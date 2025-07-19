-- ===========================================
-- FiveM Blinker Script - Client
-- Author: xtomatex2
-- Version: 2.0.0
-- ===========================================

-- ========== NUI INITIALISIERUNG ==========
-- (Wird später nach Funktionsdefinitionen ausgeführt)

-- ========== LOKALE VARIABLEN ==========
local currentVehicle = nil
local canControlBlinkers = false
local lastCanControlBlinkers = false -- Track permission changes
local blinkerState = {
    left = false,
    right = false,
    hazard = false
}
local blinkOn = false
local lastSoundState = false
local lastBlinkToggle = nil

-- Hilfsfunktion für mehrsprachige Texte
local function GetText(key, ...)
    local lang = Config.Language.current or "de"
    local text = Config.Language[lang] and Config.Language[lang][key] or Config.Language.de[key] or key
    
    if ... then
        return string.format(text, ...)
    end
    return text
end

-- Auto-Turn-Off Variablen
local lastSteeringAngle = 0
local steeringHistory = {}
local lastDebugSteering = 0
local lastDebugTime = 0

-- ========== UTILITY FUNKTIONEN ==========

-- Prüfen ob Spieler auf Fahrersitz ist
local function IsPlayerInDriverSeat()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then return false, nil end
    
    local seat = -1 -- Fahrersitz
    local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
    
    return pedInSeat == ped, vehicle
end

-- Prüfen ob Spieler die Blinker bedienen darf
local function CanPlayerControlBlinkers()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then return false, nil end
    
    if Config.Vehicle.driverOnly then
        -- Nur Fahrer darf Blinker bedienen
        local seat = -1 -- Fahrersitz
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        return pedInSeat == ped, vehicle
    else
        -- Alle Insassen dürfen Blinker bedienen
        return true, vehicle
    end
end

-- Prüfen ob Fahrzeug ein Bodenfahrzeug ist
local function IsGroundVehicle(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)
    
    for _, class in ipairs(Config.Vehicle.allowedClasses) do
        if vehicleClass == class then
            -- Prüfen ob Fahrzeug nicht auf Blacklist steht
            local modelHash = GetEntityModel(vehicle)
            for _, blacklisted in ipairs(Config.Vehicle.blacklistedModels) do
                if modelHash == blacklisted then
                    return false
                end
            end
            return true
        end
    end
    return false
end

-- Sound abspielen
local function PlayBlinkerSound(soundName, shouldSync)
    if not Config.Sound.enabled then return end
    
    -- Lokaler Sound
    SendNUIMessage({
        action = "playSound",
        sound = soundName,
        volume = Config.Sound.volume
    })
    
    -- Sound an andere Insassen senden (falls gewünscht und konfiguriert)
    if shouldSync and Config.Sound.shareWithPassengers and currentVehicle then
        local vehNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
        TriggerServerEvent('blinker:syncSound', vehNetId, soundName, 'action')
    end
end

-- Debug Nachricht
local function DebugPrint(message)
    if Config.Debug.enabled then
        print("[Blinker Debug] " .. message)
    end
end

-- Blinker-Tick-Sound starten/stoppen
local function ControlIndicatorSound(start, shouldSync)
    if not Config.Sound.enabled then 
        DebugPrint("Sound deaktiviert - ControlIndicatorSound übersprungen")
        return 
    end
    
    DebugPrint(string.format("ControlIndicatorSound: %s", start and "START" or "STOP"))
    
    if start then
        -- NUI Sound-Loop starten
        local soundInterval = Config.Blinker.customTiming and Config.Blinker.interval or 500
        local message = {
            action = "startIndicatorLoop",
            sound = Config.Sound.sounds.indicator,
            volume = Config.Sound.volume,
            interval = soundInterval
        }
        DebugPrint(string.format("Sende NUI: startIndicatorLoop - Sound: %s, Volume: %s, Interval: %s", 
            message.sound, message.volume, message.interval))
        SendNUIMessage(message)
        
        -- Sound-Loop an andere Insassen senden
        if shouldSync and Config.Sound.shareWithPassengers and currentVehicle then
            local vehNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
            TriggerServerEvent('blinker:syncSound', vehNetId, 'startIndicatorLoop', 'loop')
        end
    else
        DebugPrint("Sende NUI: stopIndicatorLoop")
        SendNUIMessage({
            action = "stopIndicatorLoop"
        })
        
        -- Sound-Loop-Stop an andere Insassen senden
        if shouldSync and Config.Sound.shareWithPassengers and currentVehicle then
            local vehNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
            TriggerServerEvent('blinker:syncSound', vehNetId, 'stopIndicatorLoop', 'loop')
        end
    end
