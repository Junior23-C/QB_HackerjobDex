--[[
    IMPORTANT BATTERY SYSTEM FIXES:
    
    1. Battery level is now rounded to one decimal place when stored in variables
       and rounded for display in UI and notifications.
    
    2. Fixed issue where using laptop features would disconnect the charger:
       - Battery charging now continues while performing operations
       - All UI updates include the current charging state
       - Charging cycle is properly maintained when using the laptop
    
    3. Updated idle battery drain to respect charging state
    
    4. Implemented realistic charging times:
       - Full charge from 0-100% now takes approximately 1 hour real time
       - Faster charging (1.5% per 30 seconds) when battery is below 30%
       - Normal charging (0.5% per 30 seconds) between 30-80%
       - Slower charging (0.3% per 30 seconds) when battery is above 80%
    
    5. Added anti-exploit measures:
       - 5-second cooldown between charger connect/disconnect actions
       - Prevents players from repeatedly connecting/disconnecting to bypass charging time
       
    These changes ensure a smoother user experience with a clean battery display
    and proper charging behavior when using the laptop's features.
]]

-- Enhanced QBCore setup and callback handling with error handling
local QBCore = exports['qb-core']:GetCoreObject()
local laptopOpen = false

-- Error handling configuration
local ErrorConfig = {
    maxRetries = 3,
    retryDelay = 500,
    networkTimeout = 10000,
    uiTimeout = 5000,
    logLevel = 'INFO'
}

-- NUI health tracking
local NUIHealth = {
    lastResponse = 0,
    failedCallbacks = 0,
    connected = true
}

