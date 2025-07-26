Config = {}

-- Job Settings
Config.HackerJobName = 'hacker'
Config.RequireJob = true -- Set to false to allow anyone to use the hacking laptop
Config.JobRank = 0 -- Minimum job rank required (0 = any rank)

-- Vendor Settings
Config.Vendor = {
    enabled = true,  -- Enable/disable the vendor NPC
    coords = vector4(-1054.49, -230.57, 44.02, 123.41),  -- Vendor location (Near LifeInvader building)
    model = `a_m_y_vinewood_01`,  -- Vendor ped model
    scenario = "WORLD_HUMAN_STAND_MOBILE",  -- Animation scenario
    price = 50000,  -- Price of the laptop
}

-- Blip Settings
Config.Blip = {
    enabled = true,  -- Set to false to disable the blip on the map
    sprite = 521,   -- Blip sprite (521 = Laptop)
    color = 2,      -- Blip color (2 = Green)
    scale = 0.7,    -- Blip size
    name = "Hacker Equipment"  -- Name displayed on the map
}

-- Item Settings
Config.LaptopItem = 'hacker_laptop' -- Item name for the hacking laptop
Config.UsableItem = true -- Set to true to make the laptop a usable item, false to use a command
Config.LaptopCommand = 'hackerlaptop' -- Command to open the laptop if UsableItem is false
Config.GPSTrackerItem = 'gps_tracker' -- Item name for the GPS tracker device
Config.GPSTrackerPrice = 3000 -- Price of the GPS tracker

-- Battery Settings
Config.Battery = {
    enabled = true, -- Enable/disable battery system
    maxCharge = 100, -- Maximum battery percentage
    drainRate = 0.5, -- Base battery drain rate per operation (percentage)
    idleDrainRate = 2.5, -- Battery drain rate when laptop is idle (percentage per minute)
    operationDrainRates = { -- Different drain rates for different operations
        plateLookup = 1.5,      -- Medium consumption
        scanning = 0.8,         -- Light consumption
        phoneTrack = 2.5,       -- Higher consumption
        radioDecrypt = 3.0,     -- Higher consumption
        vehicleLock = 1.0,      -- Light consumption
        vehicleEngine = 2.0,    -- Medium consumption
        vehicleTrack = 4.0,     -- High consumption
        vehicleControl = 5.0,   -- Very high consumption (brake disable, acceleration)
    },
    lowBatteryThreshold = 20, -- Threshold for low battery warning (percentage)
    criticalBatteryThreshold = 10, -- Threshold for critical battery warning (percentage)
    batteryItemName = "laptop_battery", -- Item name for replacement batteries
    batteryItemPrice = 1500, -- Price of replacement batteries
    chargerItemName = "laptop_charger", -- Item name for laptop charger
    chargerItemPrice = 2500, -- Price of laptop charger
    
    -- Realistic charging configuration (20 minutes total time)
    chargeRate = 1.67, -- Default charge rate for 50-100% (percentage per 30s tick)
    chargeInterval = 30000, -- Charging interval in ms (30 seconds)
    fastChargeRate = 5.0, -- Rate of fast charging for 0-50% (percentage per 30s tick)
    slowChargeRate = 1.67, -- Rate of slow charging for 50-100% (percentage per 30s tick)
    
    -- This configuration will result in approximately 20 minute charge time:
    -- 0-50%: ~5 minutes (5.0% every 30 seconds)
    -- 50-100%: ~15 minutes (1.67% every 30 seconds)
}

-- Plate Lookup Settings
Config.PlateQueryTimeout = 10000 -- Time in ms before a plate lookup query times out
Config.DefaultLookupDuration = 6000 -- Default "hacking" duration for plate lookup in ms
Config.VehicleLookupCooldown = 20000 -- Cooldown between lookups in ms (anti-spam)
Config.CacheResults = true -- Cache results to reduce DB load
Config.CacheExpiry = 300000 -- Cache expiry time in ms (5 minutes)

