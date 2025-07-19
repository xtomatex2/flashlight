-- ===========================================
-- FiveM Blinker Script - Server
-- Author: xtomatex2
-- Version: 2.0.0
-- ===========================================

-- ========== STATEBAG SYNCHRONISATION ==========

-- Event für Blinker-Status Sync
RegisterNetEvent('blinker:syncState')
AddEventHandler('blinker:syncState', function(vehNetId, leftBlinker, rightBlinker, hazardLights)
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehicle) then return end
    
    -- StateBag für alle Clients setzen
    Entity(vehicle).state.blinker_left = leftBlinker
    Entity(vehicle).state.blinker_right = rightBlinker
    Entity(vehicle).state.blinker_hazard = hazardLights
end)

-- Event für Sound-Sync an alle Fahrzeug-Insassen
RegisterNetEvent('blinker:syncSound')
AddEventHandler('blinker:syncSound', function(vehNetId, soundName, soundType)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehicle) then return end
    
    -- Alle Spieler finden, die im gleichen Fahrzeug sitzen
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayerId = tonumber(playerId)
        if targetPlayerId and targetPlayerId ~= source then -- Nicht an den Sender
            local targetPed = GetPlayerPed(targetPlayerId)
            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            
            if targetVehicle == vehicle then
                -- Spieler ist im gleichen Fahrzeug - Sound senden
                TriggerClientEvent('blinker:playSound', targetPlayerId, soundName, soundType)
            end
        end
    end
end)

-- Sync Request für neue Spieler
RegisterNetEvent('blinker:requestSync')
AddEventHandler('blinker:requestSync', function()
    local source = source
    -- StateBags werden automatisch für neue Clients synchronisiert
    print("[Blinker] Sync angefordert von Spieler: " .. source)
end)

-- Debug Event
RegisterNetEvent('blinker:debug')
AddEventHandler('blinker:debug', function(message)
    if GetConvar('blinker_debug', 'false') == 'true' then
        print("[Blinker Debug] " .. message)
    end
end)
