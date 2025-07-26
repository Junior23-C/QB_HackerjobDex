local QBCore = exports['qb-core']:GetCoreObject()

-- Enhanced error handling and reliability system for client
local ErrorConfig = {
    maxRetries = 3,
    retryDelay = 500,
    networkTimeout = 10000,
    logLevel = 'INFO'
}

-- Network health tracking
local NetworkHealth = {
    lastServerResponse = 0,
    failedRequests = 0,
    connected = true
}

-- Variables
local PlayerData = {}
local playerLoaded = false
local currentJob = nil
local vendorPed = nil
local vendorBlip = nil
local traceLevel = 0
local isCharging = false

-- Enhanced logging functions
local function SafeLogError(message, context)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    print('^1[qb-hackerjob:client:ERROR] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
end

local function SafeLogInfo(message, context)
    if ErrorConfig.logLevel == 'DEBUG' or ErrorConfig.logLevel == 'INFO' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^2[qb-hackerjob:client:INFO] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
end

local function SafeLogDebug(message, context)
    if ErrorConfig.logLevel == 'DEBUG' then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local contextStr = context and (' [' .. tostring(context) .. ']') or ''
        print('^3[qb-hackerjob:client:DEBUG] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
    end
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
        local success, result = pcall(function()
            QBCore.Functions.TriggerCallback(callbackName, function(callbackResult)
                if callbackResult then
                    NetworkHealth.lastServerResponse = GetGameTimer()
                    NetworkHealth.failedRequests = 0
                    NetworkHealth.connected = true
                    SafeLogDebug('Callback successful: ' .. callbackName)
                    callback(callbackResult)
                else
                    if attempt < retries then
                        SafeLogError('Callback returned nil on attempt ' .. attempt .. '/' .. retries .. ': ' .. callbackName)
                        Citizen.Wait(ErrorConfig.retryDelay * attempt)
                        executeCallback(attempt + 1)
                    else
                        NetworkHealth.failedRequests = NetworkHealth.failedRequests + 1
                        SafeLogError('Callback failed after all retries: ' .. callbackName)
                        callback(nil)
                    end
                end
            end, data)
        end)
        
        if not success then
            SafeLogError('Error executing callback: ' .. callbackName .. ' - ' .. tostring(result))
            if attempt < retries then
                Citizen.Wait(ErrorConfig.retryDelay * attempt)
                executeCallback(attempt + 1)
            else
                callback(nil)
            end
        end
    end
    
    executeCallback(1)
end

-- Safe event trigger
local function SafeTriggerServerEvent(eventName, ...)
    if not eventName or type(eventName) ~= 'string' then
        SafeLogError('Invalid event name provided to SafeTriggerServerEvent')
        return false
    end
    
    local success, result = pcall(function()
        TriggerServerEvent(eventName, ...)
        return true
    end)
    
    if not success then
        SafeLogError('Failed to trigger server event: ' .. eventName .. ' - ' .. tostring(result))
        return false
    end
    
    SafeLogDebug('Server event triggered: ' .. eventName)
    return true
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

-- Events

-- Enhanced player data initialization with error handling
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SafeLogInfo('Player loaded event received')
    
    local initSuccess = pcall(function()
        local playerData = QBCore.Functions.GetPlayerData()
        if not playerData then
            SafeLogError('Failed to get player data on load')
            return
        end
        
        PlayerData = playerData
        
        -- Safe job assignment
        if playerData.job and playerData.job.name then
            currentJob = playerData.job.name
            SafeLogDebug('Current job set to: ' .. currentJob)
        else
            SafeLogError('No job data found in player data')
            currentJob = nil
        end
        
        playerLoaded = true
        
        -- Safe trace level retrieval
        if playerData.metadata then
            traceLevel = playerData.metadata.tracelevel or 0
            SafeLogDebug('Trace level set to: ' .. traceLevel)
        else
            SafeLogError('No metadata found in player data')
            traceLevel = 0
        end
        
        SafeLogInfo('Player initialization completed successfully')
    end)
    
    if not initSuccess then
        SafeLogError('Player initialization failed')
        SafeNotify('System initialization error - please reconnect if issues persist', 'error')
        return
    end
    
    -- Safe usable item setup
    pcall(SetupUsableItem)
end)

-- Enhanced job update handler with error handling
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    SafeLogDebug('Job update event received')
    
    local updateSuccess = pcall(function()
        if not JobInfo then
            SafeLogError('No job info provided in job update')
            return
        end
        
        if not PlayerData then
            SafeLogError('Player data not initialized for job update')
            PlayerData = {}
        end
        
        PlayerData.job = JobInfo
        
        if JobInfo.name then
            local oldJob = currentJob
            currentJob = JobInfo.name
            SafeLogInfo('Job updated: ' .. (oldJob or 'none') .. ' -> ' .. currentJob)
        else
            SafeLogError('No job name in job update')
            currentJob = nil
        end
    end)
    
    if not updateSuccess then
        SafeLogError('Job update failed')
    end
end)

