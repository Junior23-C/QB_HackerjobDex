-- Laptop client script for QB-HackerJob
local QBCore = exports['qb-core']:GetCoreObject()
local laptopOpen = false
local batteryLevel = 100
local isCharging = false
local batteryDrainThread = nil
local chargingThread = nil
local chargingActive = false
local batteryOperationInProgress = false

-- Initialize battery level from saved data
Citizen.CreateThread(function()
    if Config.Battery.enabled then
        batteryLevel = GetResourceKvpFloat('hackerjob_battery') or 100
        print("^2[qb-hackerjob:laptop] ^7Battery level initialized: " .. batteryLevel .. "%")
    end
end)

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
    
    -- Start phone animation
    local playerPed = PlayerPedId()
    if not IsEntityPlayingAnim(playerPed, "cellphone@", "cellphone_text_read_base", 3) then
        RequestAnimDict("cellphone@")
        while not HasAnimDictLoaded("cellphone@") do
            Wait(0)
        end
        TaskPlayAnim(playerPed, "cellphone@", "cellphone_text_read_base", 2.0, 3.0, -1, 49, 0, false, false, false)
    end
    
    laptopOpen = true
    
    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openPhone",
        type = "openPhone",
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
    
    -- Stop phone animation
    local playerPed = PlayerPedId()
    if IsEntityPlayingAnim(playerPed, "cellphone@", "cellphone_text_read_base", 3) then
        StopAnimTask(playerPed, "cellphone@", "cellphone_text_read_base", 1.0)
    end
    
    laptopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "closePhone"
    })
    
    -- Stop battery drain
    if batteryDrainThread then
        batteryDrainThread = nil
    end
    
    -- Stop charging if active (charging can continue when laptop is closed)
    -- Note: We don't stop charging here as it should continue even when laptop is closed
    -- This is realistic behavior - charger stays connected
    
    -- Save battery level
    if Config.Battery.enabled then
        SetResourceKvpFloat('hackerjob_battery', batteryLevel)
    end
end

-- Function to drain battery for specific operations
function DrainBatteryForOperation(operation)
    if not Config.Battery.enabled then return end
    
    local drainAmount = Config.Battery.operationDrainRates[operation] or Config.Battery.drainRate
    batteryLevel = math.max(0, batteryLevel - drainAmount)
    
    -- Save battery level
    SetResourceKvpFloat('hackerjob_battery', batteryLevel)
    
    -- Update UI if laptop is open
    if laptopOpen then
        SendNUIMessage({
            action = "updateBattery",
            batteryLevel = batteryLevel
        })
    end
    
    -- Check if battery died
    if batteryLevel <= 0 then
        QBCore.Functions.Notify("Laptop battery died", "error")
        CloseLaptop()
    end
end

-- Battery system functions
function StartBatteryDrain()
    if not Config.Battery.enabled or batteryDrainThread then
        return
    end
    
    batteryDrainThread = CreateThread(function()
        while laptopOpen and batteryLevel > 0 and not isCharging do
            -- Calculate drain interval: 2.5% per minute = 2.5% per 60000ms
            -- So for 2.5% drain, we wait 60000ms
            local drainInterval = 60000 -- 1 minute
            Wait(drainInterval)
            
            -- Apply idle drain rate (2.5% per minute)
            batteryLevel = math.max(0, batteryLevel - Config.Battery.idleDrainRate)
            
            -- Update UI
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel
            })
            
            -- Save battery level periodically
            SetResourceKvpFloat('hackerjob_battery', batteryLevel)
            
            -- Warnings
            if batteryLevel <= Config.Battery.lowBatteryThreshold and batteryLevel > Config.Battery.criticalBatteryThreshold then
                QBCore.Functions.Notify("Laptop battery low", "error")
            elseif batteryLevel <= Config.Battery.criticalBatteryThreshold and batteryLevel > 0 then
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
        -- Ensure battery is at 100% (should already be set in NUI callback)
        batteryLevel = 100
        SetResourceKvpFloat('hackerjob_battery', batteryLevel)
        
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel,
                charging = isCharging
            })
        end
        
        QBCore.Functions.Notify("Battery replaced successfully - 100% charge", "success")
        TriggerServerEvent('qb-hackerjob:server:removeBattery')
        print("^2[qb-hackerjob:laptop] ^7Battery replacement completed - Battery: " .. batteryLevel .. "%")
    end, function() -- Cancel
        QBCore.Functions.Notify("Battery replacement cancelled", "error")
    end)
end)

