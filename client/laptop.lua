-- Laptop client script for QB-HackerJob
local QBCore = exports['qb-core']:GetCoreObject()
local laptopOpen = false
local batteryLevel = 100
local isCharging = false
local batteryDrainThread = nil

-- Debug print
print("^2[qb-hackerjob:laptop] ^7Laptop client script loaded")

-- Register event immediately - This is critical for receiving server events
RegisterNetEvent('qb-hackerjob:client:openLaptop', function()
    print("^2[qb-hackerjob:laptop] ^7OpenLaptop event received")
    
    if laptopOpen then
        print("^3[qb-hackerjob:laptop] ^7Laptop already open")
        return
    end
    
    -- Check job requirement if enabled
    if Config.RequireJob then
        local Player = QBCore.Functions.GetPlayerData()
        if not Player or not Player.job or Player.job.name ~= Config.HackerJobName then
            QBCore.Functions.Notify("You don't know how to use this device", "error")
            return
        end
    end
    
    OpenHackerLaptop()
end)

-- Function to open the laptop
function OpenHackerLaptop(stats)
    print("^2[qb-hackerjob:laptop] ^7Opening laptop interface")
    
    if laptopOpen then
        return
    end
    
    -- Get player stats if not provided
    if not stats then
        local Player = QBCore.Functions.GetPlayerData()
        stats = {
            level = Player.metadata.hackerLevel or 1,
            xp = Player.metadata.hackerXP or 0,
            nextLevelXP = Config.LevelThresholds[2] or 100,
            levelName = Config.LevelNames[1] or "Script Kiddie"
        }
    end
    
    -- Check battery if system is enabled
    if Config.Battery.enabled then
        batteryLevel = GetResourceKvpFloat('hackerjob_battery') or 100
        if batteryLevel <= 0 then
            QBCore.Functions.Notify("Laptop battery is dead. You need to charge it.", "error")
            return
        end
    end
    
    laptopOpen = true
    
    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openLaptop",
        type = "openLaptop",
        level = stats.level,
        xp = stats.xp,
        nextLevelXP = stats.nextLevelXP,
        levelName = stats.levelName,
        batteryLevel = batteryLevel,
        charging = isCharging
    })
    
    -- Start battery drain if enabled
    if Config.Battery.enabled and not isCharging then
        StartBatteryDrain()
    end
    
    print("^2[qb-hackerjob:laptop] ^7Laptop opened successfully")
end

-- Function to close the laptop
function CloseLaptop()
    if not laptopOpen then
        return
    end
    
    laptopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "closeLaptop"
    })
    
    -- Stop battery drain
    if batteryDrainThread then
        batteryDrainThread = nil
    end
    
    -- Save battery level
    if Config.Battery.enabled then
        SetResourceKvpFloat('hackerjob_battery', batteryLevel)
    end
end

-- Battery system functions
function StartBatteryDrain()
    if not Config.Battery.enabled or batteryDrainThread then
        return
    end
    
    batteryDrainThread = CreateThread(function()
        while laptopOpen and batteryLevel > 0 and not isCharging do
            Wait(Config.Battery.drainInterval)
            
            batteryLevel = math.max(0, batteryLevel - Config.Battery.drainAmount)
            
            -- Update UI
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel
            })
            
            -- Warnings
            if batteryLevel <= 20 and batteryLevel > 10 then
                QBCore.Functions.Notify("Laptop battery low", "error")
            elseif batteryLevel <= 10 and batteryLevel > 0 then
                QBCore.Functions.Notify("Laptop battery critical!", "error")
            elseif batteryLevel <= 0 then
                QBCore.Functions.Notify("Laptop battery died", "error")
                CloseLaptop()
                break
            end
        end
        
        batteryDrainThread = nil
    end)
end

-- Battery replacement
RegisterNetEvent('qb-hackerjob:client:replaceBattery', function()
    if not Config.Battery.enabled then return end
    
    QBCore.Functions.Progressbar("replace_battery", "Replacing laptop battery...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        anim = "machinic_loop_mechandplayer",
        flags = 49,
    }, {}, {}, function() -- Done
        batteryLevel = 100
        SetResourceKvpFloat('hackerjob_battery', batteryLevel)
        
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel
            })
        end
        
        QBCore.Functions.Notify("Battery replaced successfully", "success")
        TriggerServerEvent('qb-hackerjob:server:removeBattery')
    end, function() -- Cancel
        QBCore.Functions.Notify("Cancelled", "error")
    end)
end)

