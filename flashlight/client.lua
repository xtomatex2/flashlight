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

-- Auto-Turn-Off Variablen
local lastSteeringAngle = 0
local steeringHistory = {}
local lastDebugSteering = 0
local lastDebugTime = 0
local lastVisualDebug = 0

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
local lastVisualDebug = 0

-- ========== UTILITY FUNKTIONEN ==========

-- Debug Nachricht (muss früh definiert werden)
local function DebugPrint(message)
    if Config.Debug and Config.Debug.enabled then
        print("[Blinker Debug] " .. message)
    end
end

-- NUI Debug Nachricht
local function DebugPrintNUI(message)
    if Config.Debug and Config.Debug.enabled and Config.Debug.showNUIMessages then
        print("[Blinker NUI] " .. message)
    end
end

-- Sichere NetworkID-Funktion um Warnungen zu vermeiden
local function GetSafeNetworkId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end
    
    -- Prüfen ob das Fahrzeug eine gültige NetworkID hat
    if not NetworkGetEntityIsNetworked(vehicle) then
        return nil
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId == 0 then
        return nil
    end
    
    return netId
end

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
        local vehNetId = GetSafeNetworkId(currentVehicle)
        if vehNetId then
            TriggerServerEvent('blinker:syncSound', vehNetId, soundName, 'action')
        end
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
        -- NUI Sound-Loop starten (Standard 500ms)
        local message = {
            action = "startIndicatorLoop",
            sound = Config.Sound.sounds.indicator,
            volume = Config.Sound.volume,
            interval = 500
        }
        DebugPrintNUI(string.format("Sende NUI: startIndicatorLoop - Sound: %s, Volume: %s, Interval: 500ms", 
            message.sound, message.volume))
        SendNUIMessage(message)
        
        -- Sound-Loop an andere Insassen senden
        if shouldSync and Config.Sound.shareWithPassengers and currentVehicle then
            local vehNetId = GetSafeNetworkId(currentVehicle)
            if vehNetId then
                TriggerServerEvent('blinker:syncSound', vehNetId, 'startIndicatorLoop', 'loop')
            end
        end
    else
        DebugPrintNUI("Sende NUI: stopIndicatorLoop")
        SendNUIMessage({
            action = "stopIndicatorLoop"
        })
        
        -- Sound-Loop-Stop an andere Insassen senden
        if shouldSync and Config.Sound.shareWithPassengers and currentVehicle then
            local vehNetId = GetSafeNetworkId(currentVehicle)
            if vehNetId then
                TriggerServerEvent('blinker:syncSound', vehNetId, 'stopIndicatorLoop', 'loop')
            end
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
    
    -- Sound-Kontrolle sofort hier anwenden (vereinfacht)
    local anyBlinkerActive = left or right or hazard
    if anyBlinkerActive and not lastSoundState then
        -- Blinker wurde aktiviert - Sound-Loop starten (Standard 500ms)
        ControlIndicatorSound(true, canControlBlinkers)
        lastSoundState = true
        DebugPrint("Sound-Loop gestartet")
    elseif not anyBlinkerActive and lastSoundState then
        -- Blinker wurde deaktiviert - Sound-Loop stoppen
        ControlIndicatorSound(false, canControlBlinkers)
        lastSoundState = false
        DebugPrint("Sound-Loop gestoppt")
    end
    
    -- Server über Änderung informieren
    local vehNetId = GetSafeNetworkId(currentVehicle)
    if vehNetId then
        DebugPrint(string.format("Sende Server-Event: vehNetId=%d, Links=%s, Rechts=%s, Hazard=%s", 
            vehNetId, tostring(left), tostring(right), tostring(hazard)))
        TriggerServerEvent('blinker:syncState', vehNetId, left, right, hazard)
    else
        DebugPrint("WARNUNG: Kann keine NetworkID für Fahrzeug ermitteln - Server-Sync übersprungen")
    end
    
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
    
    if Config.Debug and Config.Debug.enabled and Config.Debug.showVehicleInfo and (steeringChanged or timeForUpdate) then
        DebugPrint(string.format("Lenkwinkel: %.1f° (Δ%.1f°)", currentSteering, currentSteering - lastDebugSteering))
        DebugPrint(string.format("Max Links: %.1f°, Max Rechts: %.1f°, Aktuell: %.1f°", 
            maxLeftSteering, maxRightSteering, recentSteering))
        lastDebugSteering = currentSteering
        lastDebugTime = currentTime
    end
    
    -- Sehr detaillierte Debug-Ausgaben (nur für Entwickler - kann spammy sein)
    if Config.Debug and Config.Debug.enabled and Config.Debug.showSteeringDetails then
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