end

-- ========== BLINKER FUNKTIONEN ==========

-- Blinker Status setzen
local function SetBlinkerState(left, right, hazard)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then 
        DebugPrint("SetBlinkerState fehlgeschlagen: Kein gültiges Fahrzeug")
        return 
    end
    
    DebugPrint(string.format("SetBlinkerState: Links=%s, Rechts=%s, Hazard=%s", 
        tostring(left), tostring(right), tostring(hazard)))
    
    blinkerState.left = left
    blinkerState.right = right
    blinkerState.hazard = hazard
    
    -- Sound-Kontrolle sofort hier anwenden
    local anyBlinkerActive = left or right or hazard
    if anyBlinkerActive and not lastSoundState then
        -- Blinker wurde aktiviert - Sound-Loop starten
        ControlIndicatorSound(true, canControlBlinkers) -- Nur synchronisieren wenn man selbst die Kontrolle hat
        lastSoundState = true
        DebugPrint("Sound-Loop gestartet")
    elseif not anyBlinkerActive and lastSoundState then
        -- Blinker wurde deaktiviert - Sound-Loop stoppen
        ControlIndicatorSound(false, canControlBlinkers) -- Nur synchronisieren wenn man selbst die Kontrolle hat
        lastSoundState = false
        DebugPrint("Sound-Loop gestoppt")
    end
    
    -- Server über Änderung informieren
    local vehNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
    TriggerServerEvent('blinker:syncState', vehNetId, left, right, hazard)
    
    DebugPrint(string.format("Blinker-Status erfolgreich gesetzt - Links: %s, Rechts: %s, Warnblinker: %s", 
        tostring(left), tostring(right), tostring(hazard)))
end

-- ========== AUTO-TURN-OFF FUNKTIONEN ==========

