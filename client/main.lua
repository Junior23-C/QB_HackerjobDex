local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local PlayerData = {}
local playerLoaded = false
local currentJob = nil
local vendorPed = nil
local vendorBlip = nil
local currentHackerLevel = 1
local currentHackerXP = 0
local xpForNextLevel = 100
local traceLevel = 0
local isCharging = false

-- Events

-- Initialize player data when loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    currentJob = PlayerData.job.name
    playerLoaded = true
    -- Re-register usable item on player loaded
    SetupUsableItem()
    -- Get hacker level
    GetHackerLevel()
    -- Get trace level
    traceLevel = PlayerData.metadata.tracelevel or 0
end)

-- Handle job updates
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    currentJob = JobInfo.name
end)

-- Initialize the resource
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        currentJob = PlayerData.job.name
    end
    playerLoaded = true
end)

-- Handle resource stopping to properly clean up
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Check if laptop is open and close it
    if exports['qb-hackerjob']:IsLaptopOpen() then
        exports['qb-hackerjob']:CloseLaptop()
    end
    
    -- Clean up ped
    if vendorPed ~= nil then
        DeletePed(vendorPed)
        vendorPed = nil
    end
    
    -- Clean up blip
    if vendorBlip ~= nil then
        RemoveBlip(vendorBlip)
        vendorBlip = nil
    end
end)

-- Function to set up the usable item
function SetupUsableItem()
    -- Debug message
    print("^2[qb-hackerjob] ^7Setting up usable item: " .. Config.LaptopItem)
    
    QBCore.Functions.CreateUseableItem(Config.LaptopItem, function(source, item)
        print("^2[qb-hackerjob] ^7Laptop item used via CreateUseableItem!")
        TriggerEvent('qb-hackerjob:client:openLaptop')
    end)
end

-- Setup item usage for the laptop
CreateThread(function()
    Citizen.Wait(5000) -- Wait longer for QBCore to fully initialize
    
    -- Setup usable item
    SetupUsableItem()
    
    -- Register command manually to ensure it's properly set up
    RegisterCommand(Config.LaptopCommand, function()
        print("^2[qb-hackerjob] ^7Laptop command used!")
        -- If using item system, check if player has it
        if Config.UsableItem then
            QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
                if hasItem then
                    TriggerEvent('qb-hackerjob:client:openLaptop')
                else
                    QBCore.Functions.Notify('You don\'t have a hacking laptop', "error")
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
        print("^2[qb-hackerjob] ^7Laptop item used via inventory:client:UseItem!")
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
        print("^3[qb-hackerjob] ^7Vendor disabled in config")
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
    
    print("^2[qb-hackerjob] ^7Laptop vendor created at: " .. Config.Vendor.coords.x .. ", " .. Config.Vendor.coords.y .. ", " .. Config.Vendor.coords.z)
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
        
        print("^2[qb-hackerjob] ^7Vendor blip created")
    else
        print("^3[qb-hackerjob] ^7Vendor blip disabled in config")
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
        print("^3[qb-hackerjob] ^7Vendor blip removed")
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

-- Debug command to test XP system
RegisterCommand('testxp', function()
    print("^2[qb-hackerjob] ^7Testing XP system...")
    TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'plateLookup', 'TEST123', 'Testing XP system')
end, false)

-- Debug command to check current XP
RegisterCommand('checkxpclient', function()
    print("^2[qb-hackerjob] ^7Checking XP from client...")
    GetHackerLevel(function(level, xp, nextXP)
        print(string.format("^2[qb-hackerjob] ^7Client XP Check - Level: %d, XP: %d, NextXP: %d", level, xp, nextXP))
        QBCore.Functions.Notify(string.format("Level: %d, XP: %d/%d", level, xp, nextXP), "primary")
        
        -- Force update UI if laptop is open
        if exports['qb-hackerjob']:IsLaptopOpen() then
            SendNUIMessage({
                type = 'updateHackerStats',
                level = level,
                xp = xp,
                nextLevelXP = nextXP,
                levelName = Config.LevelNames[level] or "Unknown Level"
            })
        end
    end)
end, false)

-- Initialize vendor
CreateThread(function()
    while not playerLoaded do
        Wait(1000)
    end
    
    -- Create vendor ped
    SetupVendor()
end)

-- Event to handle level up animation/notification
RegisterNetEvent('qb-hackerjob:client:levelUp')
AddEventHandler('qb-hackerjob:client:levelUp', function(newLevel, levelName)
    -- Play celebration sound
    PlaySound(-1, "RACE_PLACED", "HUD_AWARDS", 0, 0, 1)
    
    -- Show fancy notification
    SendNUIMessage({
        type = "levelUp",
        level = newLevel,
        name = levelName
    })
    
    -- Update local variables (XP needs to be fetched again or estimated)
    currentHackerLevel = newLevel
    -- Re-fetch level/XP to get accurate current XP and next threshold
    GetHackerLevel(function(level, xp, nextXP)
        -- Update available features and stats display if laptop is open
        if exports['qb-hackerjob']:IsLaptopOpen() then
            SendNUIMessage({
                type = "updateHackerStats",
                level = level,
                xp = xp,
                nextLevelXP = nextXP,
                levelName = Config.LevelNames[level] or "Unknown Level"
            })
        end
    end)
    
    -- Visual effects for level up
    AnimpostfxPlay("SuccessMichael", 0, false)
    Citizen.SetTimeout(5000, function()
        AnimpostfxStop("SuccessMichael")
    end)
end)

-- Get player's hacker level
function GetHackerLevel(callback)
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:getHackerLevel', function(level, xp, nextLevelXP)
        -- Update local variables
        currentHackerLevel = level or 1
        currentHackerXP = xp or 0
        xpForNextLevel = nextLevelXP or Config.LevelThresholds[2] or 100 -- Default to level 2 threshold or 100
        
        -- Debug log
        print(string.format("^3[qb-hackerjob] ^7Updated local hacker level: %d, XP: %d/%d", currentHackerLevel, currentHackerXP, xpForNextLevel))
        
        -- Execute callback if provided
        if callback then
            callback(currentHackerLevel, currentHackerXP, xpForNextLevel)
        end
    end)
