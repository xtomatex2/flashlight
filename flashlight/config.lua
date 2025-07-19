-- ===========================================
-- FiveM Blinker Script - Konfiguration / Configuration
-- Author: xtomatex2
-- Version: 2.0.0
-- ===========================================

Config = {}

-- ========== SOUND EINSTELLUNGEN / SOUND SETTINGS ==========
Config.Sound = {
    enabled = true,              -- Sound aktiviert (true/false) / Sound enabled (true/false)
    volume = 0.5,               -- Globale Lautstärke (0.0 - 1.0) / Global volume (0.0 - 1.0)
    shareWithPassengers = true, -- Sounds mit anderen Insassen teilen (true/false) / Share sounds with other passengers (true/false)
    
    -- Individuelle Sound-Dateien / Individual sound files
    sounds = {
        indicator = "INDICATOR_SOUND.wav",      -- Blinker-Tick Sound / Blinker tick sound
        turnOn = "TURN_LEVER_INTRO.wav",       -- Blinker an Sound / Blinker on sound
        turnOff = "TURN_LEVER_OUTRO.wav",      -- Blinker aus Sound / Blinker off sound
        hazard = "HAZARD_BUTTON.wav"           -- Warnblinker Sound / Hazard lights sound
    }
}

-- ========== BLINKER EINSTELLUNGEN / BLINKER SETTINGS ==========
Config.Blinker = {
    customTiming = true,        -- Eigenes Blink-Timing verwenden (true) oder GTA Standard (false) / Use custom blink timing (true) or GTA standard (false)
    interval = 500,             -- Blink-Intervall in Millisekunden (nur wenn customTiming = true) / Blink interval in milliseconds (only if customTiming = true)
    autoTurnOff = {
        enabled = true,         -- Automatisches Ausschalten nach Kurven / Automatic turn-off after curves
        steeringThreshold = 15, -- Lenkwinkel-Schwellenwert / Steering angle threshold
        instantTurnOff = true   -- Sofort ausschalten bei Winkel-Erreichen (true) oder warten bis geradeaus (false) / Turn off immediately when angle reached (true) or wait until straight (false)
    }
}

-- ========== FAHRZEUG EINSTELLUNGEN / VEHICLE SETTINGS ==========
Config.Vehicle = {
    -- Erlaubte Fahrzeugklassen (Bodenfahrzeuge) / Allowed vehicle classes (ground vehicles)
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
    
    -- Verbotene Fahrzeugmodelle (Hash-Namen) / Blacklisted vehicle models (hash names)
    blacklistedModels = {
        -- Beispiel: GetHashKey("hydra") / Example: GetHashKey("hydra")
    },
    
    -- Wer darf die Blinker bedienen? / Who can operate the blinkers?
    driverOnly = true           -- true = nur Fahrer, false = alle Insassen / true = only driver, false = all passengers
}

-- ========== TASTENBELEGUNG / KEY BINDINGS ==========
Config.Controls = {
    leftBlinker = "LEFT",       -- Pfeiltaste Links / Left arrow key
    rightBlinker = "RIGHT",     -- Pfeiltaste Rechts / Right arrow key
    hazardLights = "DOWN"       -- Pfeiltaste Runter / Down arrow key
}

-- ========== SPRACH EINSTELLUNGEN / LANGUAGE SETTINGS ==========
Config.Language = {
    current = "de",             -- Aktuelle Sprache: "de" = Deutsch, "en" = English / Current language: "de" = German, "en" = English
    
    -- Deutsche Texte / German texts
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
    
    -- English Texts / Englische Texte
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

-- ========== DEBUG EINSTELLUNGEN / DEBUG SETTINGS ==========
Config.Debug = {
    enabled = true,             -- Debug-Modus aktiviert / Debug mode enabled
    showStateChanges = true,    -- State-Änderungen in Console anzeigen / Show state changes in console
    showVehicleInfo = false,    -- Fahrzeug-Informationen anzeigen (nur bei Änderungen > 5°) / Show vehicle information (only on changes > 5°)
    showSteeringDetails = false -- Detaillierte Lenkwinkel-Infos (kann spammy sein) / Detailed steering angle info (can be spammy)
}

-- ========== ERWEITERTE EINSTELLUNGEN / ADVANCED SETTINGS ==========
Config.Advanced = {
    syncInterval = 100,         -- StateBag Sync-Intervall in ms / StateBag sync interval in ms
    maxSyncDistance = 500.0,    -- Maximale Sync-Distanz in GTA-Einheiten / Maximum sync distance in GTA units
    enableStateBags = true      -- StateBag-System aktiviert / StateBag system enabled
}

return Config
