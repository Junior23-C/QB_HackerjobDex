local QBCore = exports['qb-core']:GetCoreObject()

-- Optimized cache with LRU eviction
local vehicleCache = {}
local cacheOrder = {}
local MAX_CACHE_SIZE = 100
local cacheCleanupTimer = nil

-- Rate limiting
local playerActionTimestamps = {}
local RATE_LIMIT_COOLDOWN = 2000 -- 2 seconds between lookups

-- Helper function for rate limiting
local function rateLimitCheck(source, action, cooldown)
    local key = source .. ":" .. action
    local currentTime = GetGameTimer()
    
    if playerActionTimestamps[key] and 
       currentTime - playerActionTimestamps[key] < cooldown then
        return false
    end
    
    playerActionTimestamps[key] = currentTime
    return true
end

-- Optimized cache management with LRU
local function addToCache(plate, data)
    -- Remove from existing position if exists
    for i, v in ipairs(cacheOrder) do
        if v == plate then
            table.remove(cacheOrder, i)
            break
        end
    end
    
    -- Add to end (most recent)
    table.insert(cacheOrder, plate)
    vehicleCache[plate] = {
        timestamp = os.time(),
        data = data
    }
    
    -- Evict oldest if over size limit
    while #cacheOrder > MAX_CACHE_SIZE do
        local oldestPlate = table.remove(cacheOrder, 1)
        vehicleCache[oldestPlate] = nil
    end
end

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

-- Clean up expired cache entries periodically
local function cleanupCache()
    local currentTime = os.time()
    local expiredPlates = {}
    
    for plate, cacheData in pairs(vehicleCache) do
        if currentTime - cacheData.timestamp > (Config.CacheExpiry / 1000) then
            table.insert(expiredPlates, plate)
        end
    end
    
    for _, plate in ipairs(expiredPlates) do
        vehicleCache[plate] = nil
        for i, v in ipairs(cacheOrder) do
            if v == plate then
                table.remove(cacheOrder, i)
                break
            end
        end
    end
end

-- Start cache cleanup timer
CreateThread(function()
    while true do
        Wait(60000) -- Clean up every minute
        cleanupCache()
    end
end)

-- Event handler for when player data is loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Initialize XP metadata if they don't exist
    if not Player.PlayerData.metadata.hackerXP then
        Player.Functions.SetMetaData('hackerXP', 0)
    end
    if not Player.PlayerData.metadata.hackerLevel then
        Player.Functions.SetMetaData('hackerLevel', 1)
    end
end)

-- Utility function to get vehicle info safely
local function GetVehicleInfo(hash)
    local info = {
        make = "Unknown",
        model = "Unknown",
        class = "Unknown"
    }
    
    -- Try QBCore shared vehicles first
    if QBCore.Shared and QBCore.Shared.Vehicles then
        for model, data in pairs(QBCore.Shared.Vehicles) do
            if data.hash == hash then
                info.make = data.brand or "Unknown"
                info.model = data.name or model
                if data.category then
                    info.class = data.category:sub(1,1):upper() .. data.category:sub(2)
                end
                return info
            end
        end
    end
    
    return info
end