-- Blinker visuell aktualisieren (GTA Standard)
local function UpdateBlinkerVisuals()
    if not currentVehicle or not DoesEntityExist(currentVehicle) then return end
    
    -- Einfache GTA-Standard Blinker (automatisches Timing)
    if blinkerState.hazard then
        -- Warnblinker - beide Seiten
        SetVehicleIndicatorLights(currentVehicle, 1, true)  -- Links
        SetVehicleIndicatorLights(currentVehicle, 0, true)  -- Rechts
    elseif blinkerState.left then
        -- Nur linker Blinker
        SetVehicleIndicatorLights(currentVehicle, 1, true)  -- Links
        SetVehicleIndicatorLights(currentVehicle, 0, false) -- Rechts aus
    elseif blinkerState.right then
        -- Nur rechter Blinker
        SetVehicleIndicatorLights(currentVehicle, 1, false) -- Links aus
        SetVehicleIndicatorLights(currentVehicle, 0, true)  -- Rechts
    else
        -- Alle Blinker aus
        SetVehicleIndicatorLights(currentVehicle, 1, false)
        SetVehicleIndicatorLights(currentVehicle, 0, false)
    end
end

-- ========== BLINKER SYNC EVENTS ==========

-- Aktive Blinker-Threads für andere Fahrzeuge verwalten
local activeBlinkerThreads = {}

-- Event für Blinker-Updates von anderen Spielern empfangen
RegisterNetEvent('blinker:updateBlinkers')
AddEventHandler('blinker:updateBlinkers', function(vehNetId, leftBlinker, rightBlinker, hazardLights, senderPlayerId)
    local localPlayerId = GetPlayerServerId(PlayerId())
    
    -- Ignoriere Updates von eigenem Spieler
    if senderPlayerId == localPlayerId then
        DebugPrint(string.format("Ignoriere eigenes Blinker-Update von Spieler %d", senderPlayerId))
        return
    end
    
    -- Fahrzeug-Entity aus NetworkID finden
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehicle) then
        DebugPrint(string.format("Fahrzeug mit NetID %d existiert nicht auf diesem Client", vehNetId))
        return
    end
    
    -- Prüfen ob es das eigene Fahrzeug ist (Status-Update für Mitfahrer)
    if currentVehicle and vehicle == currentVehicle then
        DebugPrint(string.format("Update für eigenes Fahrzeug %d empfangen - Status synchronisieren", vehicle))
        
        -- Eigenen Blinker-Status aktualisieren wenn wir keine Kontrolle haben
        if not canControlBlinkers then
            blinkerState.left = leftBlinker
            blinkerState.right = rightBlinker
            blinkerState.hazard = hazardLights
            
            -- Sound-Status entsprechend anpassen
            local isAnyActive = leftBlinker or rightBlinker or hazardLights
            if isAnyActive and not lastSoundState then
                ControlIndicatorSound(true, false)
                lastSoundState = true
                DebugPrint("Sound-Loop für empfangenen Status gestartet")
            elseif not isAnyActive and lastSoundState then
                ControlIndicatorSound(false, false)
                lastSoundState = false
                DebugPrint("Sound-Loop für empfangenen Status gestoppt")
            end
        end
        return
    end
    
    -- Für andere Fahrzeuge: Einfache visuelle Synchronisation
    DebugPrint(string.format("Blinker-Update für anderes Fahrzeug %d (NetID %d) - Links=%s, Rechts=%s, Hazard=%s", 
        vehicle, vehNetId, tostring(leftBlinker), tostring(rightBlinker), tostring(hazardLights)))
    
    -- Bestehenden Thread stoppen
    if activeBlinkerThreads[vehicle] then
        activeBlinkerThreads[vehicle] = false
    end
    
    -- Wenn keine Blinker aktiv sind, ausschalten und fertig
    if not leftBlinker and not rightBlinker and not hazardLights then
        SetVehicleIndicatorLights(vehicle, 0, false)
        SetVehicleIndicatorLights(vehicle, 1, false)
        DebugPrint(string.format("Blinker für anderes Fahrzeug %d ausgeschaltet", vehicle))
        return
    end
    
    -- Neuen Thread für Blinker-Animation starten
    activeBlinkerThreads[vehicle] = true
    DebugPrint(string.format("Starte Blinker-Thread für anderes Fahrzeug %d", vehicle))
    
    Citizen.CreateThread(function()
        local lastBlinkState = true
        local lastToggleTime = GetGameTimer()
        
        while activeBlinkerThreads[vehicle] and DoesEntityExist(vehicle) do
            -- 500ms Blinktiming
            local currentTime = GetGameTimer()
            if currentTime - lastToggleTime >= 500 then
                lastBlinkState = not lastBlinkState
                lastToggleTime = currentTime
            end
            
            -- Blinker setzen
            if hazardLights then
                SetVehicleIndicatorLights(vehicle, 0, lastBlinkState) -- Rechts
                SetVehicleIndicatorLights(vehicle, 1, lastBlinkState) -- Links
            else
                SetVehicleIndicatorLights(vehicle, 0, rightBlinker and lastBlinkState) -- Rechts
                SetVehicleIndicatorLights(vehicle, 1, leftBlinker and lastBlinkState)  -- Links
            end
            
            Citizen.Wait(50)
        end
        
        -- Thread beendet - Blinker ausschalten
        SetVehicleIndicatorLights(vehicle, 0, false)
        SetVehicleIndicatorLights(vehicle, 1, false)
        DebugPrint(string.format("Blinker-Thread für anderes Fahrzeug %d beendet", vehicle))
    end)
