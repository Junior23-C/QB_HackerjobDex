-- Production Configuration for QB-HackerJob
-- This file contains optimized settings for production environments

Config.ProductionOverrides = {
    -- Security Settings (CRITICAL)
    debugMode = false, -- NEVER enable in production
    testMode = false, -- Disable all test features
    adminBypass = false, -- Disable admin bypass features
    
    -- Performance Optimizations
    cacheEnabled = true,
    cacheExpiry = 300000, -- 5 minutes
    batchOperations = true,
    memoryCleanupInterval = 600000, -- 10 minutes
    
    -- Rate Limiting (Production Values)
    rateLimits = {
        global = 2000, -- 2 second global cooldown
        plateLookup = 30000, -- 30 seconds
        phoneTracking = 45000, -- 45 seconds
        radioDecryption = 90000, -- 1.5 minutes
        phoneHacking = 300000, -- 5 minutes
        vehicleControl = 600000, -- 10 minutes
    },
    
    -- Error Handling
    errorLogging = true,
    maxRetries = 3,
    timeoutValues = {
        database = 10000, -- 10 seconds
        network = 5000, -- 5 seconds
        ui = 3000, -- 3 seconds
    },
    
    -- Resource Limits
    maxConcurrentUsers = 50,
    maxCacheSize = 1000,
    maxLogEntries = 10000,
    
    -- UI Performance
    uiOptimizations = {
        disableAnimations = true,
        reducedEffects = true,
        optimizedRendering = true,
        batchedUpdates = true,
    },
    
    -- Database Optimizations
    database = {
        connectionPooling = true,
        maxConnections = 10,
        queryTimeout = 10000,
        retryDelay = 1000,
        enableIndexes = true,
    },
    
    -- Monitoring
    monitoring = {
        enabled = true,
        performanceMetrics = true,
        memoryTracking = true,
        errorTracking = true,
        auditLogging = true,
    },
    
    -- Security Enhancements
    security = {
        inputValidation = true,
        sqlInjectionPrevention = true,
        xssProtection = true,
        rateLimitingStrict = true,
        authorizationChecks = true,
    }
}

-- Function to apply production overrides
function ApplyProductionConfig()
    if not Config.Production.enabled then
        return
    end
    
    -- Apply all production overrides
    for key, value in pairs(Config.ProductionOverrides.rateLimits) do
        if Config.Cooldowns[key] then
            Config.Cooldowns[key] = value
        end
    end
    
    -- Apply timeout overrides
    Config.PlateQueryTimeout = Config.ProductionOverrides.timeoutValues.database
    Config.PhoneTrackDuration = math.min(Config.PhoneTrackDuration, Config.ProductionOverrides.timeoutValues.network)
    Config.RadioDecryptionDuration = math.min(Config.RadioDecryptionDuration, Config.ProductionOverrides.timeoutValues.network)
    
    -- Apply UI optimizations
    if Config.ProductionOverrides.uiOptimizations.disableAnimations then
        Config.UISettings.showAnimations = false
        Config.UISettings.soundEffects = false
    end
    
    print("[QB-HackerJob] Production configuration applied successfully")
end

-- Validation functions for production readiness
function ValidateProductionConfig()
    local issues = {}
    
    -- Check critical security settings
    if Config.Production.debugMode then
        table.insert(issues, "DEBUG MODE ENABLED - CRITICAL SECURITY RISK")
    end
    
    -- Check rate limiting
    if not Config.Production.rateLimiting then
        table.insert(issues, "Rate limiting disabled - potential DoS vulnerability")
    end
    
    -- Check database settings
    if Config.DatabaseMaxRetries < 1 then
        table.insert(issues, "Database retries too low for production")
    end
    
    -- Check timeouts
    if Config.PlateQueryTimeout > 30000 then
        table.insert(issues, "Database timeout too high - may cause performance issues")
    end
    
    -- Validate dependencies
    if Config.Validation.checkDependencies then
        local dependencies = {'qb-core', 'oxmysql', 'qb-input', 'qb-menu'}
        for _, dep in ipairs(dependencies) do
            if not GetResourceState(dep) == 'started' then
                table.insert(issues, "Required dependency not running: " .. dep)
            end
        end
    end
    
    return issues
end

-- Database connection test for production
function TestDatabaseConnection()
    if not Config.Validation.validateDatabase then
        return true
    end
    
    local success = false
    local retries = 0
    local maxRetries = 3
    
    while not success and retries < maxRetries do
        MySQL.query('SELECT 1 as test', {}, function(result)
            if result and #result > 0 then
                success = true
                print("[QB-HackerJob] Database connection validated successfully")
            else
                retries = retries + 1
                if retries >= maxRetries then
                    print("[QB-HackerJob] ^1ERROR: Database connection failed after " .. maxRetries .. " attempts^7")
                end
            end
        end)
        
        if not success then
            Wait(1000) -- Wait 1 second before retry
        end
        retries = retries + 1
    end
    
    return success
end

-- Performance monitoring setup
function InitializePerformanceMonitoring()
    if not Config.Production.performanceMonitoring then
        return
    end
    
    -- Initialize performance counters
    _G.HackerJobPerformance = {
        startTime = GetGameTimer(),
        operationCounts = {},
        totalQueries = 0,
        averageQueryTime = 0,
        errorCount = 0,
        memoryUsage = 0,
        activeUsers = 0
    }
    
    -- Start monitoring thread
    CreateThread(function()
        while true do
            Wait(60000) -- Check every minute
            
            -- Log performance metrics
            local perf = _G.HackerJobPerformance
            local uptime = (GetGameTimer() - perf.startTime) / 1000 / 60 -- minutes
            
            print(string.format("[QB-HackerJob] Performance: Uptime: %.1fm, Queries: %d, Avg Query Time: %.2fms, Errors: %d, Active Users: %d", 
                uptime, perf.totalQueries, perf.averageQueryTime, perf.errorCount, perf.activeUsers))
        end
    end)
end

-- Export functions for use in other files
exports('ApplyProductionConfig', ApplyProductionConfig)
exports('ValidateProductionConfig', ValidateProductionConfig)
exports('TestDatabaseConnection', TestDatabaseConnection)
exports('InitializePerformanceMonitoring', InitializePerformanceMonitoring)