-- Main callback for plate lookup (OPTIMIZED)
QBCore.Functions.CreateCallback('qb-hackerjob:server:lookupPlate', function(source, cb, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return cb({ success = false, message = "Player not found" })
    end

    -- Rate limiting check
    if not rateLimitCheck(src, "plateLookup", RATE_LIMIT_COOLDOWN) then
        return cb({ success = false, message = "Please wait before performing another lookup" })
    end

    -- Input validation (prevent SQL injection)
    if not plate or type(plate) ~= "string" or plate == '' then
        return cb({ success = false, message = "Invalid plate format" })
    end
    
    -- Sanitize plate input
    plate = plate:gsub("[^%w%-]", ""):upper()
    
    if string.len(plate) < 2 or string.len(plate) > 8 then
        return cb({ success = false, message = "Invalid plate format" })
    end

    -- Check cache first
    if Config.CacheResults and vehicleCache[plate] then
        local cacheData = vehicleCache[plate]
        if os.time() - cacheData.timestamp < (Config.CacheExpiry / 1000) then
            print('[qb-hackerjob] Plate lookup cache hit for:', plate)
            -- Move to end of LRU
            addToCache(plate, cacheData.data)
            return cb({ success = true, data = cacheData.data })
        end
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

    -- ASYNC database query (prevents server freeze)
    MySQL.Async.fetchAll('SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        local lookupSuccessful = false
        
        if result and #result > 0 then
            lookupSuccessful = true
            vehicleData.owner = "Registered Vehicle"
            vehicleData.ownertype = "player"
            vehicleData.vehicle = result[1].vehicle
            vehicleData.citizenid = result[1].citizenid

            -- Safe JSON decoding
            local charinfo = nil
            if result[1].charinfo then
                local success, decoded = pcall(json.decode, result[1].charinfo)
                if success then
                    charinfo = decoded
                end
            end
            
            if charinfo and charinfo.firstname and charinfo.lastname then
                vehicleData.firstname = charinfo.firstname
                vehicleData.lastname = charinfo.lastname
                vehicleData.owner = charinfo.firstname .. " " .. charinfo.lastname
            end

            -- Get vehicle hash
            if result[1].hash then
                vehicleData.hash = result[1].hash
            elseif result[1].vehicle then
                vehicleData.hash = GetHashKey(result[1].vehicle:lower())
            end

            -- Get vehicle info
            if vehicleData.hash then
                local vehicleInfo = GetVehicleInfo(vehicleData.hash)
                vehicleData.make = vehicleInfo.make
                vehicleData.model = vehicleInfo.model
                vehicleData.class = vehicleInfo.class
            end
            
            -- Check for flags
            if IsEmergencyModel(vehicleData.hash) then
                vehicleData.flags.police = true
                vehicleData.ownertype = "police"
            elseif IsEmergencyPlate(plate) then
                vehicleData.flags.police = true
                vehicleData.ownertype = "police"
            end
            
            if result[1].fakeplate and result[1].fakeplate ~= "" then 
                vehicleData.flags.suspicious = true 
            end
            
            if result[1].state == 2 then 
                vehicleData.flags.impounded = true 
            end

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

        -- Check for flagged vehicles (ASYNC)
        MySQL.Async.fetchAll('SELECT * FROM hackerjob_flagged_vehicles WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(flagResult)
            if flagResult and #flagResult > 0 then
                vehicleData.flags.flagged = true
                vehicleData.flags.flagged_reason = flagResult[1].reason
            end

            -- Add to cache
            if Config.CacheResults and (vehicleData.ownertype == 'player' or vehicleData.ownertype == 'police' or vehicleData.ownertype == 'emergency') then
                addToCache(plate, vehicleData)
            end

            -- Return the final data
            cb({ success = true, data = vehicleData })

            -- Award XP if successful
            if lookupSuccessful and Config.XPEnabled and Config.XPSettings and Config.XPSettings.plateLookup then
                TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'plateLookup', plate, 'Vehicle lookup successful')
            end
        end)
    end)
end)

-- Create a flagged vehicles table in the database
MySQL.ready(function()
    -- Add indexes for better performance
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `hackerjob_flagged_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `plate` varchar(15) NOT NULL,
            `reason` varchar(255) DEFAULT NULL,
            `flagged_by` varchar(50) DEFAULT NULL,
            `flagged_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`),
            KEY `idx_plate` (`plate`)
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Add indexes to improve query performance
    MySQL.Async.execute('CREATE INDEX IF NOT EXISTS idx_player_vehicles_plate ON player_vehicles(plate)')
    MySQL.Async.execute('CREATE INDEX IF NOT EXISTS idx_players_citizenid ON players(citizenid)')
end)

-- Endpoint to flag a vehicle (with rate limiting)
RegisterNetEvent('qb-hackerjob:server:flagVehicle')
AddEventHandler('qb-hackerjob:server:flagVehicle', function(plate, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Rate limiting
    if not rateLimitCheck(src, "flagVehicle", 5000) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before flagging another vehicle', 'error')
        return
    end
    
    -- Authorization check
    if Player.PlayerData.job.name ~= Config.HackerJobName and Player.PlayerData.job.name ~= 'police' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to flag vehicles', 'error')
        return
    end
    
    -- Input validation
    if not plate or type(plate) ~= "string" or plate == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid plate number', 'error')
        return
    end
    
    plate = plate:gsub("[^%w%-]", ""):upper()
    reason = reason and tostring(reason):sub(1, 255) or "No reason provided"
    
    -- ASYNC insert with parameterized query
    MySQL.Async.execute('INSERT INTO hackerjob_flagged_vehicles (plate, reason, flagged_by) VALUES (@plate, @reason, @flagged_by) ON DUPLICATE KEY UPDATE reason = @reason, flagged_by = @flagged_by', {
        ['@plate'] = plate,
        ['@reason'] = reason,
        ['@flagged_by'] = Player.PlayerData.citizenid
    }, function(affectedRows)
        if affectedRows > 0 then
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

-- Callback to check if a vehicle is flagged (ASYNC)
QBCore.Functions.CreateCallback('qb-hackerjob:server:isVehicleFlagged', function(source, cb, plate)
    if not plate or type(plate) ~= "string" or plate == '' then
        cb(false)
        return
    end
    
    plate = plate:gsub("[^%w%-]", ""):upper()
    
    MySQL.Async.fetchAll('SELECT * FROM hackerjob_flagged_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result and #result > 0 then
            cb(true, result[1].reason)
        else
            cb(false)
        end
    end)
end)

-- Clean up old action timestamps periodically
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        local currentTime = GetGameTimer()
        local expiredKeys = {}
        
        for key, timestamp in pairs(playerActionTimestamps) do
            if currentTime - timestamp > 300000 then -- 5 minutes old
                table.insert(expiredKeys, key)
            end
        end
        
        for _, key in ipairs(expiredKeys) do
            playerActionTimestamps[key] = nil
        end
    end
end)

-- Export the GenerateVIN function for other resources
exports('GenerateVIN', GenerateVIN)