-- Charger toggle
RegisterNetEvent('qb-hackerjob:client:toggleCharger', function()
    if not Config.Battery.enabled then return end
    
    isCharging = not isCharging
    
    if isCharging then
        QBCore.Functions.Notify("Laptop charger connected", "success")
        print("^2[qb-hackerjob:laptop] ^7Starting charging process - Battery: " .. batteryLevel .. "%")
        
        -- Start realistic charging
        CreateThread(function()
            while isCharging and batteryLevel < 100 do
                Wait(Config.Battery.chargeInterval) -- Default: 30 seconds
                
                if not isCharging then break end -- Double check charging status
                
                -- Determine charge rate based on battery level (realistic charging curve)
                local chargeRate
                if batteryLevel < 50 then
                    chargeRate = Config.Battery.fastChargeRate -- 5.0% per 30s = 5 minutes for 0-50%
                else
                    chargeRate = Config.Battery.slowChargeRate -- 1.67% per 30s = 15 minutes for 50-100%
                end
                
                local oldLevel = batteryLevel
                batteryLevel = math.min(100, batteryLevel + chargeRate)
                
                print("^2[qb-hackerjob:laptop] ^7Charging: " .. oldLevel .. "% -> " .. batteryLevel .. "% (+" .. chargeRate .. "%)")
                
                -- Save battery level
                SetResourceKvpFloat('hackerjob_battery', batteryLevel)
                
                -- Update UI if laptop is open
                if laptopOpen then
                    SendNUIMessage({
                        action = "updateBattery",
                        batteryLevel = batteryLevel,
                        charging = true
                    })
                end
                
                -- Check if fully charged
                if batteryLevel >= 100 then
                    QBCore.Functions.Notify("Laptop fully charged", "success")
                    print("^2[qb-hackerjob:laptop] ^7Battery fully charged")
                    break
                end
            end
            print("^2[qb-hackerjob:laptop] ^7Charging thread ended")
        end)
    else
        QBCore.Functions.Notify("Laptop charger disconnected", "primary")
        print("^2[qb-hackerjob:laptop] ^7Charger disconnected - Battery: " .. batteryLevel .. "%")
        
        if laptopOpen then
            SendNUIMessage({
                action = "updateBattery",
                batteryLevel = batteryLevel,
                charging = false
            })
            
            -- Resume battery drain if laptop is open
            StartBatteryDrain()
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeLaptop', function(_, cb)
    CloseLaptop()
    cb({success = true})
end)

RegisterNUICallback('closePhone', function(_, cb)
    CloseLaptop()
    cb({success = true})
end)

RegisterNUICallback('replaceBattery', function(_, cb)
    print("^2[qb-hackerjob:laptop] ^7Replace battery NUI callback triggered")
    
    if not Config.Battery.enabled then
        cb({success = false, message = "Battery system disabled"})
        return
    end
    
    -- Prevent multiple simultaneous operations
    if batteryOperationInProgress then
        print("^3[qb-hackerjob:laptop] ^7Battery operation already in progress, ignoring request")
        cb({success = false, message = "Battery operation already in progress"})
        return
    end
    
    batteryOperationInProgress = true
    
    -- Check if player has battery item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if hasItem then
            -- Trigger the replace battery event for animation first
            TriggerEvent('qb-hackerjob:client:replaceBattery')
            
            cb({
                success = true, 
                message = "Battery replacement started",
                batteryLevel = 100, -- New battery is full
                charging = isCharging
            })
        else
            cb({success = false, message = "You don't have a replacement battery"})
        end
        
        -- Reset operation flag
        batteryOperationInProgress = false
    end, Config.Battery.batteryItemName)
end)