-- Enhanced resource initialization with error handling
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    SafeLogInfo('Resource starting: ' .. resourceName)
    
    local startSuccess = pcall(function()
        -- Wait a bit for QBCore to be ready
        Citizen.Wait(1000)
        
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData then
            PlayerData = playerData
            
            if playerData.job and playerData.job.name then
                currentJob = playerData.job.name
                SafeLogDebug('Current job loaded: ' .. currentJob)
            else
                SafeLogError('No job data found during resource start')
                currentJob = nil
            end
            
            playerLoaded = true
            SafeLogInfo('Resource initialization completed successfully')
        else
            SafeLogError('Failed to get player data during resource start')
            playerLoaded = false
        end
    end)
    
    if not startSuccess then
        SafeLogError('Resource initialization failed')
        playerLoaded = false
    end
end)

-- Enhanced resource cleanup with error handling
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    SafeLogInfo('Resource stopping: ' .. resourceName)
    
    -- Safe laptop cleanup
    pcall(function()
        if exports['qb-hackerjob']:IsLaptopOpen() then
            exports['qb-hackerjob']:CloseLaptop()
            SafeLogDebug('Laptop closed during resource stop')
        end
    end)
    
    -- Safe ped cleanup
    pcall(function()
        if vendorPed and DoesEntityExist(vendorPed) then
            DeletePed(vendorPed)
            SafeLogDebug('Vendor ped cleaned up')
        end
        vendorPed = nil
    end)
    
    -- Safe blip cleanup
    pcall(function()
        if vendorBlip and DoesBlipExist(vendorBlip) then
            RemoveBlip(vendorBlip)
            SafeLogDebug('Vendor blip cleaned up')
        end
        vendorBlip = nil
    end)
    
    -- Reset state
    playerLoaded = false
    PlayerData = {}
    currentJob = nil
    traceLevel = 0
    isCharging = false
    
    SafeLogInfo('Resource cleanup completed')
end)

-- Enhanced usable item setup with error handling
function SetupUsableItem()
    SafeLogDebug('Setting up usable item')
    
    local setupSuccess = pcall(function()
        if not Config or not Config.LaptopItem then
            SafeLogError('No laptop item configured')
            return
        end
        
        QBCore.Functions.CreateUseableItem(Config.LaptopItem, function(source, item)
            SafeLogDebug('Laptop item used', source)
            
            -- Safe event trigger
            local triggerSuccess = pcall(function()
                TriggerEvent('qb-hackerjob:client:openLaptop')
            end)
            
            if not triggerSuccess then
                SafeLogError('Failed to trigger laptop open event', source)
                SafeNotify('Error opening laptop - please try again', 'error')
            end
        end)
        
        SafeLogDebug('Usable item setup completed')
    end)
    
    if not setupSuccess then
        SafeLogError('Failed to set up usable item')
    end
end