end

-- Check if player can use a specific hacking feature
function CanUseFeature(feature, callback)
    if not Config.XPEnabled then
        callback(true)
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:canUseFeature', function(canUse)
        if not canUse then
            local featureNames = {
                plateLookup = "Plate Lookup",
                phoneTrack = "Phone Tracking",
                radioDecrypt = "Radio Decryption",
                vehicleTrack = "Vehicle Tracking",
                phoneHack = "Phone Hacking",
                vehicleControl = "Vehicle Remote Control"
            }
            
            local featureName = featureNames[feature] or "this feature"
            QBCore.Functions.Notify("You need a higher hacker level to use " .. featureName, "error")
        end
        
        callback(canUse)
    end, feature)
end

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

-- Success handler for hacking operations to award XP
function HandleHackSuccess(activity, target, details)
    -- Add XP
    TriggerServerEvent('qb-hackerjob:server:addXP', activity)
    
    -- Log activity
    TriggerServerEvent('qb-hackerjob:server:logActivity', activity, target, true, details)
    
    -- Add trace
    TriggerServerEvent('qb-hackerjob:server:increaseTraceLevel', activity)
end

-- Failure handler for hacking operations
function HandleHackFailure(activity, target, details)
    -- Log failure
    TriggerServerEvent('qb-hackerjob:server:logActivity', activity, target, false, details)
    
    -- Still add some trace (failed attempts are suspicious too)
    TriggerServerEvent('qb-hackerjob:server:increaseTraceLevel', activity)
    
    -- Higher chance to alert police on failure
    local alertChance = (Config.AlertPolice[activity .. 'Chance'] or 10) * 2
    if math.random(1, 100) <= alertChance then
        -- Alert police (using existing police integration)
        local playerCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('police:server:policeAlert', 'Hacking attempt detected', playerCoords)
        
        QBCore.Functions.Notify("A trace of your hack attempt was detected!", "error")
    end
end

-- Export the handler functions
exports('HandleHackSuccess', HandleHackSuccess)
exports('HandleHackFailure', HandleHackFailure)

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

-- Update hacker laptop UI with level info
RegisterNetEvent('qb-hackerjob:client:updateLaptopUI')
AddEventHandler('qb-hackerjob:client:updateLaptopUI', function()
    SendNUIMessage({
        type = "updateLevel",
        level = currentHackerLevel,
        xp = currentHackerXP,
        nextLevel = xpForNextLevel,
        levelName = Config.LevelNames[currentHackerLevel]
    })
end)

-- Show XP progress bar in UI
function ShowXPBar()
    -- Calculate percentage progress to next level
    local currentLevelThreshold = Config.LevelThresholds[currentHackerLevel]
    local nextLevelThreshold = Config.LevelThresholds[currentHackerLevel + 1] or (Config.LevelThresholds[5] * 2)
    local progress = math.floor(((currentHackerXP - currentLevelThreshold) / (nextLevelThreshold - currentLevelThreshold)) * 100)
    
    if currentHackerLevel >= 5 then
        progress = 100 -- Max level
    end
    
    SendNUIMessage({
        type = "showXPBar",
        level = currentHackerLevel,
        levelName = Config.LevelNames[currentHackerLevel],
        progress = progress,
        xp = currentHackerXP
    })
    
    Citizen.SetTimeout(5000, function()
        SendNUIMessage({
            type = "hideXPBar"
        })
    end)
