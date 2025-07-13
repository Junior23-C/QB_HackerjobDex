local QBCore = exports['qb-core']:GetCoreObject()
local trackedVehicles = {}
local isTrackingVehicle = false

-- Function to install a tracking device on a vehicle
function AttemptInstallTracker(vehicle, plate)
    -- Check if player has GPS tracker item
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        if hasItem then
            if isTrackingVehicle then
                QBCore.Functions.Notify("You are already installing a tracker", "error")
                return
            end
            
            isTrackingVehicle = true
            
            -- Install animation and progressbar
            TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_VEHICLE_MECHANIC", 0, true)
            QBCore.Functions.Progressbar("install_tracker", "Installing GPS tracker...", Config.VehicleTracking.installTime, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                ClearPedTasks(PlayerPedId())
                
                -- Remove item
                TriggerServerEvent('qb-hackerjob:server:removeGPSTracker')
                
                -- Track the vehicle
                TrackVehicle(vehicle, plate)
                
                -- Award XP for successful vehicle tracking
                TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleTrack', plate, 'Vehicle tracking successful')
                
                isTrackingVehicle = false
                
                -- Check for police notification
                if math.random(100) <= Config.VehicleTracking.notifyPoliceChance then
                    TriggerServerEvent('police:server:policeAlert', 'Suspicious activity detected')
                end
                
            end, function() -- Cancel
                ClearPedTasks(PlayerPedId())
                QBCore.Functions.Notify("Cancelled installation", "error")
                isTrackingVehicle = false
            end)
        else
            QBCore.Functions.Notify("You need a GPS tracker to track this vehicle", "error")
        end
    end, Config.GPSTrackerItem)
end

-- Function to track a vehicle
function TrackVehicle(veh, plate)
    -- Debug log
    print("^2[qb-hackerjob] ^7TrackVehicle called with vehicle entity: " .. tostring(veh) .. " and plate: " .. tostring(plate))
    
    -- Check if already tracking this vehicle
    for _, data in pairs(trackedVehicles) do
        if data.plate == plate then
            QBCore.Functions.Notify("This vehicle is already being tracked", "error")
            print("^1[qb-hackerjob] ^7Vehicle is already being tracked: " .. plate)
            return
        end
    end
    
    -- Verify vehicle still exists
    if not DoesEntityExist(veh) then
        QBCore.Functions.Notify("Lost connection to vehicle", "error")
        print("^1[qb-hackerjob] ^7Vehicle entity no longer exists")
        return
    end
    
    -- Create blip
    print("^2[qb-hackerjob] ^7Creating blip for vehicle with model: " .. GetEntityModel(veh))
    local blip = AddBlipForEntity(veh)
    
    -- Check if blip was created
    if not blip or blip == 0 then
        print("^1[qb-hackerjob] ^7Failed to create blip for vehicle, trying alternative method")
        -- Alternative: Create blip at coordinates
        local coords = GetEntityCoords(veh)
        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        
        if not blip or blip == 0 then
            QBCore.Functions.Notify("Failed to establish GPS connection", "error")
            print("^1[qb-hackerjob] ^7Failed to create blip even at coordinates")
            return
        end
    end
    
    print("^2[qb-hackerjob] ^7Successfully created blip: " .. tostring(blip))
    
    -- Configure blip
    SetBlipSprite(blip, Config.VehicleTracking.blipSprite)
    SetBlipColour(blip, Config.VehicleTracking.blipColor)
    SetBlipScale(blip, Config.VehicleTracking.blipScale)
    SetBlipAsShortRange(blip, false)
    SetBlipAlpha(blip, Config.VehicleTracking.blipAlpha)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Tracked Vehicle: " .. plate)
    EndTextCommandSetBlipName(blip)
    
    -- Store the tracking info
    local trackingData = {
        vehicle = veh,
        plate = plate,
        blip = blip,
        startTime = GetGameTimer(),
        timeout = GetGameTimer() + Config.VehicleTracking.trackDuration
    }
    
    table.insert(trackedVehicles, trackingData)
    
    print("^2[qb-hackerjob] ^7Tracking data saved, tracking active for " .. math.floor(Config.VehicleTracking.trackDuration / 60000) .. " minutes")
    QBCore.Functions.Notify("Vehicle tracking active for " .. math.floor(Config.VehicleTracking.trackDuration / 60000) .. " minutes", "success")
    
    -- Award XP and log success
    TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'vehicleTrack', plate, 'Successfully installed GPS tracker')
    
    -- Flash the blip to make it more noticeable
    SetBlipFlashes(blip, true)
    
    -- Notify the vehicle owner (if it's a player's vehicle)
    TriggerServerEvent('qb-hackerjob:server:notifyVehicleOwner', plate)
end

-- Function to remove tracking from a vehicle
function RemoveTracking(index)
    if trackedVehicles[index] then
        RemoveBlip(trackedVehicles[index].blip)
        QBCore.Functions.Notify("Tracking ended for vehicle: " .. trackedVehicles[index].plate, "primary")
        table.remove(trackedVehicles, index)
    end
end