-- Setup item usage for the laptop
CreateThread(function()
    Citizen.Wait(5000) -- Wait longer for QBCore to fully initialize
    
    -- Setup usable item
    SetupUsableItem()
    
    -- Register command manually to ensure it's properly set up
    RegisterCommand(Config.LaptopCommand, function()
        -- Laptop command triggered
        -- If using item system, check if player has it
        if Config.UsableItem then
            QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
                if hasItem then
                    TriggerEvent('qb-hackerjob:client:openLaptop')
                else
                    QBCore.Functions.Notify('You don\\'t have a hacking laptop', "error")
                end
            end, Config.LaptopItem)
        else
            TriggerEvent('qb-hackerjob:client:openLaptop')
        end
    end, false)
    
    -- Register a key binding for the laptop command
    RegisterKeyMapping(Config.LaptopCommand, 'Use Hacker Laptop', 'keyboard', '')
end)

-- Direct event handler for item use (backup method)
RegisterNetEvent('inventory:client:UseItem')
AddEventHandler('inventory:client:UseItem', function(item)
    if item.name == Config.LaptopItem then
        -- Laptop item used from inventory
        TriggerEvent('qb-hackerjob:client:openLaptop')
    elseif Config.Battery.enabled and item.name == Config.Battery.batteryItemName then
        TriggerEvent('qb-hackerjob:client:replaceBattery')
    elseif Config.Battery.enabled and item.name == Config.Battery.chargerItemName then
        TriggerEvent('qb-hackerjob:client:toggleCharger')
    end
end)

-- Export to check if player is a hacker
exports('IsPlayerHacker', function()
    if not Config.RequireJob then return true end
    
    if not playerLoaded or not PlayerData or not PlayerData.job then
        return false
    end
    
    if PlayerData.job.name == Config.HackerJobName then
        if Config.JobRank > 0 then
            return PlayerData.job.grade.level >= Config.JobRank
        end
        return true
    end
    
    return false
end)

-- Register key binding for direct open
RegisterKeyMapping(Config.LaptopCommand, 'Use Hacker Laptop', 'keyboard', '')

-- Check if player is in the vehicle with the given plate
RegisterNetEvent('qb-hackerjob:client:checkVehiclePlate')
AddEventHandler('qb-hackerjob:client:checkVehiclePlate', function(plate, message)
    local playerPed = PlayerPedId()
    
    -- Check if player is in a vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle and vehicle ~= 0 then
            local vehPlate = GetVehicleNumberPlateText(vehicle):gsub("%s+", ""):upper()
            
            -- If plates match, show notification
            if vehPlate == plate then
                -- Show notification with red warning
                TriggerEvent('QBCore:Notify', message, "error", 10000)
                
                -- Flash screen red briefly
                AnimpostfxPlay("DeathFailOut", 0, true)
                Citizen.Wait(500)
                AnimpostfxStop("DeathFailOut")
            end
        end
    end
end)

-- Vendor setup
function SetupVendor()
    -- Skip if vendor is disabled in config
    if not Config.Vendor.enabled then
        -- Vendor disabled in configuration
        return
    end
    
    -- Delete existing ped if it exists
    if vendorPed ~= nil then
        DeletePed(vendorPed)
        vendorPed = nil
    end
    
    -- Define model from config
    local model = Config.Vendor.model
    
    -- Request and load the model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Create the ped at coordinates from config
    vendorPed = CreatePed(4, model, Config.Vendor.coords.x, Config.Vendor.coords.y, Config.Vendor.coords.z - 1.0, Config.Vendor.coords.w, false, true)
    
    -- Set ped attributes
    SetEntityAsMissionEntity(vendorPed, true, true)
    SetBlockingOfNonTemporaryEvents(vendorPed, true)
    SetPedDiesWhenInjured(vendorPed, false)
    SetPedCanPlayAmbientAnims(vendorPed, true)
    SetPedCanRagdollFromPlayerImpact(vendorPed, false)
    SetEntityInvincible(vendorPed, true)
    FreezeEntityPosition(vendorPed, true)
    
    -- Add animation from config
    TaskStartScenarioInPlace(vendorPed, Config.Vendor.scenario, 0, true)
    
    -- Set up target
    exports['qb-target']:AddTargetEntity(vendorPed, {
        options = {
            {
                icon = "fas fa-laptop",
                label = "Hacker Shop",
                action = function()
                    OpenHackerShop()
                end
            }
        },
        distance = 2.5
    })
    
    -- Create blip if enabled
    CreateVendorBlip()
    
    -- Laptop vendor created successfully