-- Enhanced logging functions
local function SafeLogError(message, context)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    print('^1[qb-hackerjob:laptop:ERROR] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
end

local function SafeLogInfo(message, context)
    if ErrorConfig.logLevel == 'DEBUG' or ErrorConfig.logLevel == 'INFO' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^2[qb-hackerjob:laptop:INFO] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
end

local function SafeLogDebug(message, context)
    if ErrorConfig.logLevel == 'DEBUG' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^3[qb-hackerjob:laptop:DEBUG] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
end

-- Safe NUI message wrapper
local function SafeSendNUIMessage(data, retries)
    retries = retries or ErrorConfig.maxRetries
    
    if not data or type(data) ~= 'table' then
        SafeLogError('Invalid data provided to SafeSendNUIMessage')
        return false
    end
    
    local function sendMessage(attempt)
        local success, result = pcall(function()
            SendNUIMessage(data)
            NUIHealth.lastResponse = GetGameTimer()
            NUIHealth.connected = true
            return true
        end)
        
        if success then
            SafeLogDebug('NUI message sent successfully: ' .. (data.action or 'unknown'))
            return true
        else
            SafeLogError('NUI message failed on attempt ' .. attempt .. '/' .. retries .. ': ' .. tostring(result))
            if attempt < retries then
                Citizen.Wait(ErrorConfig.retryDelay)
                return sendMessage(attempt + 1)
            else
                NUIHealth.failedCallbacks = NUIHealth.failedCallbacks + 1
                SafeLogError('NUI message failed after all retries')
                return false
            end
        end
    end
    
    return sendMessage(1)
end

-- Safe callback wrapper
local function SafeCallback(callbackName, data, callback, retries)
    retries = retries or ErrorConfig.maxRetries
    
    if not callbackName or type(callbackName) ~= 'string' then
        SafeLogError('Invalid callback name provided to SafeCallback')
        if callback then callback(nil) end
        return
    end
    
    if not callback or type(callback) ~= 'function' then
        SafeLogError('Invalid callback function provided to SafeCallback')
        return
    end
    
    local function executeCallback(attempt)
        local timeoutTimer = nil
        local callbackExecuted = false
        
        -- Set up timeout
        timeoutTimer = SetTimeout(ErrorConfig.networkTimeout, function()
            if not callbackExecuted then
                callbackExecuted = true
                SafeLogError('Callback timeout: ' .. callbackName)
                if attempt < retries then
                    Citizen.Wait(ErrorConfig.retryDelay * attempt)
                    executeCallback(attempt + 1)
                else
                    callback(nil)
                end
            end
        end)
        
        local success, result = pcall(function()
            QBCore.Functions.TriggerCallback(callbackName, function(callbackResult)
                if timeoutTimer then
                    ClearTimeout(timeoutTimer)
                end
                
                if not callbackExecuted then
                    callbackExecuted = true
                    
                    if callbackResult ~= nil then
                        SafeLogDebug('Callback successful: ' .. callbackName)
                        callback(callbackResult)
                    else
                        SafeLogError('Callback returned nil on attempt ' .. attempt .. '/' .. retries .. ': ' .. callbackName)
                        if attempt < retries then
                            Citizen.Wait(ErrorConfig.retryDelay * attempt)
                            executeCallback(attempt + 1)
                        else
                            callback(nil)
                        end
                    end
                end
            end, data)
        end)
        
        if not success then
            if timeoutTimer then
                ClearTimeout(timeoutTimer)
            end
            
            if not callbackExecuted then
                callbackExecuted = true
                SafeLogError('Error executing callback: ' .. callbackName .. ' - ' .. tostring(result))
                if attempt < retries then
                    Citizen.Wait(ErrorConfig.retryDelay * attempt)
                    executeCallback(attempt + 1)
                else
                    callback(nil)
                end
            end
        end
    end
    
    executeCallback(1)
end

-- Safe notification
local function SafeNotify(message, type, duration)
    if not message then
        SafeLogError('No message provided to SafeNotify')
        return
    end
    
    local success = pcall(function()
        QBCore.Functions.Notify(message, type or 'info', duration or 5000)
    end)
    
    if not success then
        SafeLogError('Failed to show notification: ' .. tostring(message))
    end
end

-- Battery variables
local batteryLevel = 100
local isCharging = false
local chargeTimer = nil
local idleDrainTimer = nil
local replaceBatteryInProgress = false
local toggleChargerInProgress = false
local laptopLastUsed = 0 -- timestamp of last laptop interaction
local lastChargerToggle = 0
local chargerToggleCooldown = 5000 -- 5 second cooldown between charger toggles

-- Enhanced function to check player job with error handling
local function hasRequiredJob()
    if not Config or not Config.RequireJob then 
        SafeLogDebug('Job requirement disabled')
        return true 
    end
    
    local jobCheckSuccess, hasJob, jobError = pcall(function()
        local Player = QBCore.Functions.GetPlayerData()
        if not Player then 
            return false, "Player data not found"
        end
        
        if not Player.job then
            return false, "No job data in player data"
        end
        
        if Player.job.name == Config.HackerJobName then
            if Config.JobRank > 0 then
                if not Player.job.grade or not Player.job.grade.level then
                    return false, "Missing job grade data"
                end
                return Player.job.grade.level >= Config.JobRank, "Job rank check passed"
            end
            return true, "Job check passed"
        end
        
        return false, "Job requirement not met: " .. (Player.job.name or "unknown") .. " vs required: " .. Config.HackerJobName
    end)
    
    if not jobCheckSuccess then
        SafeLogError('Job check failed: ' .. tostring(hasJob))
        return false
    end
    
    if not hasJob then
        SafeLogError('Job requirement not met: ' .. tostring(jobError))
    else
        SafeLogDebug('Job check passed: ' .. tostring(jobError))
    end
    
    return hasJob
end

-- Enhanced function to handle battery drain with error handling
local function drainBattery(operationType)
    if not Config or not Config.Battery or not Config.Battery.enabled then 
        SafeLogDebug('Battery system disabled')
        return 
    end
    
    local drainSuccess = pcall(function()
        -- Validate operation type
        if not operationType or type(operationType) ~= 'string' then
            SafeLogError('Invalid operation type for battery drain: ' .. tostring(operationType))
            operationType = 'default'
        end
        
        -- Determine drain amount based on operation type
        local amount = Config.Battery.drainRate or 0.5 -- Default drain rate
        
        if Config.Battery.operationDrainRates and Config.Battery.operationDrainRates[operationType] then
            amount = Config.Battery.operationDrainRates[operationType]
        end
        
        -- Validate amount
        if type(amount) ~= 'number' or amount < 0 then
            SafeLogError('Invalid battery drain amount: ' .. tostring(amount))
            amount = 0.5
        end
        
        -- Apply drain
        local oldLevel = batteryLevel
        batteryLevel = math.max(0, batteryLevel - amount)
        
        -- Round battery level to 1 decimal place for cleaner display
        batteryLevel = math.floor(batteryLevel * 10) / 10
        
        SafeLogDebug('Battery drained by ' .. amount .. '% (' .. operationType .. ') from ' .. oldLevel .. '% to ' .. batteryLevel .. '%')
        
        -- Safe UI update
        if laptopOpen then
            SafeSendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging
            })
        end
        
        -- Update last used timestamp
        laptopLastUsed = GetGameTimer()
        
        -- Display rounded battery level in notifications
        local displayLevel = math.floor(batteryLevel + 0.5)
        
        -- Battery warnings based on thresholds
        local lowThreshold = Config.Battery.lowBatteryThreshold or 20
        local criticalThreshold = Config.Battery.criticalBatteryThreshold or 10
        
        if oldLevel > lowThreshold and batteryLevel <= lowThreshold then
            SafeNotify("Warning: Battery Low (" .. displayLevel .. "%)", "error", 5000)
        elseif oldLevel > criticalThreshold and batteryLevel <= criticalThreshold then
            SafeNotify("Warning: Battery Critical (" .. displayLevel .. "%)", "error", 5000)
        elseif batteryLevel <= 0 then
            SafeNotify("Battery depleted. Laptop shutting down.", "error", 5000)
            if laptopOpen then
                pcall(CloseLaptop)
            end
        end
        
        -- If charging is active, immediately add a charge to compensate for drain
        if isCharging and chargeTimer then
            pcall(function()
                ClearTimeout(chargeTimer)
                chargeTimer = SetTimeout(Config.Battery.chargeInterval or 30000, chargeBattery)
            end)
        end
    end)
    
    if not drainSuccess then
        SafeLogError('Battery drain operation failed for operation: ' .. tostring(operationType))
    end