end)

-- Event um Status von anderem Spieler zu empfangen (beim Einsteigen)
RegisterNetEvent('blinker:receiveCurrentState')
AddEventHandler('blinker:receiveCurrentState', function(vehNetId, leftBlinker, rightBlinker, hazardLights)
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehicle) or vehicle ~= currentVehicle then return end
    
    DebugPrint(string.format("Empfange aktuellen Status beim Einsteigen: Links=%s, Rechts=%s, Hazard=%s", 
        tostring(leftBlinker), tostring(rightBlinker), tostring(hazardLights)))
    
    -- Status immer aktualisieren (egal ob Kontrolle oder nicht)
    local previousState = {
        left = blinkerState.left,
        right = blinkerState.right,
        hazard = blinkerState.hazard
    }
    
    blinkerState.left = leftBlinker
    blinkerState.right = rightBlinker
    blinkerState.hazard = hazardLights
    
    -- Sound entsprechend anpassen
    local isAnyActive = leftBlinker or rightBlinker or hazardLights
    local wasAnyActive = previousState.left or previousState.right or previousState.hazard
    
    if isAnyActive and not lastSoundState then
        ControlIndicatorSound(true, false) -- Kein Sync beim Einsteigen
        lastSoundState = true
        DebugPrint("Sound-Loop für bestehende Blinker gestartet")
    elseif not isAnyActive and lastSoundState then
        ControlIndicatorSound(false, false)
        lastSoundState = false
        DebugPrint("Sound-Loop gestoppt - keine aktiven Blinker")
    end
    
    -- Zusätzliche Sicherheit: Sound immer starten wenn Blinker aktiv sind
    if isAnyActive then
        ControlIndicatorSound(true, false)
        lastSoundState = true
        DebugPrint("Sound-Loop Sicherheits-Start für aktive Blinker")
    end
    
    -- Wenn wir keine Kontrolle haben, aber Blinker aktiv sind, können wir diese nicht ändern
    if not canControlBlinkers and isAnyActive then
        DebugPrint("Status empfangen - keine Kontrolle, aber Blinker sind aktiv")
    end
end)

-- Event um aktuellen Status mit neuem Spieler zu teilen
RegisterNetEvent('blinker:shareCurrentState')
AddEventHandler('blinker:shareCurrentState', function(newPlayerId, vehNetId)
    if not currentVehicle or not canControlBlinkers then return end
    
    local currentVehNetId = GetSafeNetworkId(currentVehicle)
    if not currentVehNetId or currentVehNetId ~= vehNetId then return end
    
    -- Aktuellen Status an neuen Spieler senden
    DebugPrint(string.format("Teile aktuellen Blinker-Status mit Spieler %d: Links=%s, Rechts=%s, Hazard=%s", 
        newPlayerId, tostring(blinkerState.left), tostring(blinkerState.right), tostring(blinkerState.hazard)))
    TriggerServerEvent('blinker:sendStateToPlayer', newPlayerId, vehNetId, blinkerState.left, blinkerState.right, blinkerState.hazard)
end)

