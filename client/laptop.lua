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

-- QBCore setup and callback handling
local QBCore = exports['qb-core']:GetCoreObject()
local laptopOpen = false

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

-- Function to check player job
local function hasRequiredJob()
    if not Config.RequireJob then return true end
    
    local Player = QBCore.Functions.GetPlayerData()
    if not Player then 
        print("^1[qb-hackerjob] ^7Player data not found")
        return false 
    end
    
    if Player.job and Player.job.name == Config.HackerJobName then
        if Config.JobRank > 0 then
            return Player.job.grade.level >= Config.JobRank
        end
        return true
    end
    
    print("^1[qb-hackerjob] ^7Job requirement not met: " .. (Player.job and Player.job.name or "unknown") .. " vs required: " .. Config.HackerJobName)
    return false
end

-- Function to handle battery drain
local function drainBattery(operationType)
    if not Config.Battery.enabled then return end
    
    -- Determine drain amount based on operation type
    local amount = Config.Battery.drainRate -- Default drain rate
    
    if operationType and Config.Battery.operationDrainRates[operationType] then
        amount = Config.Battery.operationDrainRates[operationType]
    end
    
    -- Apply drain
    local oldLevel = batteryLevel
    batteryLevel = math.max(0, batteryLevel - amount)
    
    -- Round battery level to 1 decimal place for cleaner display
    batteryLevel = math.floor(batteryLevel * 10) / 10
    
    print("^2[qb-hackerjob] ^7Battery drained by " .. amount .. "% (" .. operationType .. ") from " .. oldLevel .. "% to " .. batteryLevel .. "%")
    
    -- Update UI with new battery level
    if laptopOpen then
        SendNUIMessage({
            action = "updateBattery",
            level = batteryLevel,
            charging = isCharging -- Always send charging state with battery updates
        })
    end
    
    -- Update last used timestamp
    laptopLastUsed = GetGameTimer()
    
    -- Display rounded battery level in notifications
    local displayLevel = math.floor(batteryLevel + 0.5)
    
    -- Battery warnings based on thresholds
    if oldLevel > Config.Battery.lowBatteryThreshold and batteryLevel <= Config.Battery.lowBatteryThreshold then
        QBCore.Functions.Notify("Warning: Battery Low (" .. displayLevel .. "%)", "error", 5000)
    elseif oldLevel > Config.Battery.criticalBatteryThreshold and batteryLevel <= Config.Battery.criticalBatteryThreshold then
        QBCore.Functions.Notify("Warning: Battery Critical (" .. displayLevel .. "%)", "error", 5000)
    elseif batteryLevel <= 0 then
        QBCore.Functions.Notify("Battery depleted. Laptop shutting down.", "error", 5000)
        if laptopOpen then
            CloseLaptop()
        end
    end
    
    -- If charging is active, immediately add a charge to compensate for drain
    -- This prevents operations from "disconnecting" the charger
    if isCharging and chargeTimer then
        ClearTimeout(chargeTimer) -- Clear existing timer
        chargeTimer = SetTimeout(Config.Battery.chargeInterval, chargeBattery) -- Set new timer
    end
end

-- Function to handle battery charging
local function chargeBattery()
    if not Config.Battery.enabled or not isCharging then return end
    
    -- Debug print
    print("^2[qb-hackerjob] ^7chargeBattery called. Current level: " .. batteryLevel)
    
    if batteryLevel >= Config.Battery.maxCharge then
        isCharging = false
        print("^2[qb-hackerjob] ^7Battery fully charged")
        QBCore.Functions.Notify("Battery fully charged", "success")
        
        -- Update UI
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                level = math.floor(batteryLevel * 10) / 10, -- Round to 1 decimal place
                charging = false
            })
        end
        return
    end
    
    -- Determine charge rate based on current battery level (adaptive charging)
    local chargeRate = Config.Battery.chargeRate -- Default charge rate
    
    -- Fast charging when battery is low (below 30%)
    if batteryLevel < 30 then
        chargeRate = Config.Battery.fastChargeRate
        print("^2[qb-hackerjob] ^7Fast charging applied at " .. chargeRate .. "% per tick")
    -- Slow/trickle charging when battery is high (above 80%)
    elseif batteryLevel > 80 then
        chargeRate = Config.Battery.slowChargeRate
        print("^2[qb-hackerjob] ^7Slow charging applied at " .. chargeRate .. "% per tick")
    end
    
    -- Charge the battery
    local oldLevel = batteryLevel
    batteryLevel = math.min(Config.Battery.maxCharge, batteryLevel + chargeRate)
    
    -- Round battery level to 1 decimal place
    batteryLevel = math.floor(batteryLevel * 10) / 10
    
    print("^2[qb-hackerjob] ^7Battery charged from " .. oldLevel .. "% to " .. batteryLevel .. "%")
    
    -- Update UI with new battery level
    if laptopOpen then
        SendNUIMessage({
            action = "updateBattery",
            level = batteryLevel,
            charging = isCharging
        })
    end
    
    -- Display rounded battery level in notifications
    local displayLevel = math.floor(batteryLevel + 0.5)
    
    -- Notifications at certain levels
    if oldLevel < 20 and batteryLevel >= 20 then
        QBCore.Functions.Notify("Battery charging: 20%", "primary")
    elseif oldLevel < 50 and batteryLevel >= 50 then
        QBCore.Functions.Notify("Battery half charged: 50%", "primary")
    elseif oldLevel < 80 and batteryLevel >= 80 then
        QBCore.Functions.Notify("Battery nearly full: 80%", "primary")
    elseif oldLevel < 100 and batteryLevel >= 100 then
        QBCore.Functions.Notify("Battery fully charged: 100%", "success")
        isCharging = false
    end
    
    -- Schedule next charge if not full and still charging
    if batteryLevel < Config.Battery.maxCharge and isCharging then
        if chargeTimer then
            ClearTimeout(chargeTimer)
        end
        chargeTimer = SetTimeout(Config.Battery.chargeInterval, chargeBattery)
        print("^2[qb-hackerjob] ^7Scheduled next charge in " .. Config.Battery.chargeInterval/1000 .. " seconds")
    else
        isCharging = false
        chargeTimer = nil
    end
