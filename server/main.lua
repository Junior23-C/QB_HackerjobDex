-- Enhanced error handling and reliability system for QB-HackerJob
local QBCore = exports['qb-core']:GetCoreObject()

-- Error handling configuration
local ErrorConfig = {
    maxRetries = 3,
    retryDelay = 500, -- milliseconds
    circuitBreakerThreshold = 5, -- failures before circuit opens
    circuitBreakerTimeout = 30000, -- milliseconds
    logLevel = 'INFO', -- DEBUG, INFO, WARN, ERROR - Set to DEBUG for troubleshooting if needed
    healthCheckInterval = 60000 -- milliseconds
}

-- Circuit breaker state management
local CircuitBreakers = {
    database = { failures = 0, lastFailure = 0, state = 'CLOSED' },
    qbcore = { failures = 0, lastFailure = 0, state = 'CLOSED' },
    inventory = { failures = 0, lastFailure = 0, state = 'CLOSED' }
}

-- Health monitoring
local HealthStatus = {
    database = true,
    qbcore = true,
    inventory = true,
    lastCheck = 0
}

-- Utility functions for error handling
local function LogError(level, message, context)
    if not message then return end
    
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    local logMessage = string.format('[%s] [%s] %s%s', timestamp, level, message, contextStr)
    
    print('^1[qb-hackerjob:ERROR] ^7' .. logMessage)
    
    -- Log to file if available (optional)
    if Config.Logging and Config.Logging.enabled then
        -- Could add file logging here if needed
    end
end

local function LogInfo(message, context)
    if ErrorConfig.logLevel == 'DEBUG' or ErrorConfig.logLevel == 'INFO' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^2[qb-hackerjob:INFO] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
end

local function LogDebug(message, context)
    if ErrorConfig.logLevel == 'DEBUG' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^3[qb-hackerjob:DEBUG] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
end

-- Circuit breaker implementation
local function CheckCircuitBreaker(service)
    if not CircuitBreakers[service] then
        CircuitBreakers[service] = { failures = 0, lastFailure = 0, state = 'CLOSED' }
    end
    
    local breaker = CircuitBreakers[service]
    local currentTime = GetGameTimer()
    
    -- Check if circuit should be reset
    if breaker.state == 'OPEN' and (currentTime - breaker.lastFailure) > ErrorConfig.circuitBreakerTimeout then
        breaker.state = 'HALF_OPEN'
        breaker.failures = 0
        LogInfo('Circuit breaker reset for service: ' .. service)
    end
    
    return breaker.state ~= 'OPEN'
end

local function RecordFailure(service, error)
    if not CircuitBreakers[service] then
        CircuitBreakers[service] = { failures = 0, lastFailure = 0, state = 'CLOSED' }
    end
    
    local breaker = CircuitBreakers[service]
    breaker.failures = breaker.failures + 1
    breaker.lastFailure = GetGameTimer()
    
    LogError('ERROR', 'Service failure recorded: ' .. service .. ' - ' .. tostring(error))
    
    if breaker.failures >= ErrorConfig.circuitBreakerThreshold then
        breaker.state = 'OPEN'
        LogError('ERROR', 'Circuit breaker OPEN for service: ' .. service)
        HealthStatus[service] = false
    end
end

local function RecordSuccess(service)
    if not CircuitBreakers[service] then
        CircuitBreakers[service] = { failures = 0, lastFailure = 0, state = 'CLOSED' }
    end
    
    local breaker = CircuitBreakers[service]
    if breaker.state == 'HALF_OPEN' then
        breaker.state = 'CLOSED'
        LogInfo('Circuit breaker CLOSED for service: ' .. service)
    end
    breaker.failures = 0
    HealthStatus[service] = true
end

-- Safe function wrapper with retry logic
local function SafeExecute(func, service, maxRetries)
    maxRetries = maxRetries or ErrorConfig.maxRetries
    
    if not CheckCircuitBreaker(service) then
        LogError('ERROR', 'Circuit breaker OPEN for service: ' .. service)
        return false, 'Service temporarily unavailable'
    end
    
    for attempt = 1, maxRetries do
        local success, result = pcall(func)
        
        if success then
            RecordSuccess(service)
            return true, result
        else
            LogError('WARN', 'Attempt ' .. attempt .. '/' .. maxRetries .. ' failed for ' .. service .. ': ' .. tostring(result))
            
            if attempt < maxRetries then
                Citizen.Wait(ErrorConfig.retryDelay * attempt) -- Exponential backoff
            else
                RecordFailure(service, result)
                return false, result
            end
        end
    end
    
    return false, 'Max retries exceeded'
end

-- Safe QBCore functions
local function SafeGetPlayer(source)
    if not source or type(source) ~= 'number' then
        LogError('ERROR', 'Invalid source provided to SafeGetPlayer', source)
        return nil
    end
    
    local success, result = SafeExecute(function()
        return QBCore.Functions.GetPlayer(source)
    end, 'qbcore')
    
    if not success then
        LogError('ERROR', 'Failed to get player data', source)
        return nil
    end
    
    return result
end