RegisterNUICallback('toggleCharger', function(_, cb)
    print("^2[qb-hackerjob:laptop] ^7Toggle charger NUI callback triggered")
    
    if not Config.Battery.enabled then
        cb({success = false, message = "Battery system disabled"})
        return
    end
    
    -- Prevent multiple simultaneous operations
    if batteryOperationInProgress then
        print("^3[qb-hackerjob:laptop] ^7Battery operation already in progress, ignoring charger toggle")
        cb({success = false, message = "Battery operation already in progress"})
        return
    end
    
    batteryOperationInProgress = true
    
    -- Check if player has charger item
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem)
        if hasItem then
            -- Toggle charger state directly (inline instead of event)
            isCharging = not isCharging
            
            if isCharging then
                QBCore.Functions.Notify("Laptop charger connected", "success")
                print("^2[qb-hackerjob:laptop] ^7Starting charging process - Battery: " .. batteryLevel .. "%")
                
                -- Start realistic charging (stop any existing charging thread first)
                if chargingThread then
                    chargingActive = false
                    chargingThread = nil
                end
                
                chargingActive = true
                chargingThread = CreateThread(function()
                    print("^2[qb-hackerjob:laptop] ^7Charging thread started")
                    while isCharging and batteryLevel < 100 and chargingActive do
                        Wait(Config.Battery.chargeInterval) -- Default: 30 seconds
                        
                        if not isCharging or not chargingActive then 
                            print("^2[qb-hackerjob:laptop] ^7Charging stopped - breaking from thread")
                            break 
                        end -- Double check charging status
                        
                        -- Determine charge rate based on battery level (realistic charging curve)
                        local chargeRate
                        if batteryLevel < 50 then
                            chargeRate = Config.Battery.fastChargeRate -- 5.0% per 30s = 5 minutes for 0-50%
                        else
                            chargeRate = Config.Battery.slowChargeRate -- 1.67% per 30s = 15 minutes for 50-100%
                        end
                        
                        local oldLevel = batteryLevel
                        batteryLevel = math.min(100, batteryLevel + chargeRate)
                        
                        print("^2[qb-hackerjob:laptop] ^7Charging: " .. oldLevel .. "% -> " .. batteryLevel .. "% (+" .. chargeRate .. "%)")
                        
                        -- Save battery level
                        SetResourceKvpFloat('hackerjob_battery', batteryLevel)
                        
                        -- Update UI if laptop is open
                        if laptopOpen then
                            SendNUIMessage({
                                action = "updateBattery",
                                batteryLevel = batteryLevel,
                                charging = true
                            })
                        end
                        
                        -- Check if fully charged
                        if batteryLevel >= 100 then
                            QBCore.Functions.Notify("Laptop fully charged", "success")
                            print("^2[qb-hackerjob:laptop] ^7Battery fully charged")
                            break
                        end
                    end
                    chargingThread = nil
                    chargingActive = false
                    print("^2[qb-hackerjob:laptop] ^7Charging thread ended")
                end)
            else
                QBCore.Functions.Notify("Laptop charger disconnected", "primary")
                print("^2[qb-hackerjob:laptop] ^7Charger disconnected - Battery: " .. batteryLevel .. "%")
                
                -- Stop charging thread by setting flag (thread will detect and stop)
                if chargingThread then
                    chargingActive = false
                    chargingThread = nil
                end
                
                -- Save current battery level immediately
                SetResourceKvpFloat('hackerjob_battery', batteryLevel)
                
                if laptopOpen then
                    SendNUIMessage({
                        action = "updateBattery",
                        batteryLevel = batteryLevel,
                        charging = false
                    })
                    
                    -- Resume battery drain if laptop is open
                    StartBatteryDrain()
                end
            end
            
            -- Return the callback immediately with current state
            cb({
                success = true, 
                message = isCharging and "Charger connected" or "Charger disconnected",
                batteryLevel = batteryLevel,
                charging = isCharging
            })
        else
            cb({success = false, message = "You don't have a laptop charger"})
        end
        
        -- Reset operation flag
        batteryOperationInProgress = false
    end, Config.Battery.chargerItemName)
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
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:lookupPlate', function(result)
            if result then
                -- Drain battery for operation
                DrainBatteryForOperation('plateLookup')
                
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
                -- Drain battery for operation
                DrainBatteryForOperation('phoneTrack')
                
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
                -- Drain battery for operation
                DrainBatteryForOperation('radioDecrypt')
                
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
                -- Drain battery for operation  
                DrainBatteryForOperation('phoneHack')
                
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
exports('GetBatteryLevel', function() return batteryLevel end)
exports('IsCharging', function() return isCharging end)

-- Commands for testing
RegisterCommand('testlaptop', function()
    print("^2[qb-hackerjob:laptop] ^7Test command triggered")
    TriggerEvent('qb-hackerjob:client:openLaptop')
end, false)

RegisterCommand('testbattery', function()
    print("^2[qb-hackerjob:laptop] ^7Current battery level: " .. batteryLevel .. "%")
    print("^2[qb-hackerjob:laptop] ^7Charging status: " .. tostring(isCharging))
end, false)

RegisterCommand('setbattery', function(source, args)
    if args[1] then
        local newLevel = tonumber(args[1])
        if newLevel and newLevel >= 0 and newLevel <= 100 then
            batteryLevel = newLevel
            SetResourceKvpFloat('hackerjob_battery', batteryLevel)
            print("^2[qb-hackerjob:laptop] ^7Battery level set to: " .. batteryLevel .. "%")
            
            if laptopOpen then
                SendNUIMessage({
                    action = "updateBattery",
                    batteryLevel = batteryLevel
                })
            end
        else
            print("^1[qb-hackerjob:laptop] ^7Invalid battery level. Use 0-100")
        end
    else
        print("^1[qb-hackerjob:laptop] ^7Usage: /setbattery <level>")
    end
end, false)

print("^2[qb-hackerjob:laptop] ^7Laptop client script initialized successfully")