-- Hilfsfunktion um zu prüfen ob Fahrzeug bereits Blinker aktiv hat
local function CheckVehicleIndicatorLights(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false, false, false end
    
    -- Diese Funktion ist limitiert, da GTA nicht direkt den Blinker-Status abfragt
    -- Aber wir können prüfen ob das Fahrzeug "blinkt" - ist aber nicht 100% zuverlässig
    -- Besser ist die Server-Synchronisation
    return false, false, false
end

-- Altes StateBag-System entfernt - durch direktes Event-System ersetzt

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
                local previousVehicle = currentVehicle
                currentVehicle = vehicle
                canControlBlinkers = canControl
                lastCanControlBlinkers = canControl
                
                -- Prüfen ob Motor läuft (Blinker könnten noch aktiv sein)
                local engineRunning = GetIsVehicleEngineRunning(vehicle)
                
                if engineRunning then
                    -- Motor läuft - Status von anderen Spielern anfragen, bevor wir alles zurücksetzen
                    local vehNetId = GetSafeNetworkId(vehicle)
                    if vehNetId then
                        DebugPrint(string.format("Motor läuft - Status-Anfrage für Fahrzeug NetID %d gesendet", vehNetId))
                        
                        -- Status-Anfrage senden
                        TriggerServerEvent('blinker:requestVehicleState', vehNetId)
                        
                        -- Backup: Falls niemand antwortet, Status nach 500ms zurücksetzen
                        local requestTime = GetGameTimer()
                        Citizen.CreateThread(function()
                            Citizen.Wait(500)
                            
                            -- Prüfen ob wir immer noch im gleichen Fahrzeug sind und keine Antwort erhalten haben
                            if currentVehicle == vehicle and GetGameTimer() - requestTime >= 500 then
                                -- Keine Antwort erhalten - aber prüfen ob visuell Blinker aktiv sind
                                DebugPrint("Keine Status-Antwort erhalten - prüfe visuellen Status")
                                
                                -- Falls Status immer noch leer ist, aber wir erwarten dass Blinker aktiv sind
                                if not (blinkerState.left or blinkerState.right or blinkerState.hazard) then
                                    DebugPrint("Initialisiere mit leerem Status")
                                    blinkerState = {left = false, right = false, hazard = false}
                                    lastSoundState = false
                                else
                                    -- Status ist da, aber Sound könnte fehlen - Sound-Check
                                    local shouldHaveSound = blinkerState.left or blinkerState.right or blinkerState.hazard
                                    if shouldHaveSound and not lastSoundState then
                                        DebugPrint("Sound-Backup: Starte Sound für aktive Blinker")
                                        ControlIndicatorSound(true, false)
                                        lastSoundState = true
                                    end
                                end
                            end
                        end)
                    else
                        -- Keine NetworkID - Status zurücksetzen
                        blinkerState = {left = false, right = false, hazard = false}
                        lastSoundState = false
                    end
                else
                    -- Motor aus - Status komplett zurücksetzen
                    blinkerState = {left = false, right = false, hazard = false}
                    lastSoundState = false
                    DebugPrint("Motor aus - Blinker-Status zurückgesetzt")
                end
                
                -- Auto-Turn-Off Historie immer zurücksetzen bei Fahrzeugwechsel
                steeringHistory = {}
                lastSteeringAngle = 0
                ControlIndicatorSound(false, false)
                DebugPrint(string.format("Fahrzeug betreten: %d (Motor: %s)", vehicle, engineRunning and "AN" or "AUS"))
            else
                -- Berechtigung aktualisieren
                canControlBlinkers = canControl
                if canControl ~= lastCanControlBlinkers then
                    lastCanControlBlinkers = canControl
                    DebugPrint(canControl and "Blinker-Berechtigung erhalten" or "Blinker-Berechtigung verloren")
                end
            end
        else
            if currentVehicle then
                -- Fahrzeug verlassen - aber nur Status senden wenn wir Kontrolle haben
                if canControlBlinkers then
                    SetBlinkerState(false, false, false)
                end
                ControlIndicatorSound(false, false)
                
                -- Wichtig: currentVehicle erst später auf nil setzen, damit andere Spieler
                -- den finalen Status noch empfangen können
                local vehicleToLeave = currentVehicle
                
                -- Status-Reset mit Verzögerung
                Citizen.SetTimeout(200, function()
                    currentVehicle = nil
                    canControlBlinkers = false
                    lastCanControlBlinkers = false
                    lastSoundState = false
                    steeringHistory = {}
                    lastSteeringAngle = 0
                    DebugPrint("Fahrzeug verlassen - Status zurückgesetzt")
                end)
                
                DebugPrint("Fahrzeug wird verlassen: " .. vehicleToLeave)
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
            
            -- Auto-Turn-Off nur mit Berechtigung prüfen (weniger häufig für Stabilität)
            if canControlBlinkers then
                CheckAutoTurnOff()
            end
        end
        
        -- Stabiles 50ms Intervall für konsistentes Timing
        Citizen.Wait(50)
    end
end)