-- Safe database operations
local function SafeDBQuery(query, parameters, callback)
    if not query or type(query) ~= 'string' then
        LogError('ERROR', 'Invalid query provided to SafeDBQuery')
        if callback then callback(nil) end
        return
    end
    
    local success, result = SafeExecute(function()
        MySQL.query(query, parameters or {}, function(queryResult)
            if queryResult then
                RecordSuccess('database')
                if callback then callback(queryResult) end
            else
                RecordFailure('database', 'Query returned nil result')
                if callback then callback(nil) end
            end
        end)
        return true
    end, 'database')
    
    if not success then
        LogError('ERROR', 'Database query failed: ' .. tostring(result))
        if callback then callback(nil) end
    end
end

-- Dependency validation
local function ValidateDependencies()
    local dependencies = {
        'qb-core',
        'oxmysql'
    }
    
    local missing = {}
    
    for _, dependency in ipairs(dependencies) do
        if GetResourceState(dependency) ~= 'started' then
            table.insert(missing, dependency)
        end
    end
    
    if #missing > 0 then
        LogError('ERROR', 'Missing dependencies: ' .. table.concat(missing, ', '))
        return false, missing
    end
    
    LogInfo('All dependencies validated successfully')
    return true, {}
end

-- Health check system
local function PerformHealthCheck()
    local currentTime = GetGameTimer()
    
    if (currentTime - HealthStatus.lastCheck) < ErrorConfig.healthCheckInterval then
        return HealthStatus
    end
    
    HealthStatus.lastCheck = currentTime
    LogDebug('Performing health check')
    
    -- Check QBCore
    local qbSuccess = SafeExecute(function()
        return QBCore and QBCore.Functions and true
    end, 'qbcore')
    HealthStatus.qbcore = qbSuccess
    
    -- Check Database
    SafeDBQuery('SELECT 1 as test', {}, function(result)
        HealthStatus.database = result ~= nil
    end)
    
    -- Check inventory (if ox_inventory is available)
    if GetResourceState('ox_inventory') == 'started' then
        HealthStatus.inventory = true
    else
        HealthStatus.inventory = Config.Inventory and Config.Inventory.type == 'qb'
    end
    
    return HealthStatus
end

