local QBCore = exports['qb-core']:GetCoreObject()

-- Security and anti-exploit system
local SecuritySystem = {
    playerLimits = {},          -- Per-player rate limits and usage tracking
    ipLimits = {},             -- Per-IP rate limits (for multiple accounts)
    suspiciousActivity = {},   -- Flagged activities and patterns
    blacklistedPlayers = {},   -- Temporarily banned players
    globalLimits = {           -- Server-wide limits
        dailyOperations = 0,
        lastReset = os.time()
    }
}

-- Rate limiting configuration
local RateLimits = {
    -- Per-service hourly limits
    hourlyLimits = {
        plateLookup = 50,        -- 50 plate lookups per hour
        phoneTracking = 20,      -- 20 phone tracks per hour
        radioDecrypt = 15,       -- 15 radio decryptions per hour
        vehicleControl = 10,     -- 10 vehicle controls per hour
        phoneHacking = 8         -- 8 phone hacks per hour
    },
    
    -- Per-service cooldowns (in milliseconds)
    cooldowns = {
        plateLookup = 5000,      -- 5 seconds between plate lookups
        phoneTracking = 10000,   -- 10 seconds between phone tracks
        radioDecrypt = 8000,     -- 8 seconds between radio decrypts
        vehicleControl = 15000,  -- 15 seconds between vehicle controls
        phoneHacking = 20000     -- 20 seconds between phone hacks
    },
    
    -- Burst protection (max operations in short period)
    burstLimits = {
        maxOpsPerMinute = 8,     -- Max 8 operations per minute
        maxOpsPerFiveMinutes = 25 -- Max 25 operations per 5 minutes
    },
    
    -- Global server limits
    globalLimits = {
        maxOperationsPerHour = 1000, -- Server-wide hourly limit
        maxPlayersPerHour = 50       -- Max unique players per hour
    }
}

-- Suspicious activity patterns to detect
local SuspiciousPatterns = {
    rapidRequests = {
        threshold = 10,          -- 10+ requests in 60 seconds
        timeWindow = 60000,      -- 60 seconds
        action = "warn"          -- warn, suspend, or ban
    },
    
    identicalRequests = {
        threshold = 5,           -- 5+ identical requests
        timeWindow = 300000,     -- 5 minutes
        action = "suspend"
    },
    
    patternAbuse = {
        threshold = 0.95,        -- 95%+ same service usage
        minRequests = 20,        -- Minimum 20 requests to trigger
        action = "warn"
    },
    
    timePatterns = {
        threshold = 0.8,         -- 80%+ requests in specific hour pattern
        minRequests = 30,        -- Minimum 30 requests
        action = "warn"
    }
}

-- Initialize security system
local function InitializeSecurity()
    print("^2[Security] ^7Anti-exploit system initialized")
    
    -- Start cleanup threads
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(300000) -- 5 minutes
            CleanupExpiredData()
        end
    end)
    
    -- Start daily reset thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(3600000) -- 1 hour
            ResetDailyLimits()
        end
    end)
end

