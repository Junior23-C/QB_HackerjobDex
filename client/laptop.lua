-- EMERGENCY MINIMAL LAPTOP CLIENT - BASIC WORKING VERSION
print("^1[qb-hackerjob:laptop] ^7========== LAPTOP CLIENT SCRIPT LOADING ==========")

local QBCore = nil
local laptopOpen = false

-- Initialize QBCore
CreateThread(function()
    print("^3[qb-hackerjob:laptop] ^7Attempting to initialize QBCore...")
    local attempts = 0
    while QBCore == nil and attempts < 50 do
        QBCore = exports['qb-core']:GetCoreObject()
        if QBCore then
            print("^2[qb-hackerjob:laptop] ^7QBCore initialized successfully")
            break
        end
        attempts = attempts + 1
        Wait(100)
    end
    
    if not QBCore then
        print("^1[qb-hackerjob:laptop] ^7CRITICAL: Failed to initialize QBCore")
        return
    end
    
    print("^2[qb-hackerjob:laptop] ^7QBCore ready, registering events...")
    
    -- Register the basic laptop open event
    RegisterNetEvent('qb-hackerjob:client:openLaptop')
    AddEventHandler('qb-hackerjob:client:openLaptop', function()
        print("^2[qb-hackerjob] ^7========== LAPTOP OPEN EVENT TRIGGERED ==========")
        print("^2[qb-hackerjob] ^7Event received successfully!")
        
        -- Basic validation
        if laptopOpen then
            print("^3[qb-hackerjob] ^7Laptop already open")
            return
        end
        
        print("^2[qb-hackerjob] ^7Opening laptop interface...")
        OpenBasicLaptop()
    end)
    
    print("^2[qb-hackerjob:laptop] ^7Event registered successfully!")
end)

-- Basic laptop opening function
function OpenBasicLaptop()
    print("^2[qb-hackerjob] ^7OpenBasicLaptop called")
    
    if not QBCore then
        print("^1[qb-hackerjob] ^7QBCore not available")
        return
    end
    
    -- Simple job check (optional)
    if Config.RequireJob then
        local Player = QBCore.Functions.GetPlayerData()
        if not Player or not Player.job or Player.job.name ~= Config.HackerJobName then
            QBCore.Functions.Notify("You don't know how to use this device", "error")
            print("^1[qb-hackerjob] ^7Job requirement not met")
            return
        end
    end
    
    print("^2[qb-hackerjob] ^7Job check passed, opening laptop...")
    
    -- Set laptop as open
    laptopOpen = true
    
    -- Enable NUI focus
    SetNuiFocus(true, true)
    
    -- Send basic message to NUI
    SendNUIMessage({
        action = "openLaptop",
        type = "openLaptop",
        level = 1,
        xp = 0,
        nextLevelXP = 100,
        levelName = "Script Kiddie",
        batteryLevel = 100,
        charging = false
    })
    
    print("^2[qb-hackerjob] ^7Laptop opened successfully!")
    QBCore.Functions.Notify("Laptop activated", "success")
end

-- Basic laptop closing function
function CloseLaptop()
    print("^2[qb-hackerjob] ^7Closing laptop")
    laptopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({action = "closeLaptop"})
end

-- Basic NUI callback
RegisterNUICallback('closeLaptop', function(_, cb)
    CloseLaptop()
    cb({success = true})
end)

-- Add basic resource initialization debug
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print("^2[qb-hackerjob:laptop] ^7========== RESOURCE STARTING ==========")
    print("^2[qb-hackerjob:laptop] ^7Resource: " .. resourceName)
    print("^2[qb-hackerjob:laptop] ^7Client script initialized")
end)

-- Export functions for compatibility
exports('OpenHackerLaptop', OpenBasicLaptop)
exports('CloseLaptop', CloseLaptop)
exports('IsLaptopOpen', function() return laptopOpen end)

print("^2[qb-hackerjob:laptop] ^7========== LAPTOP SCRIPT LOADED SUCCESSFULLY ==========")