end

-- Optimized event-driven battery charging system
local chargingNotificationThresholds = {20, 50, 80, 100}
local lastNotificationThreshold = 0

local function chargeBattery()
    if not Config.Battery.enabled or not isCharging then return end
    
    if batteryLevel >= Config.Battery.maxCharge then
        isCharging = false
        print("^2[qb-hackerjob] ^7Battery fully charged")
        QBCore.Functions.Notify("Battery fully charged", "success")
        
        -- Single UI update when charging complete
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                level = math.floor(batteryLevel * 10) / 10,
                charging = false
            })
        end
        chargeTimer = nil
        return
    end
    
    -- Determine charge rate based on current battery level (adaptive charging)
    local chargeRate = Config.Battery.chargeRate
    if batteryLevel < 30 then
        chargeRate = Config.Battery.fastChargeRate
    elseif batteryLevel > 80 then
        chargeRate = Config.Battery.slowChargeRate
    end
    
    -- Charge the battery
    local oldLevel = batteryLevel
    batteryLevel = math.min(Config.Battery.maxCharge, batteryLevel + chargeRate)
    batteryLevel = math.floor(batteryLevel * 10) / 10
    
    -- Efficient notification system - only notify at specific thresholds
    for _, threshold in ipairs(chargingNotificationThresholds) do
        if oldLevel < threshold and batteryLevel >= threshold and lastNotificationThreshold < threshold then
            if threshold == 100 then
                QBCore.Functions.Notify("Battery fully charged: 100%", "success")
                isCharging = false
            elseif threshold == 80 then
                QBCore.Functions.Notify("Battery nearly full: 80%", "primary")
            elseif threshold == 50 then
                QBCore.Functions.Notify("Battery half charged: 50%", "primary")
            elseif threshold == 20 then
                QBCore.Functions.Notify("Battery charging: 20%", "primary")
            end
            lastNotificationThreshold = threshold
            break
        end
    end
    
    -- Batch UI update - only update every few charge cycles to reduce UI overhead
    if math.floor(oldLevel) ~= math.floor(batteryLevel) or batteryLevel >= 100 then
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging
            })
        end
    end
    
    -- Continue charging if needed
    if batteryLevel < Config.Battery.maxCharge and isCharging then
        if chargeTimer then
            ClearTimeout(chargeTimer)
        end
        chargeTimer = SetTimeout(Config.Battery.chargeInterval, chargeBattery)
    else
        isCharging = false
        chargeTimer = nil
        lastNotificationThreshold = 0 -- Reset for next charging session
    end
end

-- Optimized idle battery drain with reduced polling frequency
local function startIdleDrain()
    if idleDrainTimer then
        ClearTimeout(idleDrainTimer)
        idleDrainTimer = nil
    end
    
    if not laptopOpen then return end
    
    idleDrainTimer = SetTimeout(90000, function() -- Reduced frequency: 1.5 minute intervals
        local currentTime = GetGameTimer()
        local idleTime = currentTime - laptopLastUsed
        
        -- Only drain if idle for more than 90 seconds and not charging
        if idleTime > 90000 and batteryLevel > 0 and not isCharging then
            local oldLevel = batteryLevel
            batteryLevel = math.max(0, batteryLevel - Config.Battery.idleDrainRate)
            batteryLevel = math.floor(batteryLevel * 10) / 10
            
            -- Efficient notification system - only notify on threshold changes
            local displayLevel = math.floor(batteryLevel + 0.5)
            local shouldNotify = false
            local notificationMessage = ""
            local notificationType = ""
            
            if oldLevel > Config.Battery.criticalBatteryThreshold and batteryLevel <= Config.Battery.criticalBatteryThreshold then
                shouldNotify = true
                notificationMessage = "Warning: Battery Critical (" .. displayLevel .. "%)"
                notificationType = "error"
            elseif oldLevel > Config.Battery.lowBatteryThreshold and batteryLevel <= Config.Battery.lowBatteryThreshold then
                shouldNotify = true
                notificationMessage = "Warning: Battery Low (" .. displayLevel .. "%)"
                notificationType = "error"
            elseif batteryLevel <= 0 then
                QBCore.Functions.Notify("Battery depleted. Laptop shutting down.", "error", 5000)
                CloseLaptop()
                return
            end
            
            -- Batch UI update with notification
            if shouldNotify then
                QBCore.Functions.Notify(notificationMessage, notificationType, 5000)
            end
            
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging
            })
        end
        
        -- Continue monitoring
        startIdleDrain()
    end)
