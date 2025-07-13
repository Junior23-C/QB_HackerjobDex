local QBCore = exports['qb-core']:GetCoreObject()
local vehicleCache = {}

-- Helper function to check if a plate belongs to an emergency vehicle
local function IsEmergencyPlate(plate)
    for _, prefix in ipairs(Config.PoliceVehiclePrefixes) do
        if string.find(plate:upper(), prefix) then
            return true
        end
    end
    
    for _, prefix in ipairs(Config.EmergencyServicePrefixes) do
        if string.find(plate:upper(), prefix) then
            return true
        end
    end
    
    return false
end

-- Helper function to check if a vehicle model is an emergency vehicle
local function IsEmergencyModel(model)
    for _, emergencyModel in ipairs(Config.EmergencyVehicleModels) do
        if model == emergencyModel then
            return true
        end
    end
    
    return false
end

-- Generate a VIN for vehicles
local function GenerateVIN()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local vin = ""
    
    -- Generate the first 3 characters (manufacturer ID)
    for i = 1, 3 do
        local index = math.random(1, #chars)
        vin = vin .. chars:sub(index, index)
    end
    
    -- Add a hyphen for readability
    vin = vin .. "-"
    
    -- Generate the next 6 characters (vehicle attributes)
    for i = 1, 6 do
        local index = math.random(1, #chars)
        vin = vin .. chars:sub(index, index)
    end
    
    -- Add another hyphen for readability
    vin = vin .. "-"
    
    -- Generate the last 8 characters (unique serial)
    for i = 1, 8 do
        local index = math.random(1, #chars)
        vin = vin .. chars:sub(index, index)
    end
    
    return vin
end

-- Clear the vehicle cache periodically to prevent memory bloat
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.CacheExpiry)
        vehicleCache = {}
    end
end)

-- Event handler for when player data is loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Initialize stats if they don't exist
    local currentStats = GetHackerStats(src)
    if not Player.PlayerData.metadata['hacker_xp'] then
        Player.Functions.SetMetaData('hacker_xp', 0)
    end
    if not Player.PlayerData.metadata['hacker_level'] then
         Player.Functions.SetMetaData('hacker_level', 1)
    end

    -- Send initial stats to the client shortly after loading
    Citizen.SetTimeout(5000, function()
        local stats = GetHackerStats(src)
        if stats then
            local level, levelName, nextLevelXP = CalculateLevel(stats.xp)
             TriggerClientEvent('qb-hackerjob:client:updateStats', src, {
                xp = stats.xp,
                level = level,
                levelName = levelName,
                nextLevelXP = nextLevelXP
            })
        end
    end)
end)

-- Optional: Save stats on logout (metadata usually saves automatically with QBCore player save)
-- RegisterNetEvent('QBCore:Player:OnLogout', function()
--    local src = source
--    -- Logic to explicitly save if needed, but metadata should handle it
-- end)

-- Debug command to set hacker XP
QBCore.Commands.Add("sethackerxp", "Set Hacker XP (Admin Only)", {{name="id", help="Player ID"}, {name="xp", help="Amount of XP"}}, true, function(source, args)
    local targetId = tonumber(args[1])
    local xpAmount = tonumber(args[2])

    if not targetId or not xpAmount or xpAmount < 0 then
        TriggerClientEvent('QBCore:Notify', source, "Invalid arguments. Use /sethackerxp [player id] [xp amount]", 'error')
        return
    end

    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', source, "Player not found.", 'error')
        return
    end

    local _, newLevelName, nextLevelXP = CalculateLevel(xpAmount)
    local newLevel = GetHackerStats(targetId).level -- Use CalculateLevel to get the accurate level

    -- Directly set the metadata
    TargetPlayer.Functions.SetMetaData('hacker_xp', xpAmount)
    TargetPlayer.Functions.SetMetaData('hacker_level', newLevel) -- Need to recalculate level

    -- Recalculate final stats after setting
    local finalLevel, finalLevelName, finalNextLevelXP = CalculateLevel(xpAmount)
    TargetPlayer.Functions.SetMetaData('hacker_level', finalLevel) -- Set correct level

    -- Send update to the target client
    TriggerClientEvent('qb-hackerjob:client:updateStats', targetId, {
        xp = xpAmount,
        level = finalLevel,
        levelName = finalLevelName,
        nextLevelXP = finalNextLevelXP
    })

    TriggerClientEvent('QBCore:Notify', source, string.format("Set %s's hacker XP to %d (Level %d)", TargetPlayer.PlayerData.charinfo.firstname, xpAmount, finalLevel), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, string.format("Your hacker XP was set to %d by an admin.", xpAmount), 'primary')

end, "admin") -- Set permission level (e.g., "admin", "god")