-- Sound-Sicherheits-Thread (prüft regelmäßig ob Sound gestoppt werden muss)
Citizen.CreateThread(function()
    while true do
        -- Prüfen ob Sound läuft aber Spieler nicht mehr im Fahrzeug ist
        if lastSoundState then
            local ped = PlayerPedId()
            local playerVehicle = GetVehiclePedIsIn(ped, false)
            
            -- Wenn kein Fahrzeug oder anderes Fahrzeug als currentVehicle
            if playerVehicle == 0 or (currentVehicle and playerVehicle ~= currentVehicle) then
                DebugPrint("Sicherheits-Stop: Sound läuft aber Spieler nicht im richtigen Fahrzeug")
                SendNUIMessage({
                    action = "stopIndicatorLoop"
                })
                lastSoundState = false
            -- Zusätzliche Prüfung mit IsPedInVehicle
            elseif currentVehicle and not IsPedInVehicle(ped, currentVehicle, false) then
                DebugPrint("Sicherheits-Stop: Sound läuft aber Spieler nicht IM Fahrzeug")
                SendNUIMessage({
                    action = "stopIndicatorLoop"
                })
                lastSoundState = false
            end
        end
        
        -- NEUE PRÜFUNG: Sound-Status mit Blinker-Status synchronisieren
        if currentVehicle and DoesEntityExist(currentVehicle) then
            local shouldHaveSound = blinkerState.left or blinkerState.right or blinkerState.hazard
            
            -- Sound sollte laufen, tut es aber nicht
            if shouldHaveSound and not lastSoundState then
                DebugPrint("Sound-Sync-Fix: Blinker aktiv aber kein Sound - starte Sound")
                ControlIndicatorSound(true, false)
                lastSoundState = true
            -- Sound läuft, sollte aber nicht
            elseif not shouldHaveSound and lastSoundState then
                DebugPrint("Sound-Sync-Fix: Kein Blinker aktiv aber Sound läuft - stoppe Sound")
                ControlIndicatorSound(false, false)
                lastSoundState = false
            end
        end
        
        Citizen.Wait(1000) -- Alle 1 Sekunde prüfen
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
AddEventHandler('blinker:playSound', function(soundName, soundType, vehNetId)
    if not Config.Sound.enabled then return end
    
    -- Sicherheitsprüfung: Nur Sound abspielen wenn Spieler im entsprechenden Fahrzeug sitzt
    if vehNetId then
        local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
        local ped = PlayerPedId()
        local playerVehicle = GetVehiclePedIsIn(ped, false)
        
        -- Validierung: Spieler muss in richtigem Fahrzeug sein
        if not DoesEntityExist(vehicle) or playerVehicle ~= vehicle or not IsPedInVehicle(ped, vehicle, false) then
            DebugPrint(string.format("Sound ignoriert - Spieler nicht im richtigen Fahrzeug (NetID %d)", vehNetId))
            return
        end
    else
        DebugPrint("Sound ignoriert - keine Fahrzeug-NetID empfangen")
        return
    end
    
    DebugPrint(string.format("Sound von anderem Insassen empfangen: %s (%s) für Fahrzeug NetID %d", soundName, soundType, vehNetId))
    
    if soundType == 'loop' then
        if soundName == 'startIndicatorLoop' then
            SendNUIMessage({
                action = "startIndicatorLoop",
                sound = Config.Sound.sounds.indicator,
                volume = Config.Sound.volume,
                interval = 500
            })
        elseif soundName == 'stopIndicatorLoop' then
            SendNUIMessage({
                action = "stopIndicatorLoop"
            })
        end
    elseif soundType == 'action' then
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
        enabled = Config.Debug and Config.Debug.enabled and Config.Debug.showNUIMessages
    })
    
    DebugPrintNUI("NUI Audio-System initialisiert")