end)

-- Event handlers for hack success/failure via local events (solves export issues)
RegisterNetEvent('qb-hackerjob:client:handleHackSuccess')
AddEventHandler('qb-hackerjob:client:handleHackSuccess', function(activity, target, details)
    -- Debug prints to trace event flow
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7Event received:")
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7 - Activity: " .. tostring(activity))
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7 - Target: " .. tostring(target))
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7 - Details: " .. tostring(details))
    
    -- Add XP directly - This triggers the server-side XP addition
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7Triggering server XP event for activity: " .. tostring(activity))
    TriggerServerEvent('qb-hackerjob:server:addXP', activity)
    
    -- Log activity
    TriggerServerEvent('qb-hackerjob:server:logActivity', activity, target, true, details)
    
    -- Add trace
    TriggerServerEvent('qb-hackerjob:server:increaseTraceLevel', activity)
    
    -- Display a notification directly to the player
    local xpAmount = Config.XPSettings[activity] or 5
    print("^2[qb-hackerjob:client:handleHackSuccess] ^7Showing XP notification: +" .. xpAmount)
    QBCore.Functions.Notify("Hack successful: +" .. xpAmount .. " XP", "success")
end)

RegisterNetEvent('qb-hackerjob:client:handleHackFailure')
AddEventHandler('qb-hackerjob:client:handleHackFailure', function(activity, target, details)
    -- Log failure
    TriggerServerEvent('qb-hackerjob:server:logActivity', activity, target, false, details)
    
    -- Still add some trace (failed attempts are suspicious too)
    TriggerServerEvent('qb-hackerjob:server:increaseTraceLevel', activity)
    
    -- Higher chance to alert police on failure
    local alertChance = (Config.AlertPolice[activity .. 'Chance'] or 10) * 2
    if math.random(1, 100) <= alertChance then
        -- Alert police (using existing police integration)
        local playerCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('police:server:policeAlert', 'Hacking attempt detected', playerCoords)
        
        QBCore.Functions.Notify("A trace of your hack attempt was detected!", "error")
    end
end)

-- Handler for receiving updated stats from the server
RegisterNetEvent('qb-hackerjob:client:updateStats')
AddEventHandler('qb-hackerjob:client:updateStats', function(stats)
    -- ### CLIENT DEBUG START ###
    print("^3[qb-hackerjob:client:updateStats] ========== UI UPDATE EVENT ==========")
    print("^3[qb-hackerjob:client:updateStats] Event received.^7")
    if type(stats) ~= 'table' then
        print("^1[qb-hackerjob:client:updateStats] Received invalid stats data type: " .. type(stats) .. "^7")
        return
    end

    print(string.format("^3[qb-hackerjob:client:updateStats] Data: Level=%s, XP=%s, NextXP=%s, Name=%s^7",
        tostring(stats.level), tostring(stats.xp), tostring(stats.nextLevelXP), tostring(stats.levelName)))
    print("^3[qb-hackerjob:client:updateStats] Laptop Open Status: " .. tostring(exports['qb-hackerjob']:IsLaptopOpen()))
    -- ### CLIENT DEBUG END ###

    -- Update local cache (if needed, though NUI should be primary display)
    currentHackerLevel = tonumber(stats.level) or currentHackerLevel
    currentHackerXP = stats.xp or currentHackerXP
    xpForNextLevel = stats.nextLevelXP or xpForNextLevel

    -- FIXED: Ensure we're using the correct action type for the NUI message
    -- The NUI script is expecting 'updateHackerStats' but we were sending 'action' = 'updateHackerStats'
    -- This should be 'type' for the NUI script to recognize it
    local nuiData = {
        type = 'updateHackerStats',
        level = tonumber(stats.level) or 1,
        xp = tonumber(stats.xp) or 0,
        nextLevelXP = tonumber(stats.nextLevelXP) or 100,
        levelName = tostring(stats.levelName) or "Unknown Rank"
    }
    
    -- ### CLIENT DEBUG START ###
    print("^3[qb-hackerjob:client:updateStats] Sending NUI message: " .. json.encode(nuiData) .. "^7")
    -- ### CLIENT DEBUG END ###
    
    -- Force update the UI elements directly as well
    SendNUIMessage(nuiData)
    
    -- Also update the UI elements directly when laptop is open
    if exports['qb-hackerjob']:IsLaptopOpen() then
        -- Update the hacker stats display in the taskbar
        SendNUIMessage({
            action = 'updateHackerStats',
            level = tonumber(stats.level) or 1,
            xp = tonumber(stats.xp) or 0,
            nextLevelXP = tonumber(stats.nextLevelXP) or 100,
            levelName = tostring(stats.levelName) or "Unknown Rank"
        })
    end
end)

-- Note: Laptop opening logic moved to laptop.lua to avoid conflicts