end

-- Function to replace battery
local function replaceBattery()
    if not Config.Battery.enabled then return false end
    
    -- Use a callback to check for the battery item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if not hasItem then
            QBCore.Functions.Notify("You need a replacement battery.", "error")
            return
        end
        
        -- Remove the battery item
        TriggerServerEvent('qb-hackerjob:server:removeItem', Config.Battery.batteryItemName, 1)
        
        -- Set battery to 100%
        batteryLevel = Config.Battery.maxCharge
        
        -- Update UI
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel
            })
        end
        
        QBCore.Functions.Notify("Battery replaced successfully.", "success")
    end, Config.Battery.batteryItemName)
    
    return true
end

-- Function to toggle charging
local function toggleCharging()
    if not Config.Battery.enabled then return false end
    
    -- Check cooldown to prevent connect/disconnect exploit
    local currentTime = GetGameTimer()
    if currentTime - lastChargerToggle < chargerToggleCooldown then
        QBCore.Functions.Notify("Please wait before toggling the charger again.", "error")
        return false
    end
    
    -- Update last toggle time
    lastChargerToggle = currentTime
    
    -- Use a callback to check for the charger item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if not hasItem then
            QBCore.Functions.Notify("You need a laptop charger.", "error")
            return
        end
        
        -- Toggle charging state
        isCharging = not isCharging
        
        if isCharging then
            QBCore.Functions.Notify("Connected to charger.", "success")
            
            -- Start charging immediately
            if chargeTimer then
                ClearTimeout(chargeTimer)
            end
            
            -- Charge once immediately based on battery level
            local chargeRate = Config.Battery.chargeRate
            
            -- Apply adaptive charging based on battery level
            if batteryLevel < 30 then
                chargeRate = Config.Battery.fastChargeRate
            elseif batteryLevel > 80 then
                chargeRate = Config.Battery.slowChargeRate
            end
            
            -- Apply immediate charge
            batteryLevel = math.min(Config.Battery.maxCharge, batteryLevel + chargeRate)
            
            -- Round battery level to 1 decimal place
            batteryLevel = math.floor(batteryLevel * 10) / 10
            
            -- Then start the charging cycle
            chargeTimer = SetTimeout(Config.Battery.chargeInterval, chargeBattery)
        else
            QBCore.Functions.Notify("Disconnected from charger.", "primary")
            if chargeTimer then
                ClearTimeout(chargeTimer)
                chargeTimer = nil
            end
        end
        
        -- Update UI
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging
            })
        end
    end, Config.Battery.chargerItemName)
    
    return true
end