end

-- Create blip for vendor
function CreateVendorBlip()
    -- Remove existing blip if it exists
    if vendorBlip ~= nil then
        RemoveBlip(vendorBlip)
        vendorBlip = nil
    end
    
    -- Create new blip if enabled in config
    if Config.Blip.enabled then
        vendorBlip = AddBlipForCoord(Config.Vendor.coords.x, Config.Vendor.coords.y, Config.Vendor.coords.z)
        SetBlipSprite(vendorBlip, Config.Blip.sprite)
        SetBlipDisplay(vendorBlip, 4)
        SetBlipScale(vendorBlip, Config.Blip.scale)
        SetBlipColour(vendorBlip, Config.Blip.color)
        SetBlipAsShortRange(vendorBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blip.name)
        EndTextCommandSetBlipName(vendorBlip)
        
        -- Vendor blip created
    else
        -- Vendor blip disabled in configuration
    end
end

-- Function to toggle blip
function ToggleVendorBlip()
    if vendorBlip ~= nil then
        -- Blip exists, remove it
        RemoveBlip(vendorBlip)
        vendorBlip = nil
        Config.Blip.enabled = false
        QBCore.Functions.Notify("Hacker vendor blip disabled", "success")
        -- Vendor blip removed
    else
        -- Blip doesn't exist, create it
        Config.Blip.enabled = true
        CreateVendorBlip()
        QBCore.Functions.Notify("Hacker vendor blip enabled", "success")
    end
end

-- Shop interface function
function OpenHackerShop()
    -- Use qb-menu to create a shop menu
    local shopMenu = {
        {
            header = "Hacker Shop",
            isMenuHeader = true,
        },
        {
            header = "Hacking Laptop",
            txt = "Price: $" .. Config.Vendor.price,
            params = {
                event = "qb-hackerjob:client:buyLaptop",
            }
        },
        {
            header = "GPS Vehicle Tracker",
            txt = "Price: $" .. Config.GPSTrackerPrice .. " | Used to track vehicles remotely",
            params = {
                event = "qb-hackerjob:client:buyGPSTracker",
            }
        }
    }
    
    -- Add battery items if battery system is enabled
    if Config.Battery.enabled then
        table.insert(shopMenu, {
            header = "Laptop Battery",
            txt = "Price: $" .. Config.Battery.batteryItemPrice .. " | Replacement battery for the hacking laptop",
            params = {
                event = "qb-hackerjob:client:buyBattery",
            }
        })
        
        table.insert(shopMenu, {
            header = "Laptop Charger",
            txt = "Price: $" .. Config.Battery.chargerItemPrice .. " | Charger for the hacking laptop",
            params = {
                event = "qb-hackerjob:client:buyCharger",
            }
        })
    end
    
    -- Add close button
    table.insert(shopMenu, {
        header = "Close Menu",
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu",
        }
    })
    
    exports['qb-menu']:openMenu(shopMenu)
end

-- Event to purchase the laptop
RegisterNetEvent('qb-hackerjob:client:buyLaptop', function()
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:canBuyLaptop', function(canBuy)
        if canBuy then
            QBCore.Functions.Notify("Purchased hacking laptop", "success")
        else
            QBCore.Functions.Notify("You don't have enough money", "error")
        end
    end)
end)