-- Database Settings
Config.DatabaseMaxRetries = 3 -- Maximum number of retries for database queries
Config.DatabaseRetryDelay = 500 -- Delay between retries in ms

-- Phone Tracker Settings
Config.PhoneTrackerEnabled = true
Config.PhoneTrackDuration = 10000 -- Duration of phone tracking in ms
Config.PhoneTrackCooldown = 30000 -- Cooldown between phone tracking attempts in ms
Config.PhoneTrackAccuracy = 25 -- Accuracy in meters (higher = less accurate)

-- Radio Decryption Settings
Config.RadioDecryptionEnabled = true
Config.RadioDecryptionDuration = 15000 -- Duration of decryption in ms
Config.RadioDecryptionCooldown = 60000 -- Cooldown between decryption attempts in ms
Config.RadioDecryptionChance = 70 -- Chance of successful decryption (0-100)

-- UI Settings (Optimized for Performance)
Config.UISettings = {
    theme = 'dark', -- 'dark' or 'light'
    showAnimations = false, -- Disabled by default for better performance
    soundEffects = false, -- Disabled for performance
    fontSize = 'normal', -- 'small', 'normal', 'large'
    updateInterval = 500, -- UI update interval in ms (optimized for performance)
    maxConcurrentAnimations = 3, -- Limit animations for performance
}

-- Production Environment Settings
Config.Production = {
    enabled = true, -- Set to false for development
    debugMode = false, -- NEVER enable in production
    performanceMonitoring = true, -- Enable performance tracking
    errorReporting = true, -- Enable error reporting to logs
    memoryOptimization = true, -- Enable memory optimization features
    rateLimiting = true, -- Enable rate limiting for all operations
}

-- Configuration Validation
Config.Validation = {
    enabled = true, -- Enable config validation on startup
    strict = true, -- Strict validation (fail if issues found)
    checkDependencies = true, -- Validate all dependencies
    validateDatabase = true, -- Test database connection on startup
}

-- Police Alert Settings
Config.AlertPolice = {
    enabled = true, -- Enable/disable police alerts
    lookupChance = 10, -- Chance (0-100) to alert police on vehicle lookup
    phoneTrackChance = 25, -- Chance to alert police on phone tracking
    radioDecryptChance = 40, -- Chance to alert police on radio decryption
    alertCooldown = 120000, -- Cooldown between alerts in ms (2 minutes)
}

-- Vehicle Detection Settings
Config.VehicleDetection = {
    maxDistance = 15.0, -- Maximum distance to detect vehicles
    checkVinChance = 80, -- Chance to check VIN (for stolen vehicles)
    maxResultsOnScreen = 5, -- Maximum number of vehicles to show in the UI at once
}

-- Police Vehicle Identification
Config.PoliceVehiclePrefixes = {
    'LSPD',
    'SAHP',
    'BCSO',
    'POLICE',
    'FBI',
    'FIB',
}

Config.EmergencyServicePrefixes = {
    'EMS',
    'AMBULANCE',
    'FIRE',
    'RANGER',
}

-- Vehicle Database Flags
Config.VehicleFlags = {
    stolen = {
        label = 'STOLEN',
        color = 'red',
    },
    police = {
        label = 'POLICE VEHICLE',
        color = 'blue',
    },
    emergency = {
        label = 'EMERGENCY VEHICLE',
        color = 'green',
    },
    flagged = {
        label = 'FLAGGED',
        color = 'orange',
    },
    rental = {
        label = 'RENTAL',
        color = 'purple',
    },
}

-- Vehicle Tracking Settings
Config.VehicleTracking = {
    enabled = true, -- Enable/disable vehicle tracking feature
    trackDuration = 300000, -- Duration of tracking in ms (5 minutes)
    refreshRate = 3000, -- How often the tracker updates in ms
    blipSprite = 225, -- Blip sprite for tracked vehicle (225 = Car)
    blipColor = 1, -- Blip color (1 = Red)
    blipScale = 0.85, -- Blip size
    blipAlpha = 255, -- Blip opacity (0-255)
    installTime = 5000, -- Time it takes to install the tracker in ms
    notifyPoliceChance = 15, -- Chance (0-100) to alert police when tracking a vehicle
}