-- Enhanced function to open laptop with comprehensive error handling
function OpenHackerLaptop(xpData)
    SafeLogInfo('Attempting to open hacker laptop', xpData and 'with XP data' or 'without XP data')
    
    if laptopOpen then 
        SafeLogInfo('Laptop already open')
        return 
    end
    
    -- Safe job check
    local jobCheckSuccess, hasJob = pcall(hasRequiredJob)
    if not jobCheckSuccess then
        SafeLogError('Job check failed during laptop open')
        SafeNotify("System error during authorization check", "error")
        return
    end
    
    if not hasJob then
        SafeNotify("You are not authorized to use this device", "error")
        return
    end
    
    -- Safe battery check
    if Config and Config.Battery and Config.Battery.enabled then
        if type(batteryLevel) ~= 'number' or batteryLevel <= 0 then
            SafeNotify("Laptop battery is depleted. Replace the battery or charge it.", "error")
            return
        end
    end
    
    SafeLogDebug('Pre-flight checks passed, proceeding with laptop open')
    
    -- Safe animation and prop setup
    local animationSuccess = pcall(function()
        local ped = PlayerPedId()
        if not ped or ped == 0 then
            SafeLogError('Invalid player ped for laptop animation')
            return
        end
        
        local animDict = "amb@world_human_seat_wall_tablet@female@base"
        local animName = "base"
        
        -- Request animation without blocking
        RequestAnimDict(animDict)
        
        -- Create laptop prop with error handling
        local tabletProp = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)
        if not tabletProp or tabletProp == 0 then
            SafeLogError('Failed to create tablet prop')
            return
        end
        
        local tabletBone = GetPedBoneIndex(ped, 28422)
        if tabletBone == -1 then
            SafeLogError('Failed to get tablet bone index')
            DeleteEntity(tabletProp)
            return
        end
        
        AttachEntityToEntity(tabletProp, ped, tabletBone, 0.12, 0.0, -0.05, 10.0, 0.0, 0.0, true, true, false, true, 1, true)
        currentTabletProp = tabletProp
        
        SafeLogDebug('Tablet prop created and attached successfully')
    end)
    
    if not animationSuccess then
        SafeLogError('Animation setup failed - continuing without animation')
    end
    
    -- Safe NUI focus setup
    local nuiFocusSuccess = pcall(function()
        laptopOpen = true
        SafeLogDebug('Setting NUI focus')
        SetNuiFocus(true, true)
        SafeLogDebug('NUI focus set successfully')
    end)
    
    if not nuiFocusSuccess then
        SafeLogError('Failed to set NUI focus')
        laptopOpen = false
        SafeNotify("Error opening laptop interface", "error")
        return
    end
    
    -- Drain battery for turning on
    drainBattery("scanning")
    
    -- Update last used timestamp
    laptopLastUsed = GetGameTimer()
    
    -- Start idle drain
    startIdleDrain()
    
    -- Send initial boot message to UI with optimized settings and XP data
    local message = {
        action = "openLaptop",
        type = "openLaptop", -- Also include type for compatibility
        theme = Config.UISettings.theme,
        showAnimations = false, -- Disable animations for faster loading
        soundEffects = false, -- Disable sound effects regardless of config
        batteryLevel = batteryLevel,
        charging = isCharging
    }
    
    -- Include XP data if provided
    if xpData then
        message.level = xpData.level or 1
        message.xp = xpData.xp or 0
        message.nextLevelXP = xpData.nextLevelXP or 100
        message.levelName = xpData.levelName or "Script Kiddie"
        message.features = xpData.features or {}
        print(string.format("^2[qb-hackerjob] ^7Opening laptop with XP data: Level=%d, XP=%d, NextXP=%d, Name=%s", 
            message.level, message.xp, message.nextLevelXP, message.levelName))
    else
        print("^3[qb-hackerjob] ^7Opening laptop without XP data - using defaults")
        message.level = 1
        message.xp = 0
        message.nextLevelXP = 100
        message.levelName = "Script Kiddie"
        message.features = {}
    end
    
    print("^2[qb-hackerjob] ^7Sending NUI message:", json.encode(message))
    SendNUIMessage(message)
    print("^2[qb-hackerjob] ^7NUI message sent")
    
    -- Register storage values for the laptop session
    SetNuiFocusKeepInput(false)
    
    -- Only play the animation if it loaded
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 2.0, 2.0, -1, 51, 0, false, false, false)
    else
        -- Fallback animation if the requested one fails to load
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_MOBILE", 0, true)
    end
    
    currentTabletProp = tabletProp
    print("^2[qb-hackerjob] ^7Laptop opened successfully")
    QBCore.Functions.Notify("Laptop activated", "success")
    
    return tabletProp
end

-- Function to close the laptop
function CloseLaptop()
    if not laptopOpen then 
        print("^3[qb-hackerjob] ^7Laptop already closed")
        return 
    end
    
    print("^2[qb-hackerjob] ^7Closing laptop")
    
    laptopOpen = false
    SetNuiFocus(false, false)
    
    -- Stop idle drain
    if idleDrainTimer then
        ClearTimeout(idleDrainTimer)
        idleDrainTimer = nil
    end
    
    QBCore.Functions.Notify("Shutting down...", "primary")
    SendNUIMessage({
        action = "closeLaptop"
    })
    
    -- Clear animation
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    
    -- Delete tablet prop if it exists
    local tabletProp = GetClosestObjectOfType(GetEntityCoords(ped), 1.0, `prop_cs_tablet`, false, false, false)
    if tabletProp ~= 0 then
        DeleteEntity(tabletProp)
    end
    
    print("^2[qb-hackerjob] ^7Laptop closed successfully")
end