-- Check if player can perform an operation
function CheckRateLimit(source, serviceName)
    local identifier = GetPlayerIdentifier(source, 0)
    local playerIP = GetPlayerEndpoint(source)
    local currentTime = GetGameTimer()
    
    if not identifier then
        return false, "Invalid player identifier"
    end
    
    -- Initialize player tracking if not exists
    if not SecuritySystem.playerLimits[identifier] then
        SecuritySystem.playerLimits[identifier] = {
            services = {},
            hourlyOps = 0,
            lastHourReset = currentTime,
            recentOps = {},
            totalOps = 0,
            firstSeen = currentTime,
            flags = {}
        }
    end
    
    local playerData = SecuritySystem.playerLimits[identifier]
    
    -- Reset hourly counters if needed
    if (currentTime - playerData.lastHourReset) >= 3600000 then -- 1 hour
        playerData.hourlyOps = 0
        playerData.lastHourReset = currentTime
        for service, data in pairs(playerData.services) do
            data.hourlyCount = 0
        end
    end
    
    -- Check if player is blacklisted
    if SecuritySystem.blacklistedPlayers[identifier] then
        local blacklist = SecuritySystem.blacklistedPlayers[identifier]
        if blacklist.expires > currentTime then
            return false, string.format("Access suspended until %s. Reason: %s", 
                os.date('%H:%M', blacklist.expires / 1000), blacklist.reason)
        else
            -- Blacklist expired, remove it
            SecuritySystem.blacklistedPlayers[identifier] = nil
        end
    end
    
    -- Initialize service tracking if not exists
    if not playerData.services[serviceName] then
        playerData.services[serviceName] = {
            lastUse = 0,
            hourlyCount = 0,
            totalCount = 0,
            recentRequests = {}
        }
    end
    
    local serviceData = playerData.services[serviceName]
    
    -- Check service-specific cooldown
    local cooldown = RateLimits.cooldowns[serviceName] or 5000
    if (currentTime - serviceData.lastUse) < cooldown then
        local remainingTime = math.ceil((cooldown - (currentTime - serviceData.lastUse)) / 1000)
        return false, string.format("Service cooldown active. Wait %d seconds.", remainingTime)
    end
    
    -- Check hourly service limit
    local hourlyLimit = RateLimits.hourlyLimits[serviceName] or 20
    if serviceData.hourlyCount >= hourlyLimit then
        return false, string.format("Hourly service limit reached (%d/%d)", serviceData.hourlyCount, hourlyLimit)
    end
    
    -- Check burst protection
    local burstCheck = CheckBurstLimits(playerData, currentTime)
    if not burstCheck.allowed then
        return false, burstCheck.message
    end
    
    -- Check for suspicious patterns
    local suspiciousCheck = CheckSuspiciousActivity(identifier, serviceName, currentTime)
    if not suspiciousCheck.allowed then
        return false, suspiciousCheck.message
    end
    
    -- Check global limits
    local globalCheck = CheckGlobalLimits(currentTime)
    if not globalCheck.allowed then
        return false, globalCheck.message
    end
    
    -- All checks passed, update counters
    serviceData.lastUse = currentTime
    serviceData.hourlyCount = serviceData.hourlyCount + 1
    serviceData.totalCount = serviceData.totalCount + 1
    playerData.hourlyOps = playerData.hourlyOps + 1
    playerData.totalOps = playerData.totalOps + 1
    
    -- Add to recent operations for pattern analysis
    table.insert(playerData.recentOps, {
        service = serviceName,
        time = currentTime,
        ip = playerIP
    })
    
    -- Keep only last 50 operations
    if #playerData.recentOps > 50 then
        table.remove(playerData.recentOps, 1)
    end
    
    -- Update global counters
    SecuritySystem.globalLimits.dailyOperations = SecuritySystem.globalLimits.dailyOperations + 1
    
    return true, "Rate limit check passed"
end

-- Check burst limits (rapid successive requests)
function CheckBurstLimits(playerData, currentTime)
    local recentOps = playerData.recentOps
    local oneMinuteAgo = currentTime - 60000
    local fiveMinutesAgo = currentTime - 300000
    
    local opsLastMinute = 0
    local opsLastFiveMinutes = 0
    
    for _, op in ipairs(recentOps) do
        if op.time >= oneMinuteAgo then
            opsLastMinute = opsLastMinute + 1
        end
        if op.time >= fiveMinutesAgo then
            opsLastFiveMinutes = opsLastFiveMinutes + 1
        end
    end
    
    if opsLastMinute > RateLimits.burstLimits.maxOpsPerMinute then
        return {
            allowed = false,
            message = string.format("Too many operations in last minute (%d/%d)", 
                opsLastMinute, RateLimits.burstLimits.maxOpsPerMinute)
        }
    end
    
    if opsLastFiveMinutes > RateLimits.burstLimits.maxOpsPerFiveMinutes then
        return {
            allowed = false,
            message = string.format("Too many operations in last 5 minutes (%d/%d)", 
                opsLastFiveMinutes, RateLimits.burstLimits.maxOpsPerFiveMinutes)
        }
    end
    
    return { allowed = true }
end

