local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local PlayerData = {}
local playerLoaded = false
local currentJob = nil
local vendorPed = nil
local vendorBlip = nil
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

-- ===== NEW SIMPLE XP SYSTEM =====

-- Function to award XP for hacking activities
function AwardXP(activityType)
    if not Config.XPEnabled then return end
    TriggerServerEvent('hackerjob:awardXP', activityType)
end

-- Handle XP stats updates from server
RegisterNetEvent('hackerjob:updateStats')
AddEventHandler('hackerjob:updateStats', function(stats)
    print("^2[qb-hackerjob] ^7Received stats update from server:")
    print("  Level: " .. tostring(stats.level))
    print("  XP: " .. tostring(stats.xp))
    print("  Next Level XP: " .. tostring(stats.nextLevelXP))
    print("  Level Name: " .. tostring(stats.levelName))
    
    -- Always try to update laptop UI if open
    if exports['qb-hackerjob']:IsLaptopOpen() then
        print("^2[qb-hackerjob] ^7Laptop is open, sending NUI message...")
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
        print("^3[qb-hackerjob] ^7Laptop is not open, skipping UI update")
    end
end)

-- Export XP function for use in other files
exports('AwardXP', AwardXP)

-- Test command for XP
RegisterCommand('testxp', function()
    print("^2[qb-hackerjob] ^7Running testxp command...")
    AwardXP('plateLookup')
    QBCore.Functions.Notify("Test XP awarded!", "success")
end, false)

-- Debug command to check XP
RegisterCommand('checkxp', function()
    QBCore.Functions.TriggerCallback('hackerjob:getStats', function(stats)
        print("^2[qb-hackerjob] ^7Current XP Stats:")
        print("  Level: " .. stats.level)
        print("  XP: " .. stats.xp)
        print("  Next Level XP: " .. stats.nextLevelXP)
        print("  Level Name: " .. stats.levelName)
        QBCore.Functions.Notify("Level " .. stats.level .. " (" .. stats.levelName .. ") - " .. stats.xp .. " XP", "primary")
    end)
end, false)

print("^2[qb-hackerjob] ^7Client main script loaded successfully")