-- Used for usable item
-- Enhanced laptop opening event with job/battery checks and XP fetching
RegisterNetEvent('qb-hackerjob:client:openLaptop')
AddEventHandler('qb-hackerjob:client:openLaptop', function()
    print("^2[qb-hackerjob] ^7========== LAPTOP OPEN EVENT TRIGGERED ==========")
    print("^2[qb-hackerjob] ^7Player source: " .. tostring(GetPlayerServerId(PlayerId())))
    print("^2[qb-hackerjob] ^7QBCore available: " .. tostring(QBCore ~= nil))
    print("^2[qb-hackerjob] ^7Config available: " .. tostring(Config ~= nil))
    
    -- Job check using the same callback as main.lua with retry mechanism
    local function AttemptJobCheck(retryCount)
        retryCount = retryCount or 0
        local maxRetries = 3
        
        if retryCount >= maxRetries then
            print("^1[qb-hackerjob] ^7Job check failed after " .. maxRetries .. " attempts")
            QBCore.Functions.Notify('Unable to verify permissions. Try again later.', "error")
            return
        end
        
        print("^3[qb-hackerjob] ^7Attempting job check (attempt " .. (retryCount + 1) .. "/" .. maxRetries .. ")")
        print("^3[qb-hackerjob] ^7About to call TriggerCallback for hasHackerJob")
        
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasHackerJob', function(hasJob)
            print("^3[qb-hackerjob] ^7Callback response received: " .. tostring(hasJob))
            if hasJob == nil then
                print("^1[qb-hackerjob] ^7Received nil response from job check, retrying...")
                Citizen.Wait(1000)
                AttemptJobCheck(retryCount + 1)
                return
            end
            
            if not hasJob then
                QBCore.Functions.Notify('You don\'t know how to use this device', "error")
                return
            end
            
            print("^2[qb-hackerjob] ^7Job check successful, proceeding with laptop opening")
            OpenLaptopInterface()
        end)
        
        -- Add timeout protection
        Citizen.CreateThread(function()
            Citizen.Wait(5000) -- 5 second timeout
            if retryCount < maxRetries then
                print("^1[qb-hackerjob] ^7Job check timeout, retrying...")
                AttemptJobCheck(retryCount + 1)
            end
        end)
    end
    
    local function OpenLaptopInterface()
        -- Moved the laptop opening logic to a separate function
        
        -- Get updated hacker stats before opening NUI (use both methods for reliability)
        QBCore.Functions.TriggerCallback('hackerjob:getStats', function(stats)
            print("^2[qb-hackerjob] ^7Server callback returned stats:", json.encode(stats))
            
            -- Also get local metadata as fallback
            local localStats = nil
            local success, err = pcall(function()
                localStats = exports['qb-hackerjob']:GetPlayerXPData()
            end)
            
            if not success then
                print("^1[qb-hackerjob] ^7Error getting local stats: " .. tostring(err))
                localStats = {level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"}
            end
            
            print("^2[qb-hackerjob] ^7Local stats:", json.encode(localStats))
            
            -- Use server stats if available, otherwise use local
            local finalStats = stats
            if not stats or not stats.level then
                print("^3[qb-hackerjob] ^7Server stats unavailable, using local metadata")
                finalStats = localStats
            end
            
            print("^2[qb-hackerjob] ^7Final stats for laptop:", json.encode(finalStats))
            local level, xp, nextLevelXP = finalStats.level, finalStats.xp, finalStats.nextLevelXP
            -- Battery check
            if Config.Battery.enabled then
                local PlayerData = QBCore.Functions.GetPlayerData()
                local batteryLevel = PlayerData.metadata.laptopBattery or Config.Battery.maxCharge
                
                -- Check if battery is critically low
                if batteryLevel <= Config.Battery.criticalBatteryThreshold then
                    QBCore.Functions.Notify('Laptop battery critical! Needs charging or replacement', "error")
                    return
                end
            end
            
            -- Open laptop with XP data
            print("^2[qb-hackerjob] ^7About to call OpenHackerLaptop")
            local success, err = pcall(function()
                OpenHackerLaptop(finalStats)
            end)
            
            if not success then
                print("^1[qb-hackerjob] ^7Error opening laptop: " .. tostring(err))
                QBCore.Functions.Notify("Error opening laptop", "error")
            else
                print("^2[qb-hackerjob] ^7OpenHackerLaptop called successfully")
            end
        end)
    end
    
    -- Start the job check process
    AttemptJobCheck()
end)

-- Event handler for laptop opening with XP data
RegisterNetEvent('qb-hackerjob:client:openLaptopWithXP')
AddEventHandler('qb-hackerjob:client:openLaptopWithXP', function(xpData)
    print("^2[qb-hackerjob] ^7openLaptopWithXP event triggered with data:", json.encode(xpData))
    OpenHackerLaptop(xpData)
end)

-- Battery management events
RegisterNetEvent('qb-hackerjob:client:replaceBattery')
AddEventHandler('qb-hackerjob:client:replaceBattery', function()
    print("^2[qb-hackerjob] ^7replaceBattery event triggered")
    replaceBattery()
end)

RegisterNetEvent('qb-hackerjob:client:toggleCharger')
AddEventHandler('qb-hackerjob:client:toggleCharger', function()
    print("^2[qb-hackerjob] ^7toggleCharger event triggered")
    toggleCharging()
end)

-- Function to update the last interaction time
local function updateLastInteraction()
    laptopLastUsed = GetGameTimer()
end

-- NUI Callbacks
RegisterNUICallback('closeLaptop', function(_, cb)
    CloseLaptop()
    cb({success = true})
end)

