local QBCore = exports['qb-core']:GetCoreObject()
local controlCooldown = false
local controlledVehicle = nil
local disabledBrakeVehicles = {} -- Track vehicles with disabled brakes

-- Function to find a vehicle by plate
local function FindVehicleByPlate(plate)
    -- Normalize the plate
    plate = plate:gsub("%s+", ""):upper()
    
    -- Get all vehicles in the game world
    local vehicles = GetGamePool('CVehicle')
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestVehicle = nil
    local closestDistance = 999999
    
    -- Check each vehicle
    for _, vehicle in ipairs(vehicles) do
        local vehiclePlate = GetVehicleNumberPlateText(vehicle):gsub("%s+", ""):upper()
        
        if vehiclePlate == plate then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(playerCoords - vehCoords)
            
            -- Store closest matching vehicle
            if distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end
    
    return closestVehicle, closestDistance
end

-- Function to perform various vehicle actions
function PerformVehicleAction(action, plate)
    print("^1[qb-hackerjob:vehicle_control] ^7PerformVehicleAction called with action: " .. tostring(action) .. ", plate: " .. tostring(plate))
    print("^1[qb-hackerjob:vehicle_control] ^7THIS DEBUG MESSAGE SHOULD APPEAR IF FUNCTION IS CALLED!")
    
    -- Check if player is in cooldown
    if controlCooldown then
        QBCore.Functions.Notify("System cooling down, please wait", "error")
        return false
    end
    
    -- Set cooldown
    controlCooldown = true
    SetTimeout(2000, function()
        controlCooldown = false
    end)
    
    -- Normalize plate
    plate = plate:gsub("%s+", ""):upper()
    
    -- Find vehicle with matching plate
    local vehicle, distance = FindVehicleByPlate(plate)
    
    if not vehicle then
        QBCore.Functions.Notify("Vehicle not found nearby", "error")
        return false
    end
    
    -- Store for accelerate/brake actions that need to be maintained
    controlledVehicle = vehicle
    
    -- Perform the requested action
    if action == "lock" then
        -- Lock the vehicle
        SetVehicleDoorsLocked(vehicle, 2) -- 2 = locked
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        
        -- Visual and sound effects
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        Wait(200)
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        
        QBCore.Functions.Notify("Vehicle locked remotely", "success")
        
        -- Notify vehicle owner/driver
        TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "Your vehicle has been locked remotely")
        
        -- Award XP and log success using proper client event
        print("^2[qb-hackerjob:vehicle_control] ^7About to trigger XP event for lock action")
        TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleControl', plate, 'Successfully locked vehicle')
        
        return true
        
    elseif action == "unlock" then
        -- Unlock the vehicle
        SetVehicleDoorsLocked(vehicle, 1) -- 1 = unlocked
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        
        -- Visual and sound effects
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        Wait(200)
        SetVehicleLights(vehicle, 2)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        
        QBCore.Functions.Notify("Vehicle unlocked remotely", "success")
        
        -- Notify vehicle owner/driver
        TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "Your vehicle has been unlocked remotely")
        
        -- Award XP and log success using proper client event
        print("^2[qb-hackerjob:vehicle_control] ^7About to trigger XP event for unlock action")
        TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleControl', plate, 'Successfully unlocked vehicle')
        
        return true
        
    elseif action == "engine" then
        -- Toggle engine
        local isEngineRunning = GetIsVehicleEngineRunning(vehicle)
        SetVehicleEngineOn(vehicle, not isEngineRunning, true, true)
        
        if isEngineRunning then
            QBCore.Functions.Notify("Vehicle engine disabled", "success")
            -- Notify vehicle owner/driver
            TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "Your vehicle engine has been remotely disabled")
        else
            QBCore.Functions.Notify("Vehicle engine enabled", "success")
            -- Notify vehicle owner/driver
            TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "Your vehicle engine has been remotely enabled")
        end
        
        -- Award XP and log success using proper client event
        TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleControl', plate, 'Successfully toggled vehicle engine')
        
        return true
        
    elseif action == "disable_brakes" then
        -- Permanently disable brakes - only fixable with vehicle repair
        QBCore.Functions.Notify("Permanently disabling vehicle brakes", "success")
        
        -- Notify vehicle owner/driver
        TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "WARNING: Your vehicle braking system has been critically compromised")
        
        -- Save original brake force value
        local originalBrakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
        
        -- Use more aggressive methods to permanently disable brakes
        -- 1. Set brake force to nearly zero
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", 0.05)
        
        -- 2. Increase mass slightly to make it harder to stop
        local originalMass = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass")
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", originalMass * 1.2)
        
        -- 3. Reduce traction control slightly
        local originalTraction = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", originalTraction * 0.8)
        
        -- 4. Add slight damage to brakes - this ensures the "repair" requirement is meaningful
        SetVehicleBodyHealth(vehicle, math.min(GetVehicleBodyHealth(vehicle) * 0.8, 800.0))
        
        -- 5. Make it slightly faster to simulate loss of control
        ModifyVehicleTopSpeed(vehicle, 1.15)
        
        -- Add to tracked vehicles with all original values
        disabledBrakeVehicles[plate] = {
            vehicle = vehicle,
            originalBrakeForce = originalBrakeForce,
            originalMass = originalMass,
            originalTraction = originalTraction,
            timeDisabled = GetGameTimer()
        }
        
        -- Save to a persistent variable for tracking across resource restarts
        TriggerServerEvent('qb-hackerjob:server:saveDisabledBrakes', plate, originalBrakeForce, originalMass, originalTraction)
        
        print("^2[qb-hackerjob] ^7Vehicle brakes permanently disabled for plate: " .. plate)
        
        -- Award XP and log success using proper client event
        print("^2[qb-hackerjob:vehicle_control] ^7About to trigger XP event for brake disable action")
        TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleControl', plate, 'Successfully disabled vehicle brakes')
        
        -- Create thread to maintain disabled brakes until vehicle is repaired
        CreateThread(function()
            while true do
                -- Only check every 3 seconds to reduce performance impact
                Wait(3000)
                
                if not DoesEntityExist(vehicle) then
                    -- Don't remove from tracking - we want to find it again if it respawns
                    print("^3[qb-hackerjob] ^7Vehicle temporarily lost, still tracking: " .. plate)
                    -- Wait longer before checking again
                    Wait(10000)
                    -- Continue the loop to keep checking
                    goto continue
                end
                
                -- Check if vehicle health indicates it was FULLY repaired
                -- Must have both engine AND body health restored
                local engineHealth = GetVehicleEngineHealth(vehicle)
                local bodyHealth = GetVehicleBodyHealth(vehicle)
                
                -- Only fix if vehicle is COMPLETELY repaired (professional mechanic job)
                if engineHealth > 995 and bodyHealth > 995 then
                    -- Restore brake force and other handling modifications
                    if disabledBrakeVehicles[plate] then
                        -- Check if it's been at least 30 seconds since disabling (no instant repairs)
                        local timeNow = GetGameTimer()
                        local timeDisabled = disabledBrakeVehicles[plate].timeDisabled or 0
                        if (timeNow - timeDisabled) < 30000 then
                            print("^3[qb-hackerjob] ^7Prevented instant repair of brakes for: " .. plate)
                            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", 0.05)
                            -- Keep checking
                            goto continue
                        end
                        
                        -- Restore all original values
                        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", disabledBrakeVehicles[plate].originalBrakeForce or 1.0)
                        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", disabledBrakeVehicles[plate].originalMass or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass"))
                        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", disabledBrakeVehicles[plate].originalTraction or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax"))
                        ModifyVehicleTopSpeed(vehicle, 1.0)
                        
                        -- Remove from both client and server tracking
                        disabledBrakeVehicles[plate] = nil
                        TriggerServerEvent('qb-hackerjob:server:removeDisabledBrakes', plate)
                        
                        print("^2[qb-hackerjob] ^7Vehicle fully repaired by mechanic, brakes restored for plate: " .. plate)
                        
                        -- Notify driver if possible
                        TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "Vehicle braking system has been professionally repaired and is now functioning normally")
                        break
                    end
                else
                    -- Not fully repaired, keep brakes disabled
                    -- Re-apply brake disabling to prevent game from resetting it
                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", 0.05)
                    SetVehicleBrakeLights(vehicle, false)
                end
                
                ::continue::
            end
        end)
        
        -- Return success
        return true
        
    elseif action == "accelerate" then
        -- Force vehicle acceleration
        CreateThread(function()
            local startTime = GetGameTimer()
            local endTime = startTime + 4000 -- 4 seconds of forced acceleration
            
            QBCore.Functions.Notify("Forcing vehicle acceleration for 4 seconds", "success")
            -- Notify vehicle owner/driver
            TriggerServerEvent('qb-hackerjob:server:notifyDriver', plate, "WARNING: Your vehicle accelerator has been compromised")
            
            -- Make sure engine is on
            SetVehicleEngineOn(vehicle, true, true, true)
            
            while GetGameTimer() < endTime do
                -- Force acceleration
                if DoesEntityExist(vehicle) then
                    SetVehicleForwardSpeed(vehicle, 15.0) -- Strong acceleration
                    -- Disable brakes during acceleration
                    SetVehicleBrakeLights(vehicle, false)
                    SetVehicleHandbrake(vehicle, false)
                else
                    break -- Vehicle no longer exists
                end
                Wait(100)
            end
            
            -- Reset after time expires
            if DoesEntityExist(vehicle) then
                QBCore.Functions.Notify("Vehicle accelerator control restored", "primary")
            end
        end)
        
        -- Award XP and log success using proper client event
        TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleControl', plate, 'Successfully forced vehicle acceleration')
        
        return true
    end
    
    -- Log failure if action wasn't handled
    TriggerEvent('qb-hackerjob:client:handleHackFailure', 'vehicleControl', plate, 'Unknown or failed vehicle action: ' .. action)
    return false
