local QBCore = exports['qb-core']:GetCoreObject()

-- Event to remove GPS tracker item when used
RegisterNetEvent('qb-hackerjob:server:removeGPSTracker', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print("^1[qb-hackerjob] ^7Error: Player not found when removing GPS tracker")
        return 
    end
    
    -- Check if the item exists in shared items
    if not QBCore.Shared.Items[Config.GPSTrackerItem] then
        print("^1[qb-hackerjob] ^7Error: GPS Tracker item '" .. Config.GPSTrackerItem .. "' not defined in shared items!")
        TriggerClientEvent('QBCore:Notify', src, "Error: GPS Tracker item not defined in server items", "error")
        return
    end
    
    -- Debug print
    print("^3[qb-hackerjob] ^7Attempting to remove GPS tracker from player ID: " .. src)
    
    -- Remove the GPS tracker item
    local hasItem = Player.Functions.GetItemByName(Config.GPSTrackerItem)
    if hasItem and hasItem.amount > 0 then
        Player.Functions.RemoveItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], "remove")
        print("^2[qb-hackerjob] ^7Successfully removed GPS tracker item from player")
    else
        print("^1[qb-hackerjob] ^7Error: Player doesn't have GPS tracker item to remove")
        TriggerClientEvent('QBCore:Notify', src, "You don't have a GPS tracker", "error")
    end
end)

-- Command to check if a player has a GPS tracker
QBCore.Commands.Add('checkgpstracker', 'Check if you have a GPS tracker', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if the item exists in shared items
    if not QBCore.Shared.Items[Config.GPSTrackerItem] then
        TriggerClientEvent('QBCore:Notify', src, "GPS Tracker item is not defined in shared items!", "error")
        print("^1[qb-hackerjob] ^7Error: GPS Tracker item not defined in shared items!")
        return
    end
    
    -- Check if player has the item
    local hasItem = Player.Functions.GetItemByName(Config.GPSTrackerItem)
    if hasItem then
        TriggerClientEvent('QBCore:Notify', src, "You have " .. hasItem.amount .. " GPS tracker(s)", "success")
        print("^2[qb-hackerjob] ^7Player has " .. hasItem.amount .. " GPS tracker(s)")
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have any GPS trackers", "error")
        print("^3[qb-hackerjob] ^7Player doesn't have any GPS trackers")
    end
end)

-- Event to notify vehicle owner when their vehicle is being tracked
RegisterNetEvent('qb-hackerjob:server:notifyVehicleOwner', function(plate)
    local src = source
    
    -- Normalize plate
    plate = plate:gsub("%s+", "")
    
    -- Check if it's a player owned vehicle
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            local targetCitizenId = result[1].citizenid
            
            -- Find the vehicle owner if online
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local targetPlayer = QBCore.Functions.GetPlayer(playerId)
                
                if targetPlayer and targetPlayer.PlayerData.citizenid == targetCitizenId then
                    -- Notify the owner
                    TriggerClientEvent('QBCore:Notify', playerId, "You feel like someone is tracking your vehicle...", "error", 7500)
                    break
                end
            end
        end
    end)
end)

-- Table to track vehicles with disabled brakes (will persist during server uptime)
local disabledBrakesVehicles = {}

-- Register event to save disabled brakes state
RegisterNetEvent('qb-hackerjob:server:saveDisabledBrakes')
AddEventHandler('qb-hackerjob:server:saveDisabledBrakes', function(plate, brakeForce, mass, traction)
    local src = source
    
    -- Store the disabled brake info
    disabledBrakesVehicles[plate] = {
        originalBrakeForce = brakeForce,
        originalMass = mass, 
        originalTraction = traction,
        disabledBy = src,
        timeDisabled = os.time()
    }
    
    print("^3[qb-hackerjob] ^7Vehicle brakes disabled state saved for plate: " .. plate)
end)

-- Register event to remove disabled brakes state
RegisterNetEvent('qb-hackerjob:server:removeDisabledBrakes')
AddEventHandler('qb-hackerjob:server:removeDisabledBrakes', function(plate)
    if disabledBrakesVehicles[plate] then
        disabledBrakesVehicles[plate] = nil
        print("^2[qb-hackerjob] ^7Vehicle brakes disabled state removed for plate: " .. plate)
    end
end)

-- Load disabled brakes when player enters server
RegisterNetEvent('QBCore:Server:PlayerLoaded')
AddEventHandler('QBCore:Server:PlayerLoaded', function()
    local src = source
    
    -- Send the disabled brakes list to the client
    if next(disabledBrakesVehicles) then -- Check if table is not empty
        TriggerClientEvent('qb-hackerjob:client:syncDisabledBrakes', src, disabledBrakesVehicles)
    end
end)

-- Export for other resources to check brake status
exports('IsVehicleBrakesDisabled', function(plate)
    return disabledBrakesVehicles[plate] ~= nil
end)

-- Server callback to check and remove GPS tracker
QBCore.Functions.CreateCallback('qb-hackerjob:server:checkAndRemoveGPS', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local success = false
    
    if not Player then 
        print("^1[qb-hackerjob] ^7Error: Player not found when checking GPS tracker")
        cb(false)
        return 
    end
    
    -- Check if the item exists in shared items
    if not QBCore.Shared.Items[Config.GPSTrackerItem] then
        print("^1[qb-hackerjob] ^7Error: GPS Tracker item '" .. Config.GPSTrackerItem .. "' not defined in shared items!")
        TriggerClientEvent('QBCore:Notify', src, "Error: GPS Tracker item not defined in server items", "error")
        cb(false)
        return
    end
    
    -- Check if player has the item
    local hasItem = Player.Functions.GetItemByName(Config.GPSTrackerItem)
    if hasItem and hasItem.amount > 0 then
        -- Remove the GPS tracker item
        Player.Functions.RemoveItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], "remove")
        print("^2[qb-hackerjob] ^7Successfully removed GPS tracker item from player ID: " .. src)
        success = true
    else
        print("^1[qb-hackerjob] ^7Error: Player " .. src .. " doesn't have GPS tracker item")
        TriggerClientEvent('QBCore:Notify', src, "You don't have a GPS tracker", "error")
    end
    
    cb(success)
end) 