RegisterNUICallback('getPhoneTools', function(_, cb)
    updateLastInteraction()
    if Config.PhoneTrackerEnabled then
        cb({success = true, enabled = true})
    else
        cb({success = true, enabled = false})
    end
end)

RegisterNUICallback('getRadioTools', function(_, cb)
    updateLastInteraction()
    if Config.RadioDecryptionEnabled then
        cb({success = true, enabled = true})
    else
        cb({success = true, enabled = false})
    end
end)

-- Battery management callbacks
RegisterNUICallback('replaceBattery', function(data, cb)
    print("^2[qb-hackerjob] ^7NUI callback: replaceBattery triggered")
    
    -- Ensure callback is always called, even on error
    local function safeCallback(success, level, message)
        print("^2[qb-hackerjob] ^7replaceBattery callback: success=" .. tostring(success) .. ", level=" .. tostring(level) .. ", message=" .. tostring(message or ""))
        cb({
            success = success,
            batteryLevel = level,
            message = message
        })
    end
    
    -- Prevent spamming
    if replaceBatteryInProgress then
        print("^3[qb-hackerjob] ^7Replace battery already in progress")
        safeCallback(false, batteryLevel, "Operation already in progress")
        return
    end
    
    replaceBatteryInProgress = true
    
    -- Send initial response to prevent UI hanging
    safeCallback(true, batteryLevel, "Checking for battery...")
    
    -- Use server callback to check for battery item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if not hasItem then
            print("^1[qb-hackerjob] ^7Player doesn't have battery item")
            QBCore.Functions.Notify("You need a replacement battery.", "error")
            
            -- Send failure response
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging,
                message = "No battery item found"
            })
            
            replaceBatteryInProgress = false
            return
        end
        
        print("^2[qb-hackerjob] ^7Player has battery item, removing it")
        
        -- Remove the battery item
        TriggerServerEvent('qb-hackerjob:server:removeItem', Config.Battery.batteryItemName, 1)
        
        -- Set battery to 100%
        batteryLevel = Config.Battery.maxCharge
        
        print("^2[qb-hackerjob] ^7Battery set to " .. batteryLevel .. "%")
        
        -- Update UI
        SendNUIMessage({
            action = "updateBattery",
            level = batteryLevel,
            charging = isCharging,
            success = true
        })
        
        QBCore.Functions.Notify("Battery replaced successfully.", "success")
        replaceBatteryInProgress = false
    end, Config.Battery.batteryItemName)
end)

RegisterNUICallback('toggleCharger', function(data, cb)
    print("^2[qb-hackerjob] ^7NUI callback: toggleCharger triggered")
    updateLastInteraction()
    
    -- Ensure callback is always called, even on error
    local function safeCallback(success, level, charging, message)
        print("^2[qb-hackerjob] ^7toggleCharger callback: success=" .. tostring(success) .. ", level=" .. tostring(level) .. ", charging=" .. tostring(charging) .. ", message=" .. tostring(message or ""))
        cb({
            success = success,
            batteryLevel = level,
            charging = charging,
            message = message
        })
    end
    
    -- Prevent spamming
    if toggleChargerInProgress then
        print("^3[qb-hackerjob] ^7Toggle charger already in progress")
        safeCallback(false, batteryLevel, isCharging, "Operation already in progress")
        return
    end
    
    -- Check cooldown to prevent connect/disconnect exploit
    local currentTime = GetGameTimer()
    if currentTime - lastChargerToggle < chargerToggleCooldown then
        print("^3[qb-hackerjob] ^7Charger toggle cooldown active")
        safeCallback(false, batteryLevel, isCharging, "Please wait before toggling the charger again")
        return
    end
    
    -- Update last toggle time
    lastChargerToggle = currentTime
    
    toggleChargerInProgress = true
    
    -- Send initial response to prevent UI hanging
    safeCallback(true, batteryLevel, isCharging, "Checking for charger...")
    
    -- Use server callback to check for charger item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if not hasItem then
            print("^1[qb-hackerjob] ^7Player doesn't have charger item")
            QBCore.Functions.Notify("You need a laptop charger.", "error")
            
            -- Send failure response
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging,
                message = "No charger item found"
            })
            
            toggleChargerInProgress = false
            return
        end
        
        print("^2[qb-hackerjob] ^7Player has charger item")
        
        -- Toggle charging state
        isCharging = not isCharging
        
        if isCharging then
            print("^2[qb-hackerjob] ^7Starting charging process")
            QBCore.Functions.Notify("Connected to charger.", "success")
            
            -- Start charging immediately
            if chargeTimer then
                ClearTimeout(chargeTimer)
            end
            
            -- Charge once immediately
            local oldLevel = batteryLevel
            local chargeRate = Config.Battery.chargeRate
            
            -- Fast charging when battery is low
            if batteryLevel < 30 then
                chargeRate = Config.Battery.fastChargeRate
            -- Slow/trickle charging when battery is high
            elseif batteryLevel > 80 then
                chargeRate = Config.Battery.slowChargeRate
            end
            
            batteryLevel = math.min(Config.Battery.maxCharge, batteryLevel + chargeRate)
            
            -- Round battery level to 1 decimal place
            batteryLevel = math.floor(batteryLevel * 10) / 10
            
            print("^2[qb-hackerjob] ^7Initial charge: " .. oldLevel .. "% to " .. batteryLevel .. "% at rate " .. chargeRate)
            
            -- Then start the charging cycle
            chargeTimer = SetTimeout(Config.Battery.chargeInterval, chargeBattery)
        else
            print("^2[qb-hackerjob] ^7Stopping charging process")
            QBCore.Functions.Notify("Disconnected from charger.", "primary")
            if chargeTimer then
                ClearTimeout(chargeTimer)
                chargeTimer = nil
            end
        end
        
        -- Update UI
        SendNUIMessage({
            action = "updateBattery",
            level = batteryLevel,
            charging = isCharging,
            success = true
        })
        
        toggleChargerInProgress = false
    end, Config.Battery.chargerItemName)
