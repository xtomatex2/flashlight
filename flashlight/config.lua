-- ===========================================
-- FiveM Blinker Script - Konfiguration
-- Author: xtomatex2
-- Version: 2.0.0
-- ===========================================

Config = {}

-- ========== SOUND EINSTELLUNGEN ==========
Config.Sound = {
    enabled = true,              -- Sound aktiviert (true/false)
    volume = 0.5,               -- Globale Lautstärke (0.0 - 1.0)
    shareWithPassengers = true, -- Sounds mit anderen Insassen teilen (true/false)
    
    -- Individuelle Sound-Dateien
    sounds = {
        indicator = "INDICATOR_SOUND.wav",      -- Blinker-Tick Sound
        turnOn = "TURN_LEVER_INTRO.wav",       -- Blinker an Sound
        turnOff = "TURN_LEVER_OUTRO.wav",      -- Blinker aus Sound
        hazard = "HAZARD_BUTTON.wav"           -- Warnblinker Sound
    }
}

-- ========== BLINKER EINSTELLUNGEN ==========
Config.Blinker = {
    customTiming = true,        -- Eigenes Blink-Timing verwenden (true) oder GTA Standard (false)
    interval = 500,             -- Blink-Intervall in Millisekunden (nur wenn customTiming = true)
    autoTurnOff = {
        enabled = true,         -- Automatisches Ausschalten nach Kurven
        steeringThreshold = 15, -- Lenkwinkel-Schwellenwert
        instantTurnOff = true   -- Sofort ausschalten bei Winkel-Erreichen (true) oder warten bis geradeaus (false)
    }
}

-- ========== FAHRZEUG EINSTELLUNGEN ==========
Config.Vehicle = {
    -- Erlaubte Fahrzeugklassen (Bodenfahrzeuge)
    allowedClasses = {
        0,  -- Compacts
        1,  -- Sedans
        2,  -- SUVs
        3,  -- Coupes
        4,  -- Muscle
        5,  -- Sports Classics
        6,  -- Sports
        7,  -- Super
        8,  -- Motorcycles
        9,  -- Off-road
        10, -- Industrial
        11, -- Utility
        12, -- Vans
        17, -- Service
        18, -- Emergency
        19, -- Military
        20  -- Commercial
    },
    
    -- Verbotene Fahrzeugmodelle (Hash-Namen)
    blacklistedModels = {
        -- Beispiel: GetHashKey("hydra")
    },
    
    -- Wer darf die Blinker bedienen?
    driverOnly = true           -- true = nur Fahrer, false = alle Insassen
}

-- ========== TASTENBELEGUNG ==========
Config.Controls = {
    leftBlinker = "LEFT",       -- Pfeiltaste Links
    rightBlinker = "RIGHT",     -- Pfeiltaste Rechts
    hazardLights = "DOWN"       -- Pfeiltaste Runter
}

-- ========== SPRACH EINSTELLUNGEN ==========
Config.Language = {
    current = "de",             -- Aktuelle Sprache: "de" = Deutsch, "en" = English
    
    -- Deutsche Texte
    de = {
        blinkerLeft = "Blinker links aktiviert",
        blinkerRight = "Blinker rechts aktiviert",
        blinkerOff = "Blinker ausgeschaltet",
        hazardOn = "Warnblinker aktiviert",
        hazardOff = "Warnblinker ausgeschaltet",
        autoTurnOff = "Blinker automatisch ausgeschaltet (Kurve beendet)",
        notDriver = "Nur der Fahrer kann die Blinker bedienen",
        notGroundVehicle = "Blinker nur in Bodenfahrzeugen verfügbar",
        vehicleInfo = "Fahrzeug: %s | Klasse: %d | Lenkwinkel: %.1f°",
        steeringAngle = "Lenkwinkel: %.1f°"
    },
    
    -- English Texts
    en = {
        blinkerLeft = "Left blinker activated",
        blinkerRight = "Right blinker activated",
        blinkerOff = "Blinker turned off",
        hazardOn = "Hazard lights activated",
        hazardOff = "Hazard lights turned off",
        autoTurnOff = "Blinker automatically turned off (curve completed)",
        notDriver = "Only the driver can control the blinkers",
        notGroundVehicle = "Blinkers only available in ground vehicles",
        vehicleInfo = "Vehicle: %s | Class: %d | Steering angle: %.1f°",
        steeringAngle = "Steering angle: %.1f°"
    }
}

-- ========== DEBUG EINSTELLUNGEN ==========
Config.Debug = {
    enabled = true,             -- Debug-Modus aktiviert
    showStateChanges = true,    -- State-Änderungen in Console anzeigen
    showVehicleInfo = false,    -- Fahrzeug-Informationen anzeigen (nur bei Änderungen > 5°)
    showSteeringDetails = false -- Detaillierte Lenkwinkel-Infos (kann spammy sein)
}

-- ========== ERWEITERTE EINSTELLUNGEN ==========
Config.Advanced = {
    syncInterval = 100,         -- StateBag Sync-Intervall in ms
    maxSyncDistance = 500.0,    -- Maximale Sync-Distanz in GTA-Einheiten
    enableStateBags = true      -- StateBag-System aktiviert
}

return Config