end)

-- ========== TEST COMMAND ==========
RegisterCommand('testsound', function()
    DebugPrintNUI("Test-Command: Spiele Blinker-Sound...")
    SendNUIMessage({
        action = "playSound",
        sound = Config.Sound.sounds.indicator,
        volume = Config.Sound.volume
    })
end, false)

-- Test-Command für Sound-Loop
RegisterCommand('testloop', function()
    DebugPrintNUI("Test-Command: Starte Blinker-Sound-Loop...")
    SendNUIMessage({
        action = "startIndicatorLoop",
        sound = Config.Sound.sounds.indicator,
        volume = Config.Sound.volume,
        interval = 500
    })
end, false)

-- Test-Command um Sound-Loop zu stoppen
RegisterCommand('stoploop', function()
    DebugPrintNUI("Test-Command: Stoppe Blinker-Sound-Loop...")
    SendNUIMessage({
        action = "stopIndicatorLoop"
    })
end, false)

-- Test-Command um Blinker zu testen
RegisterCommand('testblinker', function()
    if not currentVehicle then
        print("^1Fehler: Kein Fahrzeug^7")
        return
    end
    
    print("^3Testing Blinker für 5 Sekunden...^7")
    
    Citizen.CreateThread(function()
        -- Links blinken für 2.5 Sekunden
        blinkerState.left = true
        blinkerState.right = false
        blinkerState.hazard = false
        
        Citizen.Wait(2500)
        
        -- Rechts blinken für 2.5 Sekunden
        blinkerState.left = false
        blinkerState.right = true
        blinkerState.hazard = false
        
        Citizen.Wait(2500)
        
        -- Reset
        blinkerState.left = false
        blinkerState.right = false
        blinkerState.hazard = false
        SetVehicleIndicatorLights(currentVehicle, 1, false)
        SetVehicleIndicatorLights(currentVehicle, 0, false)
        print("^3Blinker-Test beendet^7")
    end)
end, false)

-- Status Debug Command
RegisterCommand('blinkerstatus', function()
    if not currentVehicle then
        print("^1Fehler: Kein Fahrzeug^7")
        return
    end
    
    local engineRunning = GetIsVehicleEngineRunning(currentVehicle)
    print(string.format("^3[Blinker Status]^7"))
    print(string.format("Fahrzeug: %d", currentVehicle))
    print(string.format("Motor: %s", engineRunning and "AN" or "AUS"))
    print(string.format("Berechtigung: %s", canControlBlinkers and "JA" or "NEIN"))
    print(string.format("Links: %s | Rechts: %s | Hazard: %s", 
        tostring(blinkerState.left), tostring(blinkerState.right), tostring(blinkerState.hazard)))
    print(string.format("Sound aktiv: %s", lastSoundState and "JA" or "NEIN"))
end, false)

-- Debug Command für Fahrzeug-Status-Anfrage
RegisterCommand('requeststatus', function()
    if not currentVehicle then
        print("^1Fehler: Kein Fahrzeug^7")
        return
    end
    
    local vehNetId = GetSafeNetworkId(currentVehicle)
    if vehNetId then
        print("^3Fordere Status an...^7")
        TriggerServerEvent('blinker:requestVehicleState', vehNetId)
    else
        print("^1Fehler: Keine NetworkID^7")
    end
end, false)

-- Debug Command für Sound-Reparatur
RegisterCommand('fixsound', function()
    if not currentVehicle then
        print("^1Fehler: Kein Fahrzeug^7")
        return
    end
    
    local shouldHaveSound = blinkerState.left or blinkerState.right or blinkerState.hazard
    
    if shouldHaveSound then
        print("^3Repariere Blinker-Sound...^7")
        ControlIndicatorSound(false, false) -- Erst stoppen
        Citizen.Wait(100)
        ControlIndicatorSound(true, false) -- Dann neu starten
        lastSoundState = true
        print("^2Sound repariert!^7")
    else
        print("^3Keine aktiven Blinker - stoppe Sound^7")
        ControlIndicatorSound(false, false)
        lastSoundState = false
    end
end, false)