-- Check for suspicious activity patterns
function CheckSuspiciousActivity(identifier, serviceName, currentTime)
    local playerData = SecuritySystem.playerLimits[identifier]
    if not playerData then return { allowed = true } end
    
    -- Check for rapid identical requests
    local recentRequests = {}
    local fiveMinutesAgo = currentTime - 300000
    
    for _, op in ipairs(playerData.recentOps) do
        if op.time >= fiveMinutesAgo and op.service == serviceName then
            table.insert(recentRequests, op)
        end
    end
    
    if #recentRequests >= SuspiciousPatterns.identicalRequests.threshold then
        FlagSuspiciousActivity(identifier, "rapid_identical_requests", 
            string.format("%d identical %s requests in 5 minutes", #recentRequests, serviceName))
        
        -- Temporary suspension for identical request spam
        local suspensionTime = currentTime + 600000 -- 10 minutes
        SecuritySystem.blacklistedPlayers[identifier] = {
            expires = suspensionTime,
            reason = "Automated request pattern detected"
        }
        
        return {
            allowed = false,
            message = "Suspicious activity detected. Access temporarily suspended."
        }
    end
    
    -- Check for service pattern abuse (using only one service)
    if playerData.totalOps >= SuspiciousPatterns.patternAbuse.minRequests then
        local serviceCount = 0
        for service, data in pairs(playerData.services) do
            if data.totalCount > 0 then
                serviceCount = serviceCount + 1
            end
        end
        
        local serviceUsageRatio = (playerData.services[serviceName] and playerData.services[serviceName].totalCount or 0) / playerData.totalOps
        
        if serviceUsageRatio >= SuspiciousPatterns.patternAbuse.threshold and serviceCount == 1 then
            FlagSuspiciousActivity(identifier, "service_pattern_abuse", 
                string.format("%.0f%% usage of single service: %s", serviceUsageRatio * 100, serviceName))
        end
    end
    
    return { allowed = true }
end

-- Check global server limits
function CheckGlobalLimits(currentTime)
    local oneHourAgo = currentTime - 3600000
    
    -- Reset daily counters if needed
    if (currentTime - SecuritySystem.globalLimits.lastReset) >= 86400000 then -- 24 hours
        SecuritySystem.globalLimits.dailyOperations = 0
        SecuritySystem.globalLimits.lastReset = currentTime
    end
    
    -- Check if server is under heavy load
    if SecuritySystem.globalLimits.dailyOperations > RateLimits.globalLimits.maxOperationsPerHour then
        return {
            allowed = false,
            message = "Server under heavy load. Please try again later."
        }
    end
    
    return { allowed = true }
end

-- Flag suspicious activity for logging and monitoring
function FlagSuspiciousActivity(identifier, activityType, details)
    local timestamp = os.time()
    
    if not SecuritySystem.suspiciousActivity[identifier] then
        SecuritySystem.suspiciousActivity[identifier] = {}
    end
    
    table.insert(SecuritySystem.suspiciousActivity[identifier], {
        type = activityType,
        details = details,
        timestamp = timestamp
    })
    
    -- Log to console
    print(string.format("^3[Security Alert] ^7%s: %s - %s", 
        identifier, activityType, details))
    
    -- Log to database for persistent tracking
    MySQL.insert([[
        INSERT INTO hacker_security_logs 
        (player_identifier, activity_type, details, created_at) 
        VALUES (?, ?, ?, ?)
    ]], {
        identifier,
        activityType,
        details,
        os.date('%Y-%m-%d %H:%M:%S', timestamp)
    })
end

-- Clean up expired data to prevent memory leaks
function CleanupExpiredData()
    local currentTime = GetGameTimer()
    local sixHoursAgo = currentTime - 21600000 -- 6 hours
    local cleaned = 0
    
    -- Clean old player data
    for identifier, data in pairs(SecuritySystem.playerLimits) do
        if data.lastHourReset < sixHoursAgo then
            SecuritySystem.playerLimits[identifier] = nil
            cleaned = cleaned + 1
        else
            -- Clean old recent operations
            local newRecentOps = {}
            for _, op in ipairs(data.recentOps) do
                if op.time >= sixHoursAgo then
                    table.insert(newRecentOps, op)
                end
            end
            data.recentOps = newRecentOps
        end
    end
    
    -- Clean expired blacklists
    for identifier, blacklist in pairs(SecuritySystem.blacklistedPlayers) do
        if blacklist.expires <= currentTime then
            SecuritySystem.blacklistedPlayers[identifier] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        print(string.format("^2[Security] ^7Cleaned up %d expired entries", cleaned))
    end
end

-- Reset daily limits
function ResetDailyLimits()
    local currentTime = GetGameTimer()
    local oneDayAgo = currentTime - 86400000 -- 24 hours
    
    if (currentTime - SecuritySystem.globalLimits.lastReset) >= 86400000 then
        SecuritySystem.globalLimits.dailyOperations = 0
        SecuritySystem.globalLimits.lastReset = currentTime
        print("^2[Security] ^7Daily limits reset")
    end
end

-- Admin command to check player security status
QBCore.Commands.Add('hackersec', 'Check player hacker security status (Admin Only)', {
    {name = 'id', help = 'Player ID'}
}, true, function(source, args)
    local src = source
    local playerId = tonumber(args[1])
    
    if not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    if not playerId then
        TriggerClientEvent('QBCore:Notify', src, 'Please provide a valid player ID', 'error')
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(playerId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end
    
    local identifier = GetPlayerIdentifier(playerId, 0)
    local playerData = SecuritySystem.playerLimits[identifier]
    local suspiciousData = SecuritySystem.suspiciousActivity[identifier]
    local blacklistData = SecuritySystem.blacklistedPlayers[identifier]
    
    print(string.format("^2[Security] ^7========== PLAYER SECURITY STATUS =========="))
    print(string.format("^2[Security] ^7Player: %s (%s)", targetPlayer.PlayerData.name, identifier))
    
    if playerData then
        print(string.format("^2[Security] ^7Total Operations: %d", playerData.totalOps))
        print(string.format("^2[Security] ^7Hourly Operations: %d", playerData.hourlyOps))
        print(string.format("^2[Security] ^7Recent Operations: %d", #playerData.recentOps))
        
        for service, data in pairs(playerData.services) do
            print(string.format("^2[Security] ^7  %s: %d total, %d hourly", service, data.totalCount, data.hourlyCount))
        end
    else
        print("^2[Security] ^7No activity data found")
    end
    
    if suspiciousData and #suspiciousData > 0 then
        print(string.format("^3[Security] ^7Suspicious Activities: %d", #suspiciousData))
        for _, activity in ipairs(suspiciousData) do
            print(string.format("^3[Security] ^7  %s: %s", activity.type, activity.details))
        end
    end
    
    if blacklistData then
        local remaining = math.max(0, blacklistData.expires - GetGameTimer())
        print(string.format("^1[Security] ^7BLACKLISTED: %s (Remaining: %d minutes)", 
            blacklistData.reason, math.floor(remaining / 60000)))
    end
    
    print(string.format("^2[Security] ^7==============================================="))
    
    TriggerClientEvent('QBCore:Notify', src, 'Security status displayed in console', 'success')
end, 'admin')

-- Admin command to clear player security flags
QBCore.Commands.Add('hackerclear', 'Clear player hacker security flags (Admin Only)', {
    {name = 'id', help = 'Player ID'}
}, true, function(source, args)
    local src = source
    local playerId = tonumber(args[1])
    
    if not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    if not playerId then
        TriggerClientEvent('QBCore:Notify', src, 'Please provide a valid player ID', 'error')
        return
    end
    
    local identifier = GetPlayerIdentifier(playerId, 0)
    
    SecuritySystem.playerLimits[identifier] = nil
    SecuritySystem.suspiciousActivity[identifier] = nil
    SecuritySystem.blacklistedPlayers[identifier] = nil
    
    print(string.format("^2[Security] ^7Cleared security data for player: %s", identifier))
    TriggerClientEvent('QBCore:Notify', src, 'Player security data cleared', 'success')
end, 'admin')

-- Export functions for use by other scripts
exports('CheckRateLimit', CheckRateLimit)
exports('FlagSuspiciousActivity', FlagSuspiciousActivity)
exports('GetPlayerSecurityData', function(identifier) 
    return SecuritySystem.playerLimits[identifier] 
end)

-- Initialize security system when server starts
Citizen.CreateThread(function()
    -- Wait for database to be ready
    while not MySQL do
        Citizen.Wait(100)
    end
    
    -- Create security logs table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_security_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `player_identifier` varchar(50) NOT NULL,
            `activity_type` varchar(50) NOT NULL,
            `details` text NOT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `player_identifier` (`player_identifier`),
            KEY `activity_type` (`activity_type`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    InitializeSecurity()
    print("^2[Security] ^7System initialized successfully")
end)