-- Main callback for plate lookup
QBCore.Functions.CreateCallback('qb-hackerjob:server:lookupPlate', function(source, cb, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return cb({ success = false, message = "Player not found" })
    end

    if not plate or plate == '' or string.len(plate) < 2 or string.len(plate) > 8 then
        return cb({ success = false, message = "Invalid plate format" })
    end

    plate = plate:upper()

    if Config.CacheResults and vehicleCache[plate] and vehicleCache[plate].timestamp > (os.time() - (Config.CacheExpiry / 1000)) then
        print('[qb-hackerjob] Plate lookup cache hit for:', plate)
        return cb({ success = true, data = vehicleCache[plate].data })
    end

    local vehicleData = {
        plate = plate,
        owner = "Unknown",
        ownertype = "unknown",
        firstname = nil,
        lastname = nil,
        citizenid = nil,
        make = "Unknown",
        model = "Unknown",
        class = "Unknown",
        vehicle = nil,
        hash = nil,
        vin = GenerateVIN(),
        flags = {},
    }

    -- Wrap DB query in pcall for error handling
    local success, result = pcall(function()
        -- Use MySQL.Sync.fetchAll for simpler synchronous handling within callback
        return MySQL.Sync.fetchAll('SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ?', {plate})
    end)

    if not success then
        print(string.format("[qb-hackerjob] Error during MySQL query for plate %s: %s", plate, result)) -- Log the actual error
        return cb({ success = false, message = "Database error during lookup" }) 
    end

    -- Process result if query was successful
    local lookupSuccessful = false
    if result and #result > 0 then
        lookupSuccessful = true
        vehicleData.owner = "Registered Vehicle"
        vehicleData.ownertype = "player"
        vehicleData.vehicle = result[1].vehicle
        vehicleData.citizenid = result[1].citizenid

        -- Wrap JSON decoding in pcall
        local jsonSuccess, charinfo = pcall(json.decode, result[1].charinfo or '{}')
        if jsonSuccess and charinfo and charinfo.firstname and charinfo.lastname then
            vehicleData.firstname = charinfo.firstname
            vehicleData.lastname = charinfo.lastname
            vehicleData.owner = charinfo.firstname .. " " .. charinfo.lastname
        else
            if not jsonSuccess then
                 print(string.format("[qb-hackerjob] Error decoding charinfo JSON for citizenid %s: %s", vehicleData.citizenid, charinfo))
            end
            -- Keep owner as "Registered Vehicle" if names are missing
        end

        -- Get vehicle hash if available
        if result[1].hash then
            vehicleData.hash = result[1].hash
        elseif result[1].vehicle then
            vehicleData.hash = GetHashKey(result[1].vehicle:lower())
        end

        -- Get Make/Model/Class (using existing logic)
        if vehicleData.hash and QBShared and QBShared.VehicleHashes and QBShared.VehicleHashes[vehicleData.hash] then
            local qbVehData = QBShared.VehicleHashes[vehicleData.hash]
            vehicleData.make = qbVehData.brand
            vehicleData.model = qbVehData.name
            if qbVehData.category and qbVehData.category ~= '' then
                vehicleData.class = qbVehData.category:sub(1,1):upper() .. qbVehData.category:sub(2)
            else
                vehicleData.class = "Unknown"
            end
        elseif vehicleData.hash then
            local vehicleInfo = GetVehicleInfo(vehicleData.hash)
            vehicleData.make = vehicleInfo.make
            vehicleData.model = vehicleInfo.model
            local vehicleClassId = GetVehicleClassFromModel(vehicleData.hash)
            vehicleData.class = Config.VehicleClasses[vehicleClassId] or "Unknown"
        end
        
        -- Check for flags (using existing logic)
        local isEmergencyModelCheck = IsEmergencyModel(vehicleData.hash)
        if isEmergencyModelCheck then
            local tempClassIdCheck = GetVehicleClassFromModel(vehicleData.hash) 
            if tempClassIdCheck == 18 then 
                vehicleData.flags.police = true
                vehicleData.ownertype = "police"
            else
                vehicleData.flags.emergency = true
                vehicleData.ownertype = "emergency"
            end
        elseif IsEmergencyPlate(plate) then
            vehicleData.flags.police = true
            vehicleData.ownertype = "police"
        end
        if result[1].fakeplate and result[1].fakeplate ~= "" then vehicleData.flags.suspicious = true end
        if result[1].state == 2 then vehicleData.flags.impounded = true end

    else
        -- Not a player vehicle
        if IsEmergencyPlate(plate) then
            lookupSuccessful = true
            vehicleData.owner = "Government Vehicle"
            vehicleData.ownertype = "police"
            vehicleData.flags.police = true
        else
            lookupSuccessful = false
            vehicleData.owner = "Unregistered Vehicle"
            vehicleData.ownertype = "npc"
        end
    end

    -- Add to cache if enabled and data is worth caching (e.g., not just generic NPC)
    if Config.CacheResults and (vehicleData.ownertype == 'player' or vehicleData.ownertype == 'police' or vehicleData.ownertype == 'emergency') then
        vehicleCache[plate] = { timestamp = os.time(), data = vehicleData }
    end

    -- Return the final data
    cb({ success = true, data = vehicleData })

    -- Award XP if lookup was considered successful and XP is enabled
    if lookupSuccessful and Config.XPEnabled and Config.XPSettings and Config.XPSettings.plateLookup then
        -- Trigger client event to handle XP addition (client will trigger server)
        TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'plateLookup', plate, 'Vehicle lookup successful')
    end
end)