end

-- Register event to handle vehicle actions (called from NUI)
RegisterNetEvent('qb-hackerjob:client:vehicleAction')
AddEventHandler('qb-hackerjob:client:vehicleAction', function(action, plate)
    PerformVehicleAction(action, plate)
end)

-- Export the function
exports('PerformVehicleAction', PerformVehicleAction)

-- Function to handle tracking from the laptop
function TrackVehicleFromLaptop(plate)
    print("^2[qb-hackerjob] ^7Attempting to track vehicle with plate: " .. tostring(plate))
    
    if not Config.VehicleTracking.enabled then
        QBCore.Functions.Notify("Vehicle tracking is not enabled", "error")
        return false
    end
    
    -- Normal code path with item check
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        print("^3[qb-hackerjob] ^7Has GPS tracker: " .. tostring(hasItem))
        if not hasItem then
            QBCore.Functions.Notify("You need a GPS tracker to track vehicles", "error")
            return false
        end
        
        -- Normalize the plate for comparison
        local normalizedPlate = plate:gsub("%s+", ""):upper()
        
        -- Check if vehicle with this plate exists nearby
        local vehicles = GetGamePool('CVehicle')
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local foundVehicle = nil
        
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehPlate = GetVehicleNumberPlateText(veh)
                if vehPlate then
                    vehPlate = vehPlate:gsub("%s+", ""):upper()
                    local distance = #(playerCoords - GetEntityCoords(veh))
                    
                    if vehPlate == normalizedPlate and distance <= 100.0 then
                        foundVehicle = veh
                        print("^2[qb-hackerjob] ^7Found matching vehicle at distance: " .. distance)
                        break
                    end
                end
            end
        end
        
        if foundVehicle then
            print("^2[qb-hackerjob] ^7Starting tracking process for: " .. normalizedPlate)
            
            -- Remove the GPS tracker
            TriggerServerEvent('qb-hackerjob:server:removeItem', Config.GPSTrackerItem, 1)
            
            -- Start tracking
            TrackVehicle(foundVehicle, normalizedPlate)
            QBCore.Functions.Notify("Vehicle tracking activated", "success")
            return true
        else
            print("^1[qb-hackerjob] ^7No matching vehicle found for: " .. normalizedPlate)
            QBCore.Functions.Notify("Cannot find vehicle with plate " .. plate .. " nearby", "error")
            return false
        end
    end, Config.GPSTrackerItem)
    
    return true