-- Thread to manage tracking updates and timeouts
CreateThread(function()
    while true do
        if #trackedVehicles > 0 then
            local currentTime = GetGameTimer()
            
            for i = #trackedVehicles, 1, -1 do
                local trackData = trackedVehicles[i]
                
                -- Check if tracking has expired
                if currentTime > trackData.timeout then
                    RemoveTracking(i)
                end
                
                -- Update blip if entity no longer exists
                if not DoesEntityExist(trackData.vehicle) then
                    -- Try to find vehicle with this plate in the world
                    local foundVehicle = false
                    local vehicles = GetGamePool('CVehicle')
                    
                    for _, veh in ipairs(vehicles) do
                        local vehPlate = GetVehicleNumberPlateText(veh):gsub("%s+", "")
                        if vehPlate == trackData.plate then
                            -- Update vehicle reference and blip
                            trackData.vehicle = veh
                            RemoveBlip(trackData.blip)
                            
                            -- Create new blip
                            trackData.blip = AddBlipForEntity(veh)
                            SetBlipSprite(trackData.blip, Config.VehicleTracking.blipSprite)
                            SetBlipColour(trackData.blip, Config.VehicleTracking.blipColor)
                            SetBlipScale(trackData.blip, Config.VehicleTracking.blipScale)
                            SetBlipAsShortRange(trackData.blip, false)
                            SetBlipAlpha(trackData.blip, Config.VehicleTracking.blipAlpha)
                            
                            BeginTextCommandSetBlipName("STRING")
                            AddTextComponentString("Tracked Vehicle: " .. trackData.plate)
                            EndTextCommandSetBlipName(trackData.blip)
                            
                            foundVehicle = true
                            break
                        end
                    end
                    
                    if not foundVehicle then
                        -- Vehicle not found in the world, create a coords blip at last known position
                        local coords = GetEntityCoords(trackData.vehicle)
                        RemoveBlip(trackData.blip)
                        
                        trackData.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                        SetBlipSprite(trackData.blip, Config.VehicleTracking.blipSprite)
                        SetBlipColour(trackData.blip, Config.VehicleTracking.blipColor)
                        SetBlipScale(trackData.blip, Config.VehicleTracking.blipScale)
                        SetBlipAsShortRange(trackData.blip, false)
                        SetBlipAlpha(trackData.blip, Config.VehicleTracking.blipAlpha)
            
            if not blip or blip == 0 then
                QBCore.Functions.Notify("Failed to establish GPS connection", "error")
                print("^1[qb-hackerjob] ^7Failed to create blip even at coordinates")
                -- Log failure
                TriggerEvent('qb-hackerjob:client:handleHackFailure', 'vehicleTrack', plate, 'Failed to create blip')
                return
            end
        end
            
            Wait(Config.VehicleTracking.refreshRate)
        else
            Wait(1000)
        end
    end
end)

-- Function to handle tracking from the laptop
function TrackVehicleFromLaptop(plate)
    print("^2[qb-hackerjob] ^7Attempting to track vehicle with plate: " .. tostring(plate))
    
    -- Check if tracking is enabled
    if not Config.VehicleTracking.enabled then
        QBCore.Functions.Notify("Vehicle tracking is not enabled", "error")
        return false
    end
    
    -- Check if player has GPS tracker item
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        if not hasItem then
            QBCore.Functions.Notify("You need a GPS tracker to track this vehicle", "error")
            return
        end
        
        -- Normalize the plate
        local normalizedPlate = plate:gsub("%s+", ""):upper()
        
        -- Find the vehicle
        local playerCoords = GetEntityCoords(PlayerPedId())
        local foundVehicle = nil
        local vehicles = GetGamePool('CVehicle')
        
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehPlate = GetVehicleNumberPlateText(veh)
                if vehPlate then
                    vehPlate = vehPlate:gsub("%s+", ""):upper()
                    if vehPlate == normalizedPlate then
                        local distance = #(playerCoords - GetEntityCoords(veh))
                        if distance <= 150.0 then
                            foundVehicle = veh
                            break
                        end
                    end
                end
            end
        end
        
        if not foundVehicle then
            QBCore.Functions.Notify("Cannot find vehicle with plate " .. plate .. " nearby", "error")
            -- Log failure
            TriggerEvent('qb-hackerjob:client:handleHackFailure', 'vehicleTrack', plate, 'Vehicle not found nearby')
            return
        end
        
        -- First remove the GPS tracker item, then track the vehicle
        TriggerServerEvent('qb-hackerjob:server:removeGPSTracker')
        
        -- Small delay to ensure server has time to process item removal
        Citizen.Wait(100)
        
        -- Track the vehicle
        TrackVehicle(foundVehicle, normalizedPlate)
    end, Config.GPSTrackerItem)
    
    return true  -- Return value only used for NUI callback
end

-- Export the functions
exports('TrackVehicleFromLaptop', TrackVehicleFromLaptop)
exports('AttemptInstallTracker', AttemptInstallTracker)
exports('TrackVehicle', TrackVehicle)

-- Command to check if player has GPS tracker
RegisterCommand('gpscheck', function()
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:hasItem', function(hasItem, itemData)
        if hasItem then
            QBCore.Functions.Notify("You have " .. (itemData and itemData.amount or "a") .. " GPS tracker(s) in your inventory", "success")
            print("^2[qb-hackerjob] ^7Player has GPS tracker. Item data:", json.encode(itemData or {}))
        else
            QBCore.Functions.Notify("You don't have any GPS trackers in your inventory", "error")
            print("^1[qb-hackerjob] ^7Player does not have GPS tracker item: " .. Config.GPSTrackerItem)
        end
    end, Config.GPSTrackerItem)
end, false)

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