-- Utility function to get vehicle class from model
function GetVehicleClassFromModel(modelHash)
    -- Default to automobile (class 0) if we can't determine
    local vehicleClass = 0
    
    -- Try to get class from game first (if this is called on the server)
    if DoesEntityExist(CreateVehicle(modelHash, 0, 0, 0, 0, false, false)) then
        local tempVeh = CreateVehicle(modelHash, 0, 0, 0, 0, false, false)
        vehicleClass = GetVehicleClass(tempVeh)
        DeleteEntity(tempVeh)
    else
        -- Fallback to known emergency vehicles
        for _, model in ipairs(Config.EmergencyVehicleModels) do
            if model == modelHash then
                return 18 -- Emergency class
            end
        end
        
        -- Otherwise, try to determine from model name pattern
        local modelName = "unknown"
        
        for model, data in pairs(QBCore.Shared.Vehicles) do
            if data.hash == modelHash then
                modelName = model:lower()
                break
            end
        end
        
        -- Some basic class detection by name patterns
        if string.find(modelName, "police") or string.find(modelName, "sheriff") or string.find(modelName, "fbi") then
            vehicleClass = 18 -- Emergency
        elseif string.find(modelName, "ambulance") or string.find(modelName, "firetruk") then
            vehicleClass = 18 -- Emergency
        elseif string.find(modelName, "bus") or string.find(modelName, "coach") or string.find(modelName, "airbus") then
            vehicleClass = 13 -- Cycles/Bus (using 13 since buses don't have their own class)
        elseif string.find(modelName, "boat") or string.find(modelName, "jetmax") or string.find(modelName, "marquis") then
            vehicleClass = 14 -- Boats
        elseif string.find(modelName, "heli") or string.find(modelName, "maverick") or string.find(modelName, "buzzard") then
            vehicleClass = 15 -- Helicopters
        elseif string.find(modelName, "plane") or string.find(modelName, "jet") or string.find(modelName, "luxor") then
            vehicleClass = 16 -- Planes
        end
    end
    
    return vehicleClass
end

-- Create a flagged vehicles table in the database to track stolen or flagged vehicles
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `hackerjob_flagged_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `plate` varchar(15) NOT NULL,
            `reason` varchar(255) DEFAULT NULL,
            `flagged_by` varchar(50) DEFAULT NULL,
            `flagged_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`)
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- Endpoint to flag a vehicle
RegisterNetEvent('qb-hackerjob:server:flagVehicle')
AddEventHandler('qb-hackerjob:server:flagVehicle', function(plate, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Player.PlayerData.job.name ~= Config.HackerJobName and not Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to flag vehicles', 'error')
        return
    end
    
    if not plate or plate == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid plate number', 'error')
        return
    end
    
    plate = plate:upper()
    
    MySQL.insert('INSERT INTO hackerjob_flagged_vehicles (plate, reason, flagged_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE reason = ?, flagged_by = ?',
        {plate, reason, Player.PlayerData.citizenid, reason, Player.PlayerData.citizenid}, function(id)
        if id > 0 then
            TriggerClientEvent('QBCore:Notify', src, 'Vehicle with plate ' .. plate .. ' has been flagged', 'success')
            
            -- Update cache if exists
            if Config.CacheResults and vehicleCache[plate] then
                vehicleCache[plate].data.flags.flagged = true
                vehicleCache[plate].data.flags.flagged_reason = reason
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Error flagging vehicle', 'error')
        end
    end)
end)

-- Callback to check if a vehicle is flagged
QBCore.Functions.CreateCallback('qb-hackerjob:server:isVehicleFlagged', function(source, cb, plate)
    if not plate or plate == '' then
        cb(false)
        return
    end
    
    plate = plate:upper()
    
    MySQL.query('SELECT * FROM hackerjob_flagged_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            cb(true, result[1].reason)
        else
            cb(false)
        end
    end)
end)

-- Export the GenerateVIN function for other resources
exports('GenerateVIN', GenerateVIN) 