end

-- Event to sync disabled brakes from server
RegisterNetEvent('qb-hackerjob:client:syncDisabledBrakes')
AddEventHandler('qb-hackerjob:client:syncDisabledBrakes', function(serverDisabledBrakes)
    print("^2[qb-hackerjob] ^7Received disabled brakes list from server, entries: " .. (serverDisabledBrakes and #serverDisabledBrakes or 0))
    
    -- Track the plates locally so we can apply effects when vehicles are found
    for plate, data in pairs(serverDisabledBrakes) do
        if not disabledBrakeVehicles[plate] then
            disabledBrakeVehicles[plate] = {
                vehicle = nil, -- Will be set when we find the vehicle
                originalBrakeForce = data.originalBrakeForce,
                originalMass = data.originalMass,
                originalTraction = data.originalTraction,
                timeDisabled = GetGameTimer() - 60000 -- Set to 1 minute ago to prevent instant repair
            }
            print("^3[qb-hackerjob] ^7Added vehicle to local tracking: " .. plate)
        end
    end
end)

-- Enhanced thread to check for vehicles with disabled brakes
CreateThread(function()
    while true do
        Wait(2000) -- Check every 2 seconds
        
        -- Build a list of nearby vehicles for potential matching
        local vehicles = GetGamePool('CVehicle')
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Check all tracked plates
        for plate, data in pairs(disabledBrakeVehicles) do
            -- If we don't have a vehicle reference or it no longer exists
            if not data.vehicle or not DoesEntityExist(data.vehicle) then
                -- Try to find the vehicle in the world
                for _, veh in ipairs(vehicles) do
                    if DoesEntityExist(veh) then
                        local vehPlate = GetVehicleNumberPlateText(veh):gsub("%s+", ""):upper()
                        if vehPlate == plate then
                            -- Found a matching vehicle!
                            print("^3[qb-hackerjob] ^7Found tracked vehicle with disabled brakes: " .. plate)
                            disabledBrakeVehicles[plate].vehicle = veh
                            
                            -- Apply disabled brakes effect immediately
                            SetVehicleHandlingFloat(veh, "CHandlingData", "fBrakeForce", 0.05)
                            
                            -- Apply other handling modifications if we have the original values
                            if data.originalMass then
                                SetVehicleHandlingFloat(veh, "CHandlingData", "fMass", data.originalMass * 1.2)
                            end
                            
                            if data.originalTraction then
                                SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionCurveMax", data.originalTraction * 0.8)
                            end
                            
                            ModifyVehicleTopSpeed(veh, 1.15)
                            
                            -- If player is in this vehicle, notify them
                            if IsPedInVehicle(playerPed, veh, false) then
                                QBCore.Functions.Notify("Warning: This vehicle has damaged brakes!", "error", 5000)
                            end
                            
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- Register event for when the resource stops to clean up
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Reset all vehicles with disabled brakes
    for plate, data in pairs(disabledBrakeVehicles) do
        if DoesEntityExist(data.vehicle) and data.originalBrakeForce then
            SetVehicleHandlingFloat(data.vehicle, "CHandlingData", "fBrakeForce", data.originalBrakeForce)
            ModifyVehicleTopSpeed(data.vehicle, 1.0)
            print("^3[qb-hackerjob] ^7Resource stopping: Restored brakes for vehicle " .. plate)
        end
    end
end)