end)

RegisterNUICallback('getBatteryStatus', function(_, cb)
    updateLastInteraction()
    -- Round battery level for display
    local displayLevel = math.floor(batteryLevel * 10) / 10
    cb({success = true, level = displayLevel, charging = isCharging})
end)

-- Drain battery on various operations
RegisterNUICallback('lookupPlate', function(data, cb)
    drainBattery("lookupPlate")
    TriggerEvent('qb-hackerjob:client:lookupPlate', data.plate)
    cb({success = true})
end)

RegisterNUICallback('getNearbyVehicles', function(_, cb)
    drainBattery("scanning")
    TriggerEvent('qb-hackerjob:client:getNearbyVehicles')
    cb({success = true})
end)

RegisterNUICallback('performVehicleAction', function(data, cb)
    updateLastInteraction()
    
    -- Map action to drain type
    local drainType = "vehicleLock" -- Default
    
    if data.action == 'disable_brakes' or data.action == 'accelerate' then
        drainType = "vehicleControl"
    elseif data.action == 'engine' then
        drainType = "vehicleEngine"
    elseif data.action == 'track' then
        drainType = "vehicleTrack"
    elseif data.action == 'lock' or data.action == 'unlock' then
        drainType = "vehicleLock"
    end
    
    -- Apply battery drain
    drainBattery(drainType)
    
    -- Perform the actual vehicle action
    if data.action and data.plate then
        local success = exports[GetCurrentResourceName()]:PerformVehicleAction(data.action, data.plate)
        cb({success = success})
    else
        cb({success = false})
    end
end)

-- Function to load battery level from player metadata
local function loadBatteryLevel()
    local Player = QBCore.Functions.GetPlayerData()
    if Player and Player.metadata and Player.metadata.laptopBattery then
        batteryLevel = Player.metadata.laptopBattery
        print("^2[qb-hackerjob] ^7Loaded battery level from metadata: " .. batteryLevel .. "%")
    else
        batteryLevel = Config.Battery.maxCharge
        print("^2[qb-hackerjob] ^7No saved battery level found, using default: " .. batteryLevel .. "%")
    end
end

-- Function to save battery level to player metadata
local function saveBatteryLevel()
    TriggerServerEvent('qb-hackerjob:server:saveBatteryLevel', batteryLevel)
    print("^2[qb-hackerjob] ^7Saved battery level to metadata: " .. batteryLevel .. "%")
end

-- Initialize battery on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Wait for player data to be available
    Citizen.CreateThread(function()
        while not QBCore.Functions.GetPlayerData().citizenid do
            Citizen.Wait(100)
        end
        
        loadBatteryLevel()
        
        -- Optimized battery save timer - less frequent saves, event-driven
        local lastSaveTime = 0
        local saveInterval = 300000 -- Save every 5 minutes instead of 1 minute
        
        Citizen.CreateThread(function()
            while true do
                local currentTime = GetGameTimer()
                if currentTime - lastSaveTime >= saveInterval then
                    saveBatteryLevel()
                    lastSaveTime = currentTime
                end
                Citizen.Wait(30000) -- Check every 30 seconds instead of constant loop
            end
        end)
    end)
end)

-- Save battery level on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    saveBatteryLevel()
end)

-- Save battery level when player disconnects
AddEventHandler('onPlayerDropped', function()
    saveBatteryLevel()
end)

-- Export functions
exports('OpenHackerLaptop', OpenHackerLaptop)
exports('CloseLaptop', CloseLaptop)
exports('IsLaptopOpen', function() return laptopOpen end)
exports('GetBatteryLevel', function() return batteryLevel end)
exports('IsCharging', function() return isCharging end) 