-- Lenkwinkel in Grad berechnen
local function GetSteeringAngle(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    
    -- GetVehicleSteeringAngle gibt Werte zwischen -1.0 und 1.0 zurück
    local steeringInput = GetVehicleSteeringAngle(vehicle)
    -- Konvertiere zu Grad (-180 bis +180)
    return steeringInput * 180.0
end

-- Geschwindigkeit in km/h berechnen
local function GetVehicleSpeedKmh(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    
    local speed = GetEntitySpeed(vehicle) * 3.6 -- m/s zu km/h
    return speed
end

-- Prüfen ob Blinker automatisch ausgeschaltet werden soll
local function CheckAutoTurnOff()
    if not Config.Blinker.autoTurnOff.enabled then return end
    if not currentVehicle or not canControlBlinkers then return end
    if blinkerState.hazard then return end -- Warnblinker nicht automatisch ausschalten
    if not (blinkerState.left or blinkerState.right) then return end
    
    local currentSteering = GetSteeringAngle(currentVehicle)
    local threshold = Config.Blinker.autoTurnOff.steeringThreshold
    
    -- Lenkwinkel-Historie aktualisieren
    table.insert(steeringHistory, {
        angle = currentSteering,
        time = GetGameTimer()
    })
    
    -- Alte Einträge entfernen (älter als 5 Sekunden)
    local currentTime = GetGameTimer()
    for i = #steeringHistory, 1, -1 do
        if currentTime - steeringHistory[i].time > 5000 then
            table.remove(steeringHistory, i)
        end
    end
    
    -- Mindestens 2 Sekunden Daten benötigt (40 * 50ms = 2 Sekunden)
    if #steeringHistory < 40 then return end
    
    -- Einfachere, robustere Logik
    local maxLeftSteering = 0  -- Positive Werte = Linkslenkung
    local maxRightSteering = 0 -- Negative Werte = Rechtslenkung
    local recentSteering = 0
    local recentCount = 0
    
    -- Maximale Lenkwinkel in beide Richtungen finden
    for i, entry in ipairs(steeringHistory) do
        if entry.angle > maxLeftSteering then
            maxLeftSteering = entry.angle
        end
        if entry.angle < maxRightSteering then
            maxRightSteering = entry.angle
        end
        
        -- Durchschnitt der letzten 20 Messungen (1 Sekunde)
        if i > #steeringHistory - 20 then
            recentSteering = recentSteering + entry.angle
            recentCount = recentCount + 1
        end
    end
    
    if recentCount > 0 then
        recentSteering = recentSteering / recentCount
    end
    
    -- Smart Debug-Ausgaben (nur bei signifikanten Änderungen oder alle 5 Sekunden)
    local currentTime = GetGameTimer()
    local steeringChanged = math.abs(currentSteering - lastDebugSteering) > 5 -- Mehr als 5° Änderung
    local timeForUpdate = currentTime - lastDebugTime > 5000 -- Alle 5 Sekunden
    
    if Config.Debug.enabled and Config.Debug.showVehicleInfo and (steeringChanged or timeForUpdate) then
        DebugPrint(string.format("Lenkwinkel: %.1f° (Δ%.1f°)", currentSteering, currentSteering - lastDebugSteering))
        DebugPrint(string.format("Max Links: %.1f°, Max Rechts: %.1f°, Aktuell: %.1f°", 
            maxLeftSteering, maxRightSteering, recentSteering))
        lastDebugSteering = currentSteering
        lastDebugTime = currentTime
    end
    
    -- Sehr detaillierte Debug-Ausgaben (nur für Entwickler - kann spammy sein)
    if Config.Debug.enabled and Config.Debug.showSteeringDetails then
        DebugPrint(string.format("Detailliert - Winkel: %.1f°, Max L: %.1f°, Max R: %.1f°", 
            currentSteering, maxLeftSteering, maxRightSteering))
    end
    
    -- Auto-Turn-Off prüfen:
    if Config.Blinker.autoTurnOff.instantTurnOff then
        -- Sofortiges Ausschalten: Blinker aus sobald Winkel erreicht wird
        if blinkerState.left and math.abs(currentSteering) > threshold then
            SetBlinkerState(false, false, false)
            PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
            DebugPrint(string.format("Linker Blinker sofort ausgeschaltet bei %.1f°", currentSteering))
            steeringHistory = {} -- Historie zurücksetzen
            return
        end
        
        if blinkerState.right and math.abs(currentSteering) > threshold then
            SetBlinkerState(false, false, false)
            PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
            DebugPrint(string.format("Rechter Blinker sofort ausgeschaltet bei %.1f°", currentSteering))
            steeringHistory = {} -- Historie zurücksetzen
            return
        end
    else
        -- Verzögertes Ausschalten: Warten bis wieder geradeaus gefahren wird
        -- Linker Blinker: Ausschalten wenn stark nach links gelenkt wurde und jetzt wieder geradeaus
        if blinkerState.left and maxLeftSteering > threshold and math.abs(recentSteering) < (threshold * 0.3) then
            SetBlinkerState(false, false, false)
            PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
            DebugPrint(string.format("Linker Blinker nach Linkskurve ausgeschaltet (%.1f°)", maxLeftSteering))
            steeringHistory = {} -- Historie zurücksetzen
            return
        end
        
        -- Rechter Blinker: Ausschalten wenn stark nach rechts gelenkt wurde und jetzt wieder geradeaus
        if blinkerState.right and math.abs(maxRightSteering) > threshold and math.abs(recentSteering) < (threshold * 0.3) then
            SetBlinkerState(false, false, false)
            PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
            DebugPrint(string.format("Rechter Blinker nach Rechtskurve ausgeschaltet (%.1f°)", math.abs(maxRightSteering)))
            steeringHistory = {} -- Historie zurücksetzen
            return
        end
    end
end

-- Linken Blinker umschalten
local function ToggleLeftBlinker()
    DebugPrint(string.format("Toggle Links - Aktueller Status: Links=%s, Rechts=%s, Hazard=%s", 
        tostring(blinkerState.left), tostring(blinkerState.right), tostring(blinkerState.hazard)))
    
    if blinkerState.hazard then
        -- Warnblinker ausschalten
        SetBlinkerState(false, false, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
        DebugPrint("Warnblinker durch Links-Toggle ausgeschaltet")
    elseif blinkerState.left then
        -- Linken Blinker ausschalten
        SetBlinkerState(false, blinkerState.right, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
        DebugPrint(GetText("blinkerOff"))
    else
        -- Linken Blinker einschalten, rechten ausschalten
        SetBlinkerState(true, false, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOn, true)
        DebugPrint(GetText("blinkerLeft"))
        -- Auto-Turn-Off Historie zurücksetzen bei manuellem Einschalten
        steeringHistory = {}
    end
end

-- Rechten Blinker umschalten
local function ToggleRightBlinker()
    DebugPrint(string.format("Toggle Rechts - Aktueller Status: Links=%s, Rechts=%s, Hazard=%s", 
        tostring(blinkerState.left), tostring(blinkerState.right), tostring(blinkerState.hazard)))
    
    if blinkerState.hazard then
        -- Warnblinker ausschalten
        SetBlinkerState(false, false, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
        DebugPrint("Warnblinker durch Rechts-Toggle ausgeschaltet")
    elseif blinkerState.right then
        -- Rechten Blinker ausschalten
        SetBlinkerState(blinkerState.left, false, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
        DebugPrint(GetText("blinkerOff"))
    else
        -- Rechten Blinker einschalten, linken ausschalten
        SetBlinkerState(false, true, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOn, true)
        DebugPrint(GetText("blinkerRight"))
        -- Auto-Turn-Off Historie zurücksetzen bei manuellem Einschalten
        steeringHistory = {}
    end
end

-- Warnblinker umschalten
local function ToggleHazardLights()
    if blinkerState.hazard then
        -- Warnblinker ausschalten
        SetBlinkerState(false, false, false)
        PlayBlinkerSound(Config.Sound.sounds.turnOff, true)
        DebugPrint(GetText("hazardOff"))
    else
        -- Warnblinker einschalten
        SetBlinkerState(false, false, true)
        PlayBlinkerSound(Config.Sound.sounds.hazard, true)
        DebugPrint(GetText("hazardOn"))
    end
end

-- ========== BLINKER RENDERING ==========

-- Blinker visuell aktualisieren
local function UpdateBlinkerVisuals()
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return end
    
    -- Blink-Timing berechnen
    if Config.Blinker.customTiming then
        -- Eigenes Timing verwenden
        local currentTime = GetGameTimer()
        local cycleTime = Config.Blinker.interval * 2  -- Vollzyklus: an + aus
        local timeInCycle = currentTime % cycleTime
        blinkOn = timeInCycle < Config.Blinker.interval
    else
        -- GTA Standard-Timing (lässt GTA das Timing selbst machen)
        -- Hier verwenden wir ein einfaches 50ms Toggle-System
        local currentTime = GetGameTimer()
        if not lastBlinkToggle then lastBlinkToggle = currentTime end
        if currentTime - lastBlinkToggle >= 50 then
            -- GTA Standard-Verhalten simulieren (etwa 500ms Zyklus)
            blinkOn = not blinkOn
            lastBlinkToggle = currentTime
        end
    end
    
    -- Blinker setzen basierend auf Status
    local leftState = false
    local rightState = false
    local anyBlinkerActive = blinkerState.left or blinkerState.right or blinkerState.hazard
    
    if blinkerState.hazard then
        leftState = blinkOn
        rightState = blinkOn
    else
        leftState = blinkerState.left and blinkOn
        rightState = blinkerState.right and blinkOn
    end
    
    -- Native Blinker setzen (In GTA V: 0=Rechts, 1=Links)
    SetVehicleIndicatorLights(currentVehicle, 1, leftState)  -- Links
    SetVehicleIndicatorLights(currentVehicle, 0, rightState) -- Rechts
end

-- ========== STATEBAG EVENTS ==========

-- StateBag Event für andere Fahrzeuge
AddStateBagChangeHandler('blinker_left', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end
    
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end
    
    -- Nur für andere Fahrzeuge (nicht das eigene)
    if entity ~= currentVehicle then
        local left = Entity(entity).state.blinker_left or false
        local right = Entity(entity).state.blinker_right or false
        local hazard = Entity(entity).state.blinker_hazard or false
        
        -- Andere Fahrzeuge blinken lassen
        Citizen.CreateThread(function()
            while (left or right or hazard) and DoesEntityExist(entity) do
                local blinkState
                if Config.Blinker.customTiming then
                    -- Eigenes Timing für andere Fahrzeuge
                    blinkState = (GetGameTimer() % (Config.Blinker.interval * 2)) < Config.Blinker.interval
                else
                    -- GTA Standard-Timing für andere Fahrzeuge (etwa 500ms)
                    blinkState = (GetGameTimer() % 1000) < 500
                end
                
                if hazard then
                    SetVehicleIndicatorLights(entity, 0, blinkState) -- Rechts
                    SetVehicleIndicatorLights(entity, 1, blinkState) -- Links
                else
                    SetVehicleIndicatorLights(entity, 0, right and blinkState) -- Rechts
                    SetVehicleIndicatorLights(entity, 1, left and blinkState)  -- Links
                end
                
                -- Status neu prüfen
                left = Entity(entity).state.blinker_left or false
                right = Entity(entity).state.blinker_right or false
                hazard = Entity(entity).state.blinker_hazard or false
                
                Citizen.Wait(Config.Advanced.syncInterval)
            end
            
            -- Blinker ausschalten wenn nicht mehr aktiv
            SetVehicleIndicatorLights(entity, 0, false)
            SetVehicleIndicatorLights(entity, 1, false)
        end)
    end
end)

-- ========== MAIN THREADS ==========

-- Fahrzeug Status überwachen
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local canControl, controlVehicle = CanPlayerControlBlinkers()
        
        if vehicle > 0 and IsGroundVehicle(vehicle) then
            if currentVehicle ~= vehicle then
                -- Neues Fahrzeug betreten
                currentVehicle = vehicle
                canControlBlinkers = canControl
                lastCanControlBlinkers = canControl
                blinkerState = {left = false, right = false, hazard = false}
                lastSoundState = false
                -- Auto-Turn-Off Historie zurücksetzen
                steeringHistory = {}
                lastSteeringAngle = 0
                -- Sound-Loop stoppen bei Fahrzeugwechsel
                ControlIndicatorSound(false, false) -- Kein Sync beim Fahrzeugwechsel
                DebugPrint("Neues Fahrzeug betreten: " .. vehicle)
            else
                -- Gleiches Fahrzeug, nur Berechtigung aktualisieren
                if canControl ~= lastCanControlBlinkers then
                    -- Berechtigung hat sich geändert
                    canControlBlinkers = canControl
                    lastCanControlBlinkers = canControl
                    if canControl then
                        DebugPrint("Blinker-Berechtigung erhalten")
                    else
                        DebugPrint("Blinker-Berechtigung verloren (Blinker bleiben aktiv)")
                    end
                else
                    -- Berechtigung unverändert, nur Variable aktualisieren
                    canControlBlinkers = canControl
                end
            end
        else
            if currentVehicle then
                -- Fahrzeug wirklich verlassen
                if canControlBlinkers then
                    SetBlinkerState(false, false, false)
                    -- Sound-Loop stoppen beim Fahrzeug verlassen
                    ControlIndicatorSound(false, false) -- Kein Sync beim Verlassen
                end
                currentVehicle = nil
                canControlBlinkers = false
                lastCanControlBlinkers = false
                lastSoundState = false
                -- Auto-Turn-Off Historie zurücksetzen
                steeringHistory = {}
                lastSteeringAngle = 0
                DebugPrint("Fahrzeug verlassen")
            end
        end
        
        Citizen.Wait(500)
    end
end)

-- Blinker Rendering
Citizen.CreateThread(function()
    while true do
        if currentVehicle then
            UpdateBlinkerVisuals()
            -- Auto-Turn-Off nur mit Berechtigung prüfen
            if canControlBlinkers then
                CheckAutoTurnOff()
            end
        end
        Citizen.Wait(50)
    end
end)

-- ========== KEY BINDINGS ==========

-- Tastenbindungen registrieren
RegisterCommand('+blinker_left', function()
    if canControlBlinkers and currentVehicle then
        DebugPrint("Links-Pfeil gedrückt")
        ToggleLeftBlinker()
    else
        DebugPrint("Links-Pfeil ignoriert - keine Berechtigung oder kein Fahrzeug")
    end
end, false)

RegisterCommand('-blinker_left', function() end, false)

RegisterCommand('+blinker_right', function()
    if canControlBlinkers and currentVehicle then
        DebugPrint("Rechts-Pfeil gedrückt")
        ToggleRightBlinker()
    else
        DebugPrint("Rechts-Pfeil ignoriert - keine Berechtigung oder kein Fahrzeug")
    end
end, false)

RegisterCommand('-blinker_right', function() end, false)

RegisterCommand('+blinker_hazard', function()
    if canControlBlinkers and currentVehicle then
        ToggleHazardLights()
    end
end, false)

RegisterCommand('-blinker_hazard', function() end, false)

-- Standard Keybinds setzen
RegisterKeyMapping('+blinker_left', 'Linker Blinker', 'keyboard', Config.Controls.leftBlinker)
RegisterKeyMapping('+blinker_right', 'Rechter Blinker', 'keyboard', Config.Controls.rightBlinker)
RegisterKeyMapping('+blinker_hazard', 'Warnblinker', 'keyboard', Config.Controls.hazardLights)

-- ========== EVENTS ==========

-- Sync bei Resource Start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        TriggerServerEvent('blinker:requestSync')
    end
end)

-- Config Updates
RegisterNetEvent('blinker:updateConfig')
AddEventHandler('blinker:updateConfig', function(newConfig)
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            Config[key] = value
            DebugPrint("Config aktualisiert: " .. key .. " = " .. tostring(value))
        end
    end
    
    -- NUI über Lautstärke-Änderung informieren
    if newConfig.Sound and newConfig.Sound.volume then
        SendNUIMessage({
            action = "setVolume",
            volume = newConfig.Sound.volume
        })
    end
end)

-- Sound von anderen Insassen empfangen
RegisterNetEvent('blinker:playSound')
AddEventHandler('blinker:playSound', function(soundName, soundType)
    if not Config.Sound.enabled then return end
    
    DebugPrint(string.format("Sound von anderem Insassen empfangen: %s (%s)", soundName, soundType))
    
    if soundType == 'loop' then
        if soundName == 'startIndicatorLoop' then
            -- Indicator-Loop starten
            local soundInterval = Config.Blinker.customTiming and Config.Blinker.interval or 500
            SendNUIMessage({
                action = "startIndicatorLoop",
                sound = Config.Sound.sounds.indicator,
                volume = Config.Sound.volume,
                interval = soundInterval
            })
        elseif soundName == 'stopIndicatorLoop' then
            -- Indicator-Loop stoppen
            SendNUIMessage({
                action = "stopIndicatorLoop"
            })
        end
    elseif soundType == 'action' then
        -- Action-Sound abspielen
        SendNUIMessage({
            action = "playSound",
            sound = soundName,
            volume = Config.Sound.volume
        })
    end
end)

-- ========== NUI INITIALISIERUNG ==========
Citizen.CreateThread(function()
    -- NUI Frame erstellen durch kurzes Ein- und Ausschalten
    SetNuiFocus(true, false)
    Citizen.Wait(100)
    SetNuiFocus(false, false)
    
    -- Warten bis NUI geladen ist
    Citizen.Wait(1000)
    
    -- Audio-System initialisieren
    SendNUIMessage({
        action = "initAudio"
    })
    
    -- Initial Sound-Volume setzen
    SendNUIMessage({
        action = "setVolume",
        volume = Config.Sound.volume
    })
    
    -- Debug-Status an HTML senden
    SendNUIMessage({
        action = "setDebug",
        enabled = Config.Debug.enabled and Config.Debug.showSteeringDetails
    })
    
    DebugPrint("NUI Audio-System initialisiert")
end)

-- ========== TEST COMMAND ==========
RegisterCommand('testsound', function()
    DebugPrint("Test-Command: Spiele Blinker-Sound...")
    SendNUIMessage({
        action = "playSound",
        sound = Config.Sound.sounds.indicator,
        volume = Config.Sound.volume
    })
end, false)
