-- ===========================================
-- FiveM Blinker Script - Server
-- Author: xtomatex2
-- Version: 2.0.0
-- ===========================================

-- ========== SERVER DEBUG FUNKTIONEN ==========

-- Server Debug Funktionen
local function ServerDebugPrint(message, category)
    category = category or "general"
    
    if not Config or not Config.Debug or not Config.Debug.server then return end
    
    local shouldPrint = false
    
    if Config.Debug.server.enabled then
        if category == "sync" and Config.Debug.server.showSync then
            shouldPrint = true
        elseif category == "sound" and Config.Debug.server.showSound then
            shouldPrint = true
        elseif category == "request" and Config.Debug.server.showRequests then
            shouldPrint = true
        elseif category == "general" then
            shouldPrint = true
        end
    end
    
    if shouldPrint then
        print("[Blinker Server] " .. message)
    end
end

-- ========== STATEBAG SYNCHRONISATION ==========

-- Event für Blinker-Status Sync - Sendet an ALLE Spieler
RegisterNetEvent('blinker:syncState')
AddEventHandler('blinker:syncState', function(vehNetId, leftBlinker, rightBlinker, hazardLights)
    local source = source
    local playerPed = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if not DoesEntityExist(vehicle) or vehicle == 0 then 
        ServerDebugPrint("FEHLER: Spieler " .. source .. " ist in keinem Fahrzeug", "sync")
        return 
    end
    
    ServerDebugPrint(string.format("Sync von Spieler %d - Fahrzeug %d (NetID: %d): Links=%s, Rechts=%s, Hazard=%s", 
        source, vehicle, vehNetId, tostring(leftBlinker), tostring(rightBlinker), tostring(hazardLights)), "sync")
    
    -- Event an ALLE anderen Clients senden für Synchronisation
    TriggerClientEvent('blinker:updateBlinkers', -1, vehNetId, leftBlinker, rightBlinker, hazardLights, source)
    
    ServerDebugPrint(string.format("Event an alle Clients gesendet für NetID %d", vehNetId), "sync")
end)

-- Event für Blinker-Status Anfrage (wenn Spieler in Fahrzeug einsteigt)
RegisterNetEvent('blinker:requestVehicleState')
AddEventHandler('blinker:requestVehicleState', function(vehNetId)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    
    if not DoesEntityExist(vehicle) then 
        ServerDebugPrint(string.format("FEHLER: Fahrzeug mit NetID %d existiert nicht", vehNetId), "request")
        return 
    end
    
    ServerDebugPrint(string.format("Status-Anfrage von Spieler %d für Fahrzeug NetID %d", source, vehNetId), "request")
    
    -- Anderen kontrollierten Spieler im Fahrzeug finden
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayerId = tonumber(playerId)
        if targetPlayerId and targetPlayerId ~= source then
            local targetPed = GetPlayerPed(targetPlayerId)
            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            
            if targetVehicle == vehicle then
                -- Spieler gefunden - um Status bitten
                TriggerClientEvent('blinker:shareCurrentState', targetPlayerId, source, vehNetId)
                ServerDebugPrint(string.format("Status-Anfrage an Spieler %d gesendet", targetPlayerId), "request")
                break
            end
        end
    end
end)

-- Event um Status an bestimmten Spieler zu senden
RegisterNetEvent('blinker:sendStateToPlayer')
AddEventHandler('blinker:sendStateToPlayer', function(targetPlayerId, vehNetId, leftBlinker, rightBlinker, hazardLights)
    local source = source
    ServerDebugPrint(string.format("Sende Status von Spieler %d an Spieler %d: Links=%s, Rechts=%s, Hazard=%s", 
        source, targetPlayerId, tostring(leftBlinker), tostring(rightBlinker), tostring(hazardLights)), "request")
    
    TriggerClientEvent('blinker:receiveCurrentState', targetPlayerId, vehNetId, leftBlinker, rightBlinker, hazardLights)
end)

-- Event für Sound-Sync an Fahrzeug-Insassen
RegisterNetEvent('blinker:syncSound')
AddEventHandler('blinker:syncSound', function(vehNetId, soundName, soundType)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehicle) then 
        ServerDebugPrint(string.format("Sound-Sync FEHLER: Fahrzeug mit NetID %d existiert nicht", vehNetId), "sound")
        return 
    end
    
    ServerDebugPrint(string.format("Sound-Sync von Spieler %d - Fahrzeug NetID %d: %s (%s)", 
        source, vehNetId, soundName, soundType), "sound")
    
    -- Alle anderen Spieler im gleichen Fahrzeug finden
    local players = GetPlayers()
    local targetCount = 0
    for _, playerId in ipairs(players) do
        local targetPlayerId = tonumber(playerId)
        if targetPlayerId and targetPlayerId ~= source then
            local targetPed = GetPlayerPed(targetPlayerId)
            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            
            if DoesEntityExist(targetVehicle) and targetVehicle == vehicle then
                TriggerClientEvent('blinker:playSound', targetPlayerId, soundName, soundType, vehNetId)
                targetCount = targetCount + 1
                ServerDebugPrint(string.format("Sound an Spieler %d gesendet", targetPlayerId), "sound")
            end
        end
    end
    
    ServerDebugPrint(string.format("Sound-Sync abgeschlossen: %d Empfänger", targetCount), "sound")
end)

-- Sync Request für neue Spieler
RegisterNetEvent('blinker:requestSync')
AddEventHandler('blinker:requestSync', function()
    local source = source
    -- StateBags werden automatisch für neue Clients synchronisiert
    ServerDebugPrint("Sync angefordert von Spieler: " .. source, "sync")
end)

-- Debug Event
RegisterNetEvent('blinker:debug')
AddEventHandler('blinker:debug', function(message)
    if GetConvar('blinker_debug', 'false') == 'true' then
        ServerDebugPrint(message, "request")
    end
end)