-- Skill Progression System
Config.XPEnabled = true -- Enable/disable XP progression system
Config.XPSettings = {
    plateLookup = 5,      -- XP for successful plate lookup
    phoneTrack = 10,      -- XP for successful phone tracking
    radioDecrypt = 15,    -- XP for successful radio decryption
    phoneHack = 20,       -- XP for successful phone hacking
    vehicleTrack = 10,    -- XP for successful vehicle tracking
    vehicleControl = 25   -- XP for successful vehicle control (unlock/disable)
}

Config.LevelThresholds = {
    [1] = 0,      -- Script Kiddie
    [2] = 100,    -- Coder
    [3] = 250,    -- Security Analyst
    [4] = 500,    -- Elite Hacker
    [5] = 1000    -- Mastermind
}

Config.LevelNames = {
    [1] = "Script Kiddie",
    [2] = "Coder",
    [3] = "Security Analyst", 
    [4] = "Elite Hacker",
    [5] = "Mastermind"
}

Config.LevelUnlocks = {
    [1] = {"plateLookup"},                                  -- Level 1: Basic plate lookup
    [2] = {"plateLookup", "phoneTrack"},                    -- Level 2: Adds phone tracking
    [3] = {"plateLookup", "phoneTrack", "radioDecrypt", "vehicleTrack"}, -- Level 3: Adds radio decryption and vehicle tracking
    [4] = {"plateLookup", "phoneTrack", "radioDecrypt", "vehicleTrack", "phoneHack"}, -- Level 4: Adds phone hacking
    [5] = {"plateLookup", "phoneTrack", "radioDecrypt", "vehicleTrack", "phoneHack", "vehicleControl"} -- Level 5: Adds vehicle control
}

-- Anti-Spam / Cooldowns
Config.Cooldowns = {
    global = 5000,      -- Global cooldown between any hacking attempts
    lookup = 20000,     -- Cooldown for plate lookups
    phoneTrack = 30000, -- Cooldown for phone tracking
    radioDecrypt = 60000, -- Cooldown for radio decryption
    phoneHack = 120000, -- Cooldown for phone hacking
    vehicleHack = 180000 -- Cooldown for vehicle control
}

-- Trace Buildup System
Config.TraceBuildUp = {
    enabled = true,
    maxTrace = 100,     -- Maximum trace value
    decayRate = 5,      -- Trace decay per minute
    alertThreshold = 80, -- Alert police when trace exceeds this
    increaseRates = {
        lookup = 5,         -- Trace increase per lookup
        phoneTrack = 10,    -- Trace increase per phone track
        radioDecrypt = 15,  -- Trace increase per radio decrypt
        phoneHack = 20,     -- Trace increase per phone hack
        vehicleHack = 25    -- Trace increase per vehicle hack
    }
}

-- Phone Hacking Settings
Config.PhoneHacking = {
    enabled = true,
    hackDuration = 10000, -- Time it takes to hack in ms
    cooldown = 120000,    -- 2 minute cooldown
    minLevel = 4,         -- Minimum hacker level required (Elite Hacker)
    captchaGridSize = 5,  -- 5x5 grid for captcha challenge
    maxAttempts = 3,      -- Max password attempts
    passwordLength = 6    -- Length of password to crack
}

-- Logging System
Config.Logging = {
    enabled = true,
    databaseLogs = true,
    consoleLogs = true,
    discordWebhook = {
        enabled = false,
        url = "", -- Your Discord webhook URL
        username = "Hacker Logs",
        avatar = "" -- URL to an avatar image
    }
}

-- Inventory Compatibility
Config.Inventory = {
    type = "qb", -- Options: "qb" or "ox"
    oxInventory = false
} 