-- Charger toggle
RegisterNetEvent('qb-hackerjob:client:toggleCharger', function()
    if not Config.Battery.enabled then return end
    
    isCharging = not isCharging
    
    if isCharging then
        QBCore.Functions.Notify("Laptop charger connected", "success")
        
        -- Start charging
        CreateThread(function()
            while isCharging and batteryLevel < 100 do
                Wait(Config.Battery.chargeInterval)
                
                batteryLevel = math.min(100, batteryLevel + Config.Battery.chargeAmount)
                
                if laptopOpen then
                    SendNUIMessage({
                        action = "updateBattery",
                        batteryLevel = batteryLevel,
                        charging = true
                    })
                end
                
                if batteryLevel >= 100 then
                    QBCore.Functions.Notify("Laptop fully charged", "success")
                end
            end
        end)
    else
        QBCore.Functions.Notify("Laptop charger disconnected", "primary")
        
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel,
                charging = false
            })
            
            -- Resume battery drain
            StartBatteryDrain()
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeLaptop', function(_, cb)
    CloseLaptop()
    cb({success = true})
end)

RegisterNUICallback('performPlateLookup', function(data, cb)
    if not data.plate then
        cb({success = false, message = "No plate provided"})
        return
    end
    
    -- Check cooldown
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:checkCooldown', function(canProceed)
        if not canProceed then
            cb({success = false, message = "System cooldown active. Try again later."})
            return
        end
        
        -- Perform the lookup
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:plateLookup', function(result)
            if result then
                cb({success = true, data = result})
                
                -- Award XP if enabled
                if Config.XPEnabled then
                    TriggerServerEvent('hackerjob:awardXP', 'plateLookup')
                end
            else
                cb({success = false, message = "Lookup failed"})
            end
        end, data.plate)
    end, 'plateLookup')
end)

RegisterNUICallback('trackPhone', function(data, cb)
    if not data.number then
        cb({success = false, message = "No phone number provided"})
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:checkCooldown', function(canProceed)
        if not canProceed then
            cb({success = false, message = "System cooldown active. Try again later."})
            return
        end
        
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:trackPhone', function(result)
            if result then
                cb({success = true, data = result})
                
                if Config.XPEnabled then
                    TriggerServerEvent('hackerjob:awardXP', 'phoneTracker')
                end
            else
                cb({success = false, message = "Phone tracking failed"})
            end
        end, data.number)
    end, 'phoneTracker')
end)

RegisterNUICallback('decryptRadio', function(data, cb)
    if not data.frequency then
        cb({success = false, message = "No frequency provided"})
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:checkCooldown', function(canProceed)
        if not canProceed then
            cb({success = false, message = "System cooldown active. Try again later."})
            return
        end
        
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:decryptRadio', function(result)
            if result then
                cb({success = true, data = result})
                
                if Config.XPEnabled then
                    TriggerServerEvent('hackerjob:awardXP', 'radioDecryption')
                end
            else
                cb({success = false, message = "Radio decryption failed"})
            end
        end, data.frequency)
    end, 'radioDecryption')
end)

RegisterNUICallback('hackPhone', function(data, cb)
    if not data.number then
        cb({success = false, message = "No phone number provided"})
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:checkCooldown', function(canProceed)
        if not canProceed then
            cb({success = false, message = "System cooldown active. Try again later."})
            return
        end
        
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:hackPhone', function(result)
            if result then
                cb({success = true, data = result})
                
                if Config.XPEnabled then
                    TriggerServerEvent('hackerjob:awardXP', 'phoneHacking')
                end
            else
                cb({success = false, message = "Phone hacking failed"})
            end
        end, data.number)
    end, 'phoneHacking')
end)

RegisterNUICallback('getStats', function(_, cb)
    local Player = QBCore.Functions.GetPlayerData()
    local stats = {
        level = Player.metadata.hackerLevel or 1,
        xp = Player.metadata.hackerXP or 0,
        nextLevelXP = Config.LevelThresholds[(Player.metadata.hackerLevel or 1) + 1] or Config.LevelThresholds[#Config.LevelThresholds],
        levelName = Config.LevelNames[Player.metadata.hackerLevel or 1] or "Script Kiddie"
    }
    cb(stats)
end)

-- Exports
exports('OpenHackerLaptop', OpenHackerLaptop)
exports('CloseLaptop', CloseLaptop)
exports('IsLaptopOpen', function() return laptopOpen end)

-- Commands for testing
RegisterCommand('testlaptop', function()
    print("^2[qb-hackerjob:laptop] ^7Test command triggered")
    TriggerEvent('qb-hackerjob:client:openLaptop')
end, false)

print("^2[qb-hackerjob:laptop] ^7Laptop client script initialized successfully")