end

-- Function to handle idle battery drain
local function startIdleDrain()
    -- Clear any existing timer
    if idleDrainTimer then
        ClearTimeout(idleDrainTimer)
        idleDrainTimer = nil
    end
    
    -- Only drain battery if laptop is open
    if not laptopOpen then return end
    
    idleDrainTimer = SetTimeout(60000, function() -- 1 minute intervals
        local currentTime = GetGameTimer()
        local idleTime = currentTime - laptopLastUsed
        
        -- If idle for more than 1 minute, drain battery
        if idleTime > 60000 and batteryLevel > 0 and not isCharging then
            local oldLevel = batteryLevel
            batteryLevel = math.max(0, batteryLevel - Config.Battery.idleDrainRate)
            
            -- Round battery level
            batteryLevel = math.floor(batteryLevel * 10) / 10
            
            print("^2[qb-hackerjob] ^7Idle battery drain: " .. oldLevel .. "% to " .. batteryLevel .. "%")
            
            -- Update UI with new battery level
            SendNUIMessage({
                action = "updateBattery",
                level = batteryLevel,
                charging = isCharging
            })
            
            -- Check for low battery or critical battery
            if oldLevel > Config.Battery.lowBatteryThreshold and batteryLevel <= Config.Battery.lowBatteryThreshold then
                QBCore.Functions.Notify("Warning: Battery Low (" .. batteryLevel .. "%)", "error", 5000)
            elseif oldLevel > Config.Battery.criticalBatteryThreshold and batteryLevel <= Config.Battery.criticalBatteryThreshold then
                QBCore.Functions.Notify("Warning: Battery Critical (" .. batteryLevel .. "%)", "error", 5000)
            elseif batteryLevel <= 0 then
                QBCore.Functions.Notify("Battery depleted. Laptop shutting down.", "error", 5000)
                CloseLaptop()
                return
            end
        end
        
        -- Restart the timer
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

-- Function to open laptop
function OpenHackerLaptop(xpData)
    print("^2[qb-hackerjob] ^7Attempting to open hacker laptop")
    
    if laptopOpen then 
        print("^3[qb-hackerjob] ^7Laptop already open")
        return 
    end
    
    -- Check for required job
    if not hasRequiredJob() then
        QBCore.Functions.Notify("You are not a hacker", "error")
        return
    end
    
    -- Check battery level
    if Config.Battery.enabled and batteryLevel <= 0 then
        QBCore.Functions.Notify("Laptop battery is depleted. Replace the battery or charge it.", "error")
        return
    end
    
    -- Animation stuff - load animation in background to prevent waiting
    local ped = PlayerPedId()
    local animDict = "amb@world_human_seat_wall_tablet@female@base"
    local animName = "base"
    
    -- Request animation without blocking
    RequestAnimDict(animDict)
    
    -- Create laptop prop immediately without waiting for anim
    local tabletProp = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)
    local tabletBone = GetPedBoneIndex(ped, 28422)
    
    AttachEntityToEntity(tabletProp, ped, tabletBone, 0.12, 0.0, -0.05, 10.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    -- Set NUI focus immediately for faster UI response
    laptopOpen = true
    SetNuiFocus(true, true)
    
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
    
    SendNUIMessage(message)
    
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
-- Note: openLaptop event handler moved to main.lua to include XP data

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
    
    -- Log the action
    print("^2[qb-hackerjob] ^7Vehicle action: " .. data.action .. " on " .. data.plate .. ", drain type: " .. drainType)
    
    -- Trigger the action event
    TriggerEvent('qb-hackerjob:client:performVehicleAction', data.action, data.plate)
    cb({success = true})
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
        
        -- Set up a timer to periodically save battery level
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(60000) -- Save every 1 minute
                saveBatteryLevel()
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