-- Enhanced initialization with dependency validation and error handling
Citizen.CreateThread(function()
    LogInfo('Starting QB-HackerJob server initialization')
    
    -- Wait for dependencies to be ready
    local maxWaitTime = 30000 -- 30 seconds
    local startTime = GetGameTimer()
    
    while GetGameTimer() - startTime < maxWaitTime do
        local depsValid, missing = ValidateDependencies()
        if depsValid then
            LogInfo('Dependencies validated, proceeding with initialization')
            break
        else
            LogError('WARN', 'Waiting for dependencies: ' .. table.concat(missing, ', '))
            Citizen.Wait(2000)
        end
    end
    
    -- Final dependency check
    local depsValid, missing = ValidateDependencies()
    if not depsValid then
        LogError('ERROR', 'Failed to start - missing critical dependencies: ' .. table.concat(missing, ', '))
        return
    end
    
    Citizen.Wait(5000) -- Additional wait for everything to initialize
    
    -- Safe item creation with error handling
    LogInfo('Checking and creating required items')
    
    -- Safely check if laptop item exists
    local itemCheckSuccess, hasLaptopItem = SafeExecute(function()
        return QBCore.Shared.Items and QBCore.Shared.Items[Config.LaptopItem] ~= nil
    end, 'qbcore')
    
    if not itemCheckSuccess then
        LogError('ERROR', 'Failed to check for laptop item existence')
        return
    end
    
    if not hasLaptopItem then
        -- Item not found, adding programmatically
        
        -- Add the laptop item with error handling
        local addItemSuccess = SafeExecute(function()
            QBCore.Functions.AddItem(Config.LaptopItem, {
            name = Config.LaptopItem,
            label = 'Hacking Laptop',
            weight = 2000,
            type = 'item',
            image = 'hacker_laptop.png',
            unique = true,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A specialized laptop for various hacking operations'
            })
            return true
        end, 'qbcore')
        
        if addItemSuccess then
            LogInfo('Laptop item added successfully')
        else
            LogError('ERROR', 'Failed to add laptop item')
        end
    else
        LogInfo('Laptop item already exists')
    end
    
    -- Safe battery item creation
    if Config.Battery.enabled then
        local batteryCheckSuccess, hasBatteryItem = SafeExecute(function()
            return QBCore.Shared.Items and QBCore.Shared.Items[Config.Battery.batteryItemName] ~= nil
        end, 'qbcore')
        
        if not batteryCheckSuccess then
            LogError('ERROR', 'Failed to check for battery item existence')
        elseif not hasBatteryItem then
            -- Add the battery item with error handling
            local addBatterySuccess = SafeExecute(function()
                QBCore.Functions.AddItem(Config.Battery.batteryItemName, {
            name = Config.Battery.batteryItemName,
            label = 'Laptop Battery',
            weight = 500,
            type = 'item',
            image = 'laptop_battery.png',
            unique = false,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A replacement battery for the hacking laptop'
                })
                return true
            end, 'qbcore')
            
            if addBatterySuccess then
                LogInfo('Battery item added successfully')
            else
                LogError('ERROR', 'Failed to add battery item')
            end
        else
            LogInfo('Battery item already exists')
        end
    end
    
    -- Safe charger item creation
    if Config.Battery.enabled then
        local chargerCheckSuccess, hasChargerItem = SafeExecute(function()
            return QBCore.Shared.Items and QBCore.Shared.Items[Config.Battery.chargerItemName] ~= nil
        end, 'qbcore')
        
        if not chargerCheckSuccess then
            LogError('ERROR', 'Failed to check for charger item existence')
        elseif not hasChargerItem then
            -- Add the charger item with error handling
            local addChargerSuccess = SafeExecute(function()
                QBCore.Functions.AddItem(Config.Battery.chargerItemName, {
            name = Config.Battery.chargerItemName,
            label = 'Laptop Charger',
            weight = 300,
            type = 'item',
            image = 'laptop_charger.png',
            unique = false,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A charger for the hacking laptop'
                })
                return true
            end, 'qbcore')
            
            if addChargerSuccess then
                LogInfo('Charger item added successfully')
            else
                LogError('ERROR', 'Failed to add charger item')
            end
        else
            LogInfo('Charger item already exists')
        end
    end
    
    -- Safe job creation
    local jobCheckSuccess, hasJob = SafeExecute(function()
        return QBCore.Shared.Jobs and QBCore.Shared.Jobs[Config.HackerJobName] ~= nil
    end, 'qbcore')
    
    if not jobCheckSuccess then
        LogError('ERROR', 'Failed to check for hacker job existence')
    elseif not hasJob then
        -- Add the hacker job with error handling
        local addJobSuccess = SafeExecute(function()
            QBCore.Functions.AddJob(Config.HackerJobName, {
            label = 'Hacker',
            defaultDuty = true,
            offDutyPay = false,
            grades = {
                ['0'] = {
                    name = 'Script Kiddie',
                    payment = 50
                },
                ['1'] = {
                    name = 'Coder',
                    payment = 75
                },
                ['2'] = {
                    name = 'Security Analyst',
                    payment = 100
                },
                ['3'] = {
                    name = 'Elite Hacker',
                    payment = 125
                },
                ['4'] = {
                    name = 'Boss',
                    isboss = true,
                    payment = 150
                }
            }
            })
            return true
        end, 'qbcore')
        
        if addJobSuccess then
            LogInfo('Hacker job added successfully')
        else
            LogError('ERROR', 'Failed to add hacker job')
        end
    else
        LogInfo('Hacker job already exists')
    end
    
    -- Safe usable item registration
    local useableItemSuccess = SafeExecute(function()
        QBCore.Functions.CreateUseableItem(Config.LaptopItem, function(source)
            LogDebug('Laptop item used by player', source)
            
            -- Validate source
            if not source or type(source) ~= 'number' then
                LogError('ERROR', 'Invalid source in laptop item usage', source)
                return
            end
            
            -- Safe event trigger
            local triggerSuccess = SafeExecute(function()
                TriggerClientEvent('qb-hackerjob:client:openLaptop', source)
                return true
            end, 'qbcore')
            
            if not triggerSuccess then
                LogError('ERROR', 'Failed to trigger laptop open event', source)
            end
        end)
        return true
    end, 'qbcore')
    
    if not useableItemSuccess then
        LogError('ERROR', 'Failed to register laptop as useable item')
    end
    
    -- Safe battery item registration
    if Config.Battery.enabled then
        local batteryUseableSuccess = SafeExecute(function()
            QBCore.Functions.CreateUseableItem(Config.Battery.batteryItemName, function(source)
                LogDebug('Battery item used by player', source)
                
                if not source or type(source) ~= 'number' then
                    LogError('ERROR', 'Invalid source in battery item usage', source)
                    return
                end
                
                local triggerSuccess = SafeExecute(function()
                    TriggerClientEvent('qb-hackerjob:client:replaceBattery', source)
                    return true
                end, 'qbcore')
                
                if not triggerSuccess then
                    LogError('ERROR', 'Failed to trigger battery replace event', source)
                end
            end)
            return true
        end, 'qbcore')
        
        if not batteryUseableSuccess then
            LogError('ERROR', 'Failed to register battery as useable item')
        end
    end
    
    -- Safe charger item registration
    if Config.Battery.enabled then
        local chargerUseableSuccess = SafeExecute(function()
            QBCore.Functions.CreateUseableItem(Config.Battery.chargerItemName, function(source)
                LogDebug('Charger item used by player', source)
                
                if not source or type(source) ~= 'number' then
                    LogError('ERROR', 'Invalid source in charger item usage', source)
                    return
                end
                
                local triggerSuccess = SafeExecute(function()
                    TriggerClientEvent('qb-hackerjob:client:toggleCharger', source)
                    return true
                end, 'qbcore')
                
                if not triggerSuccess then
                    LogError('ERROR', 'Failed to trigger charger toggle event', source)
                end
            end)
            return true
        end, 'qbcore')
        
        if not chargerUseableSuccess then
            LogError('ERROR', 'Failed to register charger as useable item')
        end
    end
    
    LogInfo('QB-HackerJob server initialization completed successfully')
end)

-- Health monitoring thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(ErrorConfig.healthCheckInterval)
        
        local health = PerformHealthCheck()
        local healthyServices = 0
        local totalServices = 0
        
        for service, status in pairs(health) do
            if service ~= 'lastCheck' then
                totalServices = totalServices + 1
                if status then
                    healthyServices = healthyServices + 1
                end
            end
        end
        
        local healthPercentage = (healthyServices / totalServices) * 100
        
        if healthPercentage < 100 then
            LogError('WARN', string.format('System health: %.1f%% (%d/%d services healthy)', 
                healthPercentage, healthyServices, totalServices))
            
            for service, status in pairs(health) do
                if service ~= 'lastCheck' and not status then
                    LogError('ERROR', 'Service unhealthy: ' .. service)
                end
            end
        else
            LogDebug('All services healthy')
        end
    end