-- Event to purchase the GPS tracker
RegisterNetEvent('qb-hackerjob:client:buyGPSTracker', function()
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:canBuyGPSTracker', function(canBuy)
        if canBuy then
            QBCore.Functions.Notify("Purchased GPS vehicle tracker", "success")
        else
            QBCore.Functions.Notify("You don't have enough money", "error")
        end
    end)
end)

-- Event to purchase a battery
RegisterNetEvent('qb-hackerjob:client:buyBattery', function()
    if not Config.Battery.enabled then return end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:canBuyBattery', function(canBuy)
        if canBuy then
            QBCore.Functions.Notify("Purchased laptop battery", "success")
        else
            QBCore.Functions.Notify("You don't have enough money", "error")
        end
    end)
end)

-- Event to purchase a charger
RegisterNetEvent('qb-hackerjob:client:buyCharger', function()
    if not Config.Battery.enabled then return end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:canBuyCharger', function(canBuy)
        if canBuy then
            QBCore.Functions.Notify("Purchased laptop charger", "success")
        else
            QBCore.Functions.Notify("You don't have enough money", "error")
        end
    end)
end)

-- Command to toggle blip
RegisterCommand('togglehackerblip', function()
    ToggleVendorBlip()
end, false)

-- Initialize vendor
CreateThread(function()
    while not playerLoaded do
        Wait(1000)
    end
    
    -- Create vendor ped
    SetupVendor()
end)

-- Alert police when trace level is too high
RegisterNetEvent('qb-hackerjob:client:alertPoliceTraceLevel')
AddEventHandler('qb-hackerjob:client:alertPoliceTraceLevel', function(hackerId)
    -- Only respond if player is police
    PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then return end
    
    local isPolice = false
    for _, jobName in pairs({'police', 'lspd', 'bcso', 'sasp'}) do
        if PlayerData.job.name == jobName then
            isPolice = true
            break
        end
    end
    
    if not isPolice then return end
    
    -- Get the coordinates of the hacker
    local hackerCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(hackerId)))
    
    -- Send alert to police
    TriggerEvent('police:client:PoliceAlert', 'Suspicious network activity detected', hackerCoords, true)
    
    -- Create temporary blip
    local blip = AddBlipForRadius(hackerCoords.x, hackerCoords.y, hackerCoords.z, 100.0)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, 128)
    
    -- Create centered blip
    local centerBlip = AddBlipForCoord(hackerCoords.x, hackerCoords.y, hackerCoords.z)
    SetBlipSprite(centerBlip, 161) -- Radio Tower
    SetBlipColour(centerBlip, 1)
    SetBlipAsShortRange(centerBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Suspicious Network Activity")
    EndTextCommandSetBlipName(centerBlip)
    
    -- Remove blips after 60 seconds
    Citizen.SetTimeout(60000, function()
        RemoveBlip(blip)
        RemoveBlip(centerBlip)
    end)
    
    -- Send notification to police
    QBCore.Functions.Notify("Dispatch: Suspicious network activity detected.", "police")
end)

-- Check cooldowns for hacking operations
function CheckCooldown(activity, callback)
    local lastUseTime = QBCore.Functions.GetPlayerData().metadata["lastHack" .. activity] or 0
    local currentTime = GetGameTimer()
    local cooldown = Config.Cooldowns[activity:lower()] or Config.Cooldowns.global
    
    if (currentTime - lastUseTime) < cooldown then
        local remainingTime = math.ceil((cooldown - (currentTime - lastUseTime)) / 1000)
        QBCore.Functions.Notify("Cooldown active. Try again in " .. remainingTime .. " seconds", "error")
        callback(false)
    else
        -- Update last use time in metadata
        TriggerServerEvent('qb-hackerjob:server:updateLastUseTime', activity)
        callback(true)
    end
end

-- ===== QBCORE METADATA-BASED XP SYSTEM =====

-- Function to award XP for hacking activities
function AwardXP(activityType)
    if not Config.XPEnabled then return end
    -- Awarding XP for hacking activity
    TriggerServerEvent('hackerjob:awardXP', activityType)
end

-- Handle XP stats updates from server
RegisterNetEvent('hackerjob:updateStats')
AddEventHandler('hackerjob:updateStats', function(stats)
    -- Received stats update from server
    
    -- Always try to update laptop UI if open
    if exports['qb-hackerjob']:IsLaptopOpen() then
        -- Updating laptop UI with new stats
        SendNUIMessage({
            action = 'updateHackerStats',
            type = 'updateHackerStats', -- Send both for compatibility
            level = stats.level,
            xp = stats.xp,
            nextLevelXP = stats.nextLevelXP,
            levelName = stats.levelName
        })
        
        -- Also force refresh the stats display with a small delay
        SetTimeout(100, function()
            SendNUIMessage({
                action = 'updateHackerStats',
                type = 'updateHackerStats',
                level = stats.level,
                xp = stats.xp,
                nextLevelXP = stats.nextLevelXP,
                levelName = stats.levelName
            })
        end)
    else
        -- Laptop UI not available for update
    end
end)

-- Function to get XP from player metadata directly (client-side)
function GetPlayerXPData()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not Player.metadata then 
        return {level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"}
    end
    
    local xp = Player.metadata.hackerXP or 0
    local level = Player.metadata.hackerLevel or 1
    
    -- Calculate next level XP
    local nextLevelXP = Config.LevelThresholds[level + 1] or Config.LevelThresholds[#Config.LevelThresholds]
    local levelName = Config.LevelNames[level] or "Script Kiddie"
    
    return {
        level = level,
        xp = xp,
        nextLevelXP = nextLevelXP,
        levelName = levelName
    }
end

-- Export XP function for use in other files
exports('AwardXP', AwardXP)
exports('GetPlayerXPData', GetPlayerXPData)

-- Test command for XP
RegisterCommand('testxp', function()
    -- Running XP test command
    AwardXP('plateLookup')
    QBCore.Functions.Notify("Test XP awarded!", "success")
end, false)

-- Debug command to check XP (using both methods for comparison)
RegisterCommand('checkxp', function()
    -- Method 1: Get from server callback
    QBCore.Functions.TriggerCallback('hackerjob:getStats', function(stats)
        -- Server callback XP stats retrieved
        QBCore.Functions.Notify("Server: Level " .. stats.level .. " (" .. stats.levelName .. ") - " .. stats.xp .. " XP", "primary")
    end)
    
    -- Method 2: Get from local metadata
    local localStats = GetPlayerXPData()
    -- Local metadata XP stats retrieved
    QBCore.Functions.Notify("Local: Level " .. localStats.level .. " (" .. localStats.levelName .. ") - " .. localStats.xp .. " XP", "info")
end, false)

-- Debug command to force open laptop
RegisterCommand('openlaptop', function()
    -- Force opening laptop interface
    local testStats = {level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"}
    exports['qb-hackerjob']:OpenHackerLaptop(testStats)
end, false)

-- Handle metadata updates
RegisterNetEvent('QBCore:Player:SetPlayerData')
AddEventHandler('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    
    -- Check if laptop is open and update stats when metadata changes
    if exports['qb-hackerjob']:IsLaptopOpen() and val.metadata then
        local stats = GetPlayerXPData()
        -- Metadata updated, refreshing UI
        SendNUIMessage({
            action = 'updateHackerStats',
            type = 'updateHackerStats',
            level = stats.level,
            xp = stats.xp,
            nextLevelXP = stats.nextLevelXP,
            levelName = stats.levelName
        })
    end
end)

-- Add hackerlaptop command for testing
RegisterCommand('hackerlaptop', function(source, args, rawCommand)
    print("^2[qb-hackerjob] ^7========== HACKERLAPTOP COMMAND USED ==========")
    TriggerEvent('qb-hackerjob:client:openLaptop')
end, false)

-- Client main script initialized