end)

-- Graceful shutdown handler
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    LogInfo('QB-HackerJob shutting down gracefully')
    
    -- Perform any cleanup operations here
    -- Save any important data
    -- Close database connections if needed
    
    LogInfo('QB-HackerJob shutdown completed')
end)

-- Admin command to check system health
QBCore.Commands.Add('hackerstatus', 'Check hacker job system status (Admin Only)', {}, true, function(source, args)
    local src = source
    
    if not src or type(src) ~= 'number' then return end
    
    local AdminPlayer = SafeGetPlayer(src)
    if not AdminPlayer then return end
    
    local hasPermSuccess, hasPermission = SafeExecute(function()
        return QBCore.Functions.HasPermission(src, 'admin')
    end, 'qbcore')
    
    if not hasPermSuccess or not hasPermission then
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        end, 'qbcore')
        return
    end
    
    local health = PerformHealthCheck()
    
    print('^2[qb-hackerjob] ^7========== SYSTEM STATUS ==========')
    for service, status in pairs(health) do
        if service ~= 'lastCheck' then
            local statusText = status and '^2HEALTHY^7' or '^1UNHEALTHY^7'
            print(string.format('^2[qb-hackerjob] ^7%s: %s', service:upper(), statusText))
        end
    end
    
    -- Circuit breaker status
    print('^2[qb-hackerjob] ^7========== CIRCUIT BREAKERS ==========')
    for service, breaker in pairs(CircuitBreakers) do
        local state = breaker.state
        local stateColor = state == 'CLOSED' and '^2' or (state == 'HALF_OPEN' and '^3' or '^1')
        print(string.format('^2[qb-hackerjob] ^7%s: %s%s^7 (failures: %d)', 
            service:upper(), stateColor, state, breaker.failures))
    end
    print('^2[qb-hackerjob] ^7=====================================')
    
    SafeExecute(function()
        TriggerClientEvent('QBCore:Notify', src, 'System status displayed in console', 'success')
    end, 'qbcore')
end, 'admin')

-- Enhanced item use handler with error handling
RegisterServerEvent('qb-hackerjob:server:useItem')
AddEventHandler('qb-hackerjob:server:useItem', function()
    local src = source
    
    -- Validate source
    if not src or type(src) ~= 'number' then
        LogError('ERROR', 'Invalid source in useItem event', src)
        return
    end
    
    local Player = SafeGetPlayer(src)
    if not Player then
        LogError('WARN', 'Player not found for useItem event', src)
        return
    end
    
    -- Safe item check
    local hasItemSuccess, hasItem = SafeExecute(function()
        local item = Player.Functions.GetItemByName(Config.LaptopItem)
        return item and item.amount > 0
    end, 'qbcore')
    
    if not hasItemSuccess then
        LogError('ERROR', 'Failed to check for laptop item', src)
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, "System error - please try again", "error")
        end, 'qbcore')
        return
    end
    
    if hasItem then
        SafeExecute(function()
            TriggerClientEvent('qb-hackerjob:client:openLaptop', src)
        end, 'qbcore')
    else
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, "You don't have a hacking laptop", "error")
        end, 'qbcore')
    end
end)

-- Enhanced job check callback with error handling
QBCore.Functions.CreateCallback('qb-hackerjob:server:hasHackerJob', function(source, cb)
    -- Add debug logging to trace callback issues
    LogDebug('hasHackerJob callback triggered', source)
    LogDebug('Callback type: ' .. tostring(type(cb)), source)
    
    -- Validate inputs with improved callback handling
    if not source or type(source) ~= 'number' then
        LogError('ERROR', 'Invalid source in hasHackerJob callback', source)
        -- Safely attempt to call callback if it exists
        if cb and type(cb) == 'function' then
            pcall(cb, false)
        end
        return
    end
    
    -- Enhanced callback validation with better error reporting
    if not cb then
        LogError('ERROR', 'Nil callback provided to hasHackerJob - this indicates a client-side issue', source)
        return
    end
    
    -- More permissive callback type checking for edge cases
    local cbType = type(cb)
    if cbType ~= 'function' then
        -- Try to handle edge cases where callback might be wrapped
        if cbType == 'table' and cb.callback and type(cb.callback) == 'function' then
            LogError('WARN', 'Wrapped callback detected, attempting to unwrap', source)
            cb = cb.callback
        else
            LogError('ERROR', 'Invalid callback type in hasHackerJob: ' .. cbType .. ' (expected function)', source)
            return
        end
    end
    
    local Player = SafeGetPlayer(source)
    if not Player then
        LogError('WARN', 'Player not found for job check', source)
        -- Safe callback execution with error handling
        local success = pcall(cb, false)
        if not success then
            LogError('ERROR', 'Failed to execute callback after player check failure', source)
        end
        return
    end
    
    -- Check if job requirement is disabled
    if not Config.RequireJob then
        LogDebug('Job requirement disabled, allowing access', source)
        local success = pcall(cb, true)
        if not success then
            LogError('ERROR', 'Failed to execute callback for disabled job requirement', source)
        end
        return
    end
    
    -- Safe job data access
    local jobCheckSuccess, hasJob = SafeExecute(function()
        if not Player.PlayerData or not Player.PlayerData.job then
            return false
        end
        
        if Player.PlayerData.job.name == Config.HackerJobName then
            if Config.JobRank > 0 then
                return Player.PlayerData.job.grade and Player.PlayerData.job.grade.level >= Config.JobRank
            else
                return true
            end
        end
        
        return false
    end, 'qbcore')
    
    if not jobCheckSuccess then
        LogError('ERROR', 'Failed to check job data', source)
        local success = pcall(cb, false)
        if not success then
            LogError('ERROR', 'Failed to execute callback after job check failure', source)
        end
        return
    end
    
    LogDebug('Job check result: ' .. tostring(hasJob), source)
    
    -- Final safe callback execution with timeout protection
    local success, error = pcall(cb, hasJob)
    if not success then
        LogError('ERROR', 'Failed to execute final callback in hasHackerJob: ' .. tostring(error), source)
    else
        LogDebug('hasHackerJob callback executed successfully', source)
    end
end)

-- Enhanced admin command with comprehensive error handling
QBCore.Commands.Add('givehackerlaptop', 'Give a hacker laptop to a player (Admin Only)', {
    {name = 'id', help = 'Player ID'}
}, true, function(source, args)
    local src = source
    
    -- Validate source
    if not src or type(src) ~= 'number' then
        LogError('ERROR', 'Invalid source in givehackerlaptop command', src)
        return
    end
    
    local AdminPlayer = SafeGetPlayer(src)
    if not AdminPlayer then
        LogError('WARN', 'Admin player not found', src)
        return
    end
    
    -- Server-side admin verification with error handling
    local hasPermSuccess, hasPermission = SafeExecute(function()
        return QBCore.Functions.HasPermission(src, 'admin')
    end, 'qbcore')
    
    if not hasPermSuccess or not hasPermission then
        LogError('WARN', 'Admin permission check failed or denied', src)
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        end, 'qbcore')
        return
    end
    
    -- Validate arguments
    if not args or not args[1] then
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Usage: /givehackerlaptop [player_id]', 'error')
        end, 'qbcore')
        return
    end
    
    -- Validate player ID input
    local targetId = tonumber(args[1])
    if not targetId or targetId <= 0 or targetId > 1024 then
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID (must be 1-1024)', 'error')
        end, 'qbcore')
        return
    end
    
    local Player = SafeGetPlayer(targetId)
    if not Player then
        LogError('WARN', 'Target player not found', targetId)
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        end, 'qbcore')
        return
    end
    
    -- Safe item addition
    local addItemSuccess = SafeExecute(function()
        Player.Functions.AddItem(Config.LaptopItem, 1)
        return true
    end, 'qbcore')
    
    if not addItemSuccess then
        LogError('ERROR', 'Failed to add laptop item to player inventory', targetId)
        SafeExecute(function()
            TriggerClientEvent('QBCore:Notify', src, 'Failed to give laptop - system error', 'error')
        end, 'qbcore')
        return
    end
    
    -- Safe inventory notification
    SafeExecute(function()
        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[Config.LaptopItem], 'add')
    end, 'inventory')
    
    -- Safe success notifications
    local playerName = 'Unknown'
    if Player.PlayerData and Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname then
        playerName = Player.PlayerData.charinfo.firstname
    end
    
    SafeExecute(function()
        TriggerClientEvent('QBCore:Notify', src, 'You gave a hacker laptop to ' .. playerName, 'success')
    end, 'qbcore')
    
    SafeExecute(function()
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You received a hacker laptop', 'success')
    end, 'qbcore')
    
    LogInfo('Admin gave laptop to player', src .. ' -> ' .. targetId)
end, 'admin')

-- Command to set job to hacker (Admin Only)
QBCore.Commands.Add('makehacker', 'Set player job to hacker (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'grade', help = 'Job Grade (0-4)'}
}, true, function(source, args)
    local src = source
    local AdminPlayer = QBCore.Functions.GetPlayer(src)
    
    -- Server-side admin verification
    if not AdminPlayer or not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    -- Validate inputs
    local targetId = tonumber(args[1])
    if not targetId or targetId <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID', 'error')
        return
    end
    
    local grade = tonumber(args[2]) or 0
    if grade < 0 or grade > 4 then 
        grade = math.max(0, math.min(4, grade)) -- Clamp between 0-4
    end
    
    local Player = QBCore.Functions.GetPlayer(targetId)
    if Player then
        Player.Functions.SetJob(Config.HackerJobName, grade)
        TriggerClientEvent('QBCore:Notify', src, 'You set ' .. Player.PlayerData.charinfo.firstname .. ' as a hacker (grade ' .. grade .. ')', 'success')
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You are now a hacker (grade ' .. grade .. ')', 'success')
        -- Admin job assignment completed
    else
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    end
end, 'admin')

-- Legacy logging function - now uses enhanced system
local function LegacyLogInfo(msg)
    LogInfo(msg, 'legacy')
end

-- Enhanced vehicle owner notification with error handling
RegisterServerEvent('qb-hackerjob:server:notifyDriver')
AddEventHandler('qb-hackerjob:server:notifyDriver', function(plate, message)
    local src = source
    
    -- Validate inputs
    if not src or type(src) ~= 'number' then
        LogError('ERROR', 'Invalid source in notifyDriver event', src)
        return
    end
    
    if not plate or type(plate) ~= 'string' or plate == '' then
        LogError('ERROR', 'Invalid plate in notifyDriver event', src)
        return
    end
    
    if not message or type(message) ~= 'string' then
        LogError('ERROR', 'Invalid message in notifyDriver event', src)
        return
    end
    
    -- Normalize and validate plate
    plate = plate:gsub("%s+", ""):upper()
    if not plate:match("^[A-Z0-9]+$") or string.len(plate) < 2 or string.len(plate) > 8 then
        LogError('ERROR', 'Invalid plate format in notifyDriver', plate)
        return
    end
    
    LogDebug('Notifying vehicle owner/driver', plate)
    
    -- Safely get all players
    local playersSuccess, players = SafeExecute(function()
        return QBCore.Functions.GetPlayers()
    end, 'qbcore')
    
    if not playersSuccess or not players then
        LogError('ERROR', 'Failed to get players list for notification')
        return
    end
    
    -- Notify players in vehicles
    for _, playerId in ipairs(players) do
        if type(playerId) == 'number' then
            local targetPlayer = SafeGetPlayer(playerId)
            if targetPlayer then
                SafeExecute(function()
                    TriggerClientEvent('qb-hackerjob:client:checkVehiclePlate', playerId, plate, message)
                end, 'qbcore')
            end
        end
    end
    
    -- Safe database query for vehicle owner
    SafeDBQuery('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', {plate}, function(result)
        if result and #result > 0 then
            local ownerId = result[1].citizenid
            
            if ownerId then
                -- Find the owner if they're online
                for _, playerId in ipairs(players) do
                    if type(playerId) == 'number' then
                        local targetPlayer = SafeGetPlayer(playerId)
                        
                        if targetPlayer and targetPlayer.PlayerData and targetPlayer.PlayerData.citizenid == ownerId then
                            SafeExecute(function()
                                TriggerClientEvent('QBCore:Notify', playerId, "Your vehicle with plate " .. plate .. " has been tampered with!", "error", 10000)
                            end, 'qbcore')
                            break
                        end
                    end
                end
            end
        end
    end)
end)

-- Enhanced laptop purchase callback with error handling
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyLaptop', function(source, cb)
    local src = source
    
    -- Validate inputs
    if not src or type(src) ~= 'number' then
        LogError('ERROR', 'Invalid source in canBuyLaptop callback', src)
        if cb then cb(false) end
        return
    end
    
    if not cb or type(cb) ~= 'function' then
        LogError('ERROR', 'Invalid callback in canBuyLaptop', src)
        return
    end
    
    local Player = SafeGetPlayer(src)
    if not Player then
        LogError('WARN', 'Player not found for laptop purchase', src)
        cb(false)
        return
    end
    
    -- Validate config
    if not Config.Vendor or not Config.Vendor.price or type(Config.Vendor.price) ~= 'number' then
        LogError('ERROR', 'Invalid vendor price configuration')
        cb(false)
        return
    end
    
    local price = Config.Vendor.price
    
    -- Safe money check and transaction
    local transactionSuccess, result = SafeExecute(function()
        if not Player.PlayerData or not Player.PlayerData.money then
            return false, 'Invalid player money data'
        end
        
        if Player.PlayerData.money.cash < price then
            return false, 'Insufficient funds'
        end
        
        -- Remove cash
        local removeSuccess = Player.Functions.RemoveMoney('cash', price, "bought-hacker-laptop")
        if not removeSuccess then
            return false, 'Failed to remove money'
        end
        
        -- Add laptop item
        local addSuccess = Player.Functions.AddItem(Config.LaptopItem, 1)
        if not addSuccess then
            -- Refund money if item addition failed
            Player.Functions.AddMoney('cash', price, "laptop-purchase-refund")
            return false, 'Failed to add item'
        end
        
        return true, 'Transaction successful'
    end, 'qbcore')
    
    if not transactionSuccess then
        LogError('WARN', 'Laptop purchase failed: ' .. tostring(result), src)
        cb(false)
        return
    end
    
    -- Safe inventory notification
    SafeExecute(function()
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.LaptopItem], 'add')
    end, 'inventory')
    
    LogInfo('Player purchased laptop', src)
    cb(true)
end)

-- Callback to check if player can buy a battery
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyBattery', function(source, cb)
    if not Config.Battery.enabled then
        cb(false)
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.Battery.batteryItemPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-laptop-battery")
        
        -- Add battery item
        Player.Functions.AddItem(Config.Battery.batteryItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.batteryItemName], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- Callback to check if player can buy a charger
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyCharger', function(source, cb)
    if not Config.Battery.enabled then
        cb(false)
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.Battery.chargerItemPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-laptop-charger")
        
        -- Add charger item
        Player.Functions.AddItem(Config.Battery.chargerItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.chargerItemName], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- Server callback to check if player has an item
QBCore.Functions.CreateCallback('qb-hackerjob:server:hasItem', function(source, cb, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        -- Player validation failed
        cb(false)
        return
    end
    
    local item = Player.Functions.GetItemByName(itemName)
    if item and item.amount > 0 then
        -- Item check successful
        cb(true)
    else
        -- Item not found
        cb(false)
    end
end)

-- Server event to remove an item (used for battery replacement)
RegisterServerEvent('qb-hackerjob:server:removeItem')
AddEventHandler('qb-hackerjob:server:removeItem', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        -- Player validation failed
        return 
    end
    
    -- Make sure player actually has the item
    local hasItem = Player.Functions.GetItemByName(itemName)
    if not hasItem or hasItem.amount < amount then
        -- Insufficient item quantity
        TriggerClientEvent('QBCore:Notify', src, "You don't have this item!", "error")
        return
    end
    
    -- Removing item from player
    
    -- Remove the item
    Player.Functions.RemoveItem(itemName, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    
    -- Item removal successful
end)

-- Database setup for logs only (XP now uses metadata)
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for database connection
    
    -- Create hacker_logs table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `activity` varchar(100) NOT NULL,
            `target` varchar(100) DEFAULT NULL,
            `success` tinyint(1) NOT NULL DEFAULT 0,
            `details` text DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Database initialization complete
end)

-- Server event to log hacking activities
RegisterServerEvent('qb-hackerjob:server:logActivity')
AddEventHandler('qb-hackerjob:server:logActivity', function(activity, target, success, details)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local charInfo = Player.PlayerData.charinfo
    local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
    
    -- Format details as string if it's a table
    if type(details) == 'table' then
        details = json.encode(details)
    end
    
    -- Log to database if enabled
    if Config.Logging.databaseLogs then
        MySQL.insert('INSERT INTO hacker_logs (citizenid, activity, target, success, details) VALUES (?, ?, ?, ?, ?)', {
            citizenid, activity, target, success and 1 or 0, details or ''
        })
    end
    
    -- Log to console if enabled
    if Config.Logging.consoleLogs then
        LogInfo(string.format("Player: %s | Activity: %s | Target: %s | Status: %s", 
            playerName, activity, target or 'N/A', success and "Success" or "Failed"))
    end
    
    -- Send to Discord webhook if enabled
    if Config.Logging.discordWebhook.enabled and Config.Logging.discordWebhook.url ~= "" then
        local statusText = success and "Success" or "Failed"
        local color = success and 65280 or 16711680 -- Green or Red
        
        local embed = {
            {
                ["title"] = "Hacker Activity Log",
                ["color"] = color,
                ["fields"] = {
                    {
                        ["name"] = "Player",
                        ["value"] = playerName .. " (" .. citizenid .. ")",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Activity",
                        ["value"] = activity,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Target",
                        ["value"] = target or "N/A",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Status",
                        ["value"] = statusText,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Details",
                        ["value"] = details or "None",
                        ["inline"] = false
                    }
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Logging.discordWebhook.url, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), {['Content-Type'] = 'application/json'})
    end
end)

-- View recent hacker logs (Admin Command)
QBCore.Commands.Add('hackerlogs', 'View recent hacker activity logs (Admin Only)', {
    {name = 'count', help = 'Number of logs to retrieve (default: 10)'}
}, true, function(source, args)
    local src = source
    local AdminPlayer = QBCore.Functions.GetPlayer(src)
    
    -- Server-side admin verification
    if not AdminPlayer or not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    local count = tonumber(args[1]) or 10
    
    if count > 100 then count = 100 end -- Limit to prevent spam
    
    MySQL.query('SELECT hl.*, p.charinfo FROM hacker_logs hl LEFT JOIN players p ON hl.citizenid = p.citizenid ORDER BY hl.created_at DESC LIMIT ?', {count}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "Displaying last " .. #result .. " hacker logs in console", "primary")
            print("[qb-hackerjob] ========== RECENT HACKER LOGS ==========")
            
            for i, log in ipairs(result) do
                local charInfo = log.charinfo and json.decode(log.charinfo) or {}
                local playerName = (charInfo.firstname or "Unknown") .. " " .. (charInfo.lastname or "Player")
                local status = log.success == 1 and "SUCCESS" or "FAILED"
                local timestamp = log.created_at
                
                print(string.format("[%d] %s | %s (%s) | %s -> %s | %s | %s", 
                    i, timestamp, playerName, log.citizenid, log.activity, log.target or "N/A", status, log.details or ""))
            end
            
            print("[qb-hackerjob] =============================================")
        else
            TriggerClientEvent('QBCore:Notify', src, "No hacker logs found", "error")
        end
    end)
end, 'admin')

-- GPS Tracker shop functionality
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyGPSTracker', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.GPSTrackerPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-gps-tracker")
        
        -- Add GPS tracker item
        Player.Functions.AddItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- GPS tracker check and removal
QBCore.Functions.CreateCallback('qb-hackerjob:server:checkAndRemoveGPS', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb(false)
        return
    end
    
    local item = Player.Functions.GetItemByName(Config.GPSTrackerItem)
    if item and item.amount > 0 then
        -- Remove one GPS tracker
        Player.Functions.RemoveItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], 'remove')
        cb(true)
    else
        cb(false)
    end
end)

-- Battery level saving
RegisterServerEvent('qb-hackerjob:server:saveBatteryLevel')
AddEventHandler('qb-hackerjob:server:saveBatteryLevel', function(batteryLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Validate battery level
    if type(batteryLevel) ~= 'number' or batteryLevel < 0 or batteryLevel > 100 then
        -- Invalid battery level data
        return
    end
    
    -- Save to player metadata
    Player.Functions.SetMetaData('laptopBattery', batteryLevel)
    -- Battery level saved
end)

-- ===== QBCORE METADATA-BASED XP SYSTEM =====

-- Initialize player XP metadata if not exists
local function InitializePlayerXP(Player)
    if not Player then return end
    
    -- Check if player has XP metadata, if not initialize it
    if not Player.PlayerData.metadata.hackerXP then
        Player.Functions.SetMetaData('hackerXP', 0)
    end
    if not Player.PlayerData.metadata.hackerLevel then
        Player.Functions.SetMetaData('hackerLevel', 1)
    end
    
    -- XP metadata initialized
end

-- Function to calculate level from XP
local function CalculateLevelFromXP(xp)
    for level = #Config.LevelThresholds, 1, -1 do
        if xp >= Config.LevelThresholds[level] then
            return level
        end
    end
    return 1
end

-- Function to get next level XP threshold
local function GetNextLevelXP(level)
    return Config.LevelThresholds[level + 1] or Config.LevelThresholds[#Config.LevelThresholds]
end

-- Award XP for hacking activities using metadata
RegisterServerEvent('hackerjob:awardXP')
AddEventHandler('hackerjob:awardXP', function(activityType)
    -- XP award event triggered
    
    if not Config.XPEnabled then 
        -- XP system disabled
        return 
    end
    
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        -- Player validation failed for XP award
        return 
    end
    
    -- Initialize XP if needed
    InitializePlayerXP(Player)
    
    local xpAmount = Config.XPSettings[activityType] or 0
    -- XP calculation complete
    
    if xpAmount <= 0 then 
        -- No XP configuration found
        return 
    end
    
    -- Get current XP and level from metadata
    local currentXP = Player.PlayerData.metadata.hackerXP or 0
    local currentLevel = Player.PlayerData.metadata.hackerLevel or 1
    
    -- Add XP
    local newXP = currentXP + xpAmount
    local newLevel = CalculateLevelFromXP(newXP)
    local nextLevelXP = GetNextLevelXP(newLevel)
    local levelName = Config.LevelNames[newLevel] or "Unknown"
    
    -- Update metadata
    Player.Functions.SetMetaData('hackerXP', newXP)
    Player.Functions.SetMetaData('hackerLevel', newLevel)
    
    -- XP update complete
    
    -- Notify player
    local leveledUp = newLevel > currentLevel
    if leveledUp then
        TriggerClientEvent('QBCore:Notify', src, "Level Up! You are now a " .. levelName, "success", 5000)
        TriggerClientEvent('QBCore:Notify', src, "+" .. xpAmount .. " XP gained!", "primary")
    else
        TriggerClientEvent('QBCore:Notify', src, "+" .. xpAmount .. " XP gained!", "success")
    end
    
    -- Update laptop UI if open
    TriggerClientEvent('hackerjob:updateStats', src, {
        level = newLevel,
        xp = newXP,
        nextLevelXP = nextLevelXP,
        levelName = levelName
    })
end)

-- Get player XP stats from metadata
QBCore.Functions.CreateCallback('hackerjob:getStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb({level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"})
        return 
    end
    
    -- Initialize XP if needed
    InitializePlayerXP(Player)
    
    -- Get data from metadata
    local xp = Player.PlayerData.metadata.hackerXP or 0
    local level = Player.PlayerData.metadata.hackerLevel or 1
    local nextLevelXP = GetNextLevelXP(level)
    local levelName = Config.LevelNames[level] or "Script Kiddie"
    
    -- Stats retrieved successfully
    
    cb({
        level = level,
        xp = xp,
        nextLevelXP = nextLevelXP,
        levelName = levelName
    })
end)

-- Admin command to give XP using metadata
QBCore.Commands.Add('givexp', 'Give XP to a player (Admin)', {
    {name = 'id', help = 'Player ID'},
    {name = 'amount', help = 'XP Amount'}
}, true, function(source, args)
    local src = source
    local AdminPlayer = QBCore.Functions.GetPlayer(src)
    
    -- Server-side admin verification
    if not AdminPlayer or not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('QBCore:Notify', source, "Invalid arguments", "error")
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(targetId)
    if not Player then
        TriggerClientEvent('QBCore:Notify', source, "Player not found", "error")
        return
    end
    
    -- Initialize XP if needed
    InitializePlayerXP(Player)
    
    -- Get current data from metadata
    local currentXP = Player.PlayerData.metadata.hackerXP or 0
    local currentLevel = Player.PlayerData.metadata.hackerLevel or 1
    
    -- Add XP
    local newXP = currentXP + amount
    local newLevel = CalculateLevelFromXP(newXP)
    local nextLevelXP = GetNextLevelXP(newLevel)
    local levelName = Config.LevelNames[newLevel] or "Unknown"
    
    -- Update metadata
    Player.Functions.SetMetaData('hackerXP', newXP)
    Player.Functions.SetMetaData('hackerLevel', newLevel)
    
    -- Notify admin and player
    TriggerClientEvent('QBCore:Notify', source, "Gave " .. amount .. " XP to " .. Player.PlayerData.charinfo.firstname, "success")
    TriggerClientEvent('QBCore:Notify', targetId, "Admin gave you " .. amount .. " XP!", "success")
    
    -- Update laptop UI if open
    TriggerClientEvent('hackerjob:updateStats', targetId, {
        level = newLevel,
        xp = newXP,
        nextLevelXP = nextLevelXP,
        levelName = levelName
    })
end, 'admin')

-- Initialize XP for players when they join
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    InitializePlayerXP(Player)
end)

-- Server script initialized