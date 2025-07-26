local QBCore = exports['qb-core']:GetCoreObject()
local vehicleCache = {}

-- Performance monitoring and statistics
local performanceStats = {
    totalQueries = 0,
    slowQueries = 0,
    averageQueryTime = 0,
    cacheHits = 0,
    cacheMisses = 0,
    lastResetTime = os.time()
}

-- Enhanced error handling for plate lookup system
local function SafeLogError(message, context)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    print('^1[qb-hackerjob:plate-lookup:ERROR] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
end

local function SafeLogInfo(message, context)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    print('^2[qb-hackerjob:plate-lookup:INFO] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
end

local function SafeLogDebug(message, context)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local contextStr = context and (' [' .. tostring(context) .. ']') or ''
    print('^3[qb-hackerjob:plate-lookup:DEBUG] ^7' .. string.format('[%s] %s%s', timestamp, message, contextStr))
end

-- Safe database query wrapper
local function SafeQuery(query, params, callback, retries)
    retries = retries or 3
    
    if not query or type(query) ~= 'string' then
        SafeLogError('Invalid query provided to SafeQuery')
        if callback then callback(nil) end
        return
    end
    
    if not callback or type(callback) ~= 'function' then
        SafeLogError('Invalid callback provided to SafeQuery')
        return
    end
    
    local function executeQuery(attempt)
        print("^3[qb-hackerjob:server] ^7Executing MySQL query attempt " .. attempt .. "/" .. retries)
        
        -- Add timeout protection for MySQL queries
        local queryTimeout = SetTimeout(10000, function() -- 10 second timeout per query
            SafeLogError('MySQL query timeout on attempt ' .. attempt)
            print("^1[qb-hackerjob:server] ^7MySQL query timeout!")
            if attempt >= retries then
                callback(nil)
            end
        end)
        
        MySQL.query(query, params or {}, function(result)
            ClearTimeout(queryTimeout)
            
            if result ~= nil then -- result can be empty array, which is valid
                SafeLogDebug('Query successful on attempt ' .. attempt)
                print("^2[qb-hackerjob:server] ^7MySQL query successful, returned " .. #result .. " results")
                callback(result)
            else
                SafeLogError('Query failed on attempt ' .. attempt .. '/' .. retries)
                print("^1[qb-hackerjob:server] ^7MySQL query returned nil on attempt " .. attempt)
                if attempt < retries then
                    Citizen.Wait(500 * attempt) -- Exponential backoff
                    executeQuery(attempt + 1)
                else
                    SafeLogError('Query failed after all retries: ' .. query)
                    print("^1[qb-hackerjob:server] ^7All MySQL query attempts failed!")
                    callback(nil)
                end
            end
        end)
    end
    
    executeQuery(1)
end

-- Safe player validation
local function SafeGetPlayer(source)
    if not source or type(source) ~= 'number' then
        SafeLogError('Invalid source provided to SafeGetPlayer', source)
        return nil
    end
    
    local success, player = pcall(function()
        return QBCore.Functions.GetPlayer(source)
    end)
    
    if not success then
        SafeLogError('Failed to get player data', source)
        return nil
    end
    
    return player
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

-- Optimized cache management with selective expiry and memory monitoring
local function cleanupExpiredCache()
    local currentTime = os.time()
    local expiryThreshold = Config.CacheExpiry / 1000 -- Convert to seconds
    local removedCount = 0
    local totalEntries = 0
    
    -- Count total entries before cleanup
    for _ in pairs(vehicleCache) do
        totalEntries = totalEntries + 1
    end
    
    for plate, cacheData in pairs(vehicleCache) do
        if currentTime - cacheData.timestamp > expiryThreshold then
            vehicleCache[plate] = nil
            removedCount = removedCount + 1
        end
    end
    
    -- Memory usage monitoring and logging
    local remainingEntries = totalEntries - removedCount
    local memoryEstimateMB = (remainingEntries * 0.5) / 1024 -- Rough estimate: 0.5KB per entry
    
    if removedCount > 0 then
        print(string.format("^2[qb-hackerjob] ^7Cache cleanup: removed %d/%d entries, ~%.2fMB memory used", 
            removedCount, totalEntries, memoryEstimateMB))
    end
    
    -- Warning if cache is growing too large
    if remainingEntries > 1000 then
        print(string.format("^3[qb-hackerjob] ^7WARNING: Large cache detected (%d entries, ~%.2fMB)", 
            remainingEntries, memoryEstimateMB))
    end
end

-- Run cache cleanup every 2 minutes instead of wiping everything every 5 minutes
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(120000) -- 2 minutes
        cleanupExpiredCache()
    end
end)

-- Event handler for when player data is loaded (using new metadata system)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Initialize XP metadata if they don't exist (using new system)
    if not Player.PlayerData.metadata.hackerXP then
        Player.Functions.SetMetaData('hackerXP', 0)
    end
    if not Player.PlayerData.metadata.hackerLevel then
        Player.Functions.SetMetaData('hackerLevel', 1)
    end
end)

-- Optional: Save stats on logout (metadata usually saves automatically with QBCore player save)
-- RegisterNetEvent('QBCore:Player:OnLogout', function()
--    local src = source
--    -- Logic to explicitly save if needed, but metadata should handle it
-- end)

-- Note: XP commands are now handled in main.lua using the new metadata system

-- Enhanced main callback for plate lookup with comprehensive error handling
QBCore.Functions.CreateCallback('qb-hackerjob:server:lookupPlate', function(source, cb, plate)
    local src = source
    
    print("^2[qb-hackerjob:server] ^7Plate lookup callback triggered by source: " .. tostring(src) .. " for plate: " .. tostring(plate))
    
    -- Validate inputs
    if not src or type(src) ~= 'number' then
        SafeLogError('Invalid source in lookupPlate callback', src)
        print("^1[qb-hackerjob:server] ^7Invalid source provided")
        if cb then cb({ success = false, message = "Invalid request source" }) end
        return
    end
    
    if not cb then
        SafeLogError('No callback provided in lookupPlate', src)
        print("^1[qb-hackerjob:server] ^7No callback function provided")
        return
    end
    
    if not plate then
        SafeLogError('No plate provided in lookupPlate', src)
        print("^1[qb-hackerjob:server] ^7No plate provided")
        cb({ success = false, message = "No plate number provided" })
        return
    end
    
    local Player = SafeGetPlayer(src)
    if not Player then
        SafeLogError('Player not found in lookupPlate', src)
        print("^1[qb-hackerjob:server] ^7Player not found for source: " .. tostring(src))
        cb({ success = false, message = "Player session invalid - please reconnect" })
        return
    end
    
    print("^2[qb-hackerjob:server] ^7Player found, proceeding with plate lookup")
    
    -- Enhanced server-side job authorization check
    if Config.RequireJob then
        local jobCheckSuccess, authorized = pcall(function()
            if not Player.PlayerData or not Player.PlayerData.job then
                return false, "Invalid player job data"
            end
            
            if Player.PlayerData.job.name ~= Config.HackerJobName then
                return false, "Insufficient job permissions"
            end
            
            if Config.JobRank > 0 then
                if not Player.PlayerData.job.grade or Player.PlayerData.job.grade.level < Config.JobRank then
                    return false, "Insufficient job rank"
                end
            end
            
            return true, "Authorized"
        end)
        
        if not jobCheckSuccess then
            SafeLogError('Job authorization check failed', src)
            cb({ success = false, message = "System error during authorization" })
            return
        end
        
        if not authorized then
            SafeLogError('Job authorization denied', src)
            cb({ success = false, message = "Access denied - " .. (authorized or "unknown reason") })
            return
        end
    end

    -- Enhanced input validation for plate numbers with error handling
    local plateValidationSuccess, validatedPlate, validationError = pcall(function()
        if type(plate) ~= 'string' then
            return nil, "Plate must be text"
        end
        
        -- Remove whitespace and convert to uppercase
        local cleanPlate = plate:gsub("%s+", ""):upper()
        
        if cleanPlate == "" then
            return nil, "Plate cannot be empty"
        end
        
        -- Validate plate format (2-8 alphanumeric characters)
        if not cleanPlate:match("^[A-Z0-9]+$") then
            return nil, "Plate can only contain letters and numbers"
        end
        
        if string.len(cleanPlate) < 2 or string.len(cleanPlate) > 8 then
            return nil, "Plate must be 2-8 characters long"
        end
        
        return cleanPlate, nil
    end)
    
    if not plateValidationSuccess then
        SafeLogError('Plate validation error: ' .. tostring(validatedPlate), src)
        cb({ success = false, message = "System error during plate validation" })
        return
    end
    
    if not validatedPlate then
        SafeLogError('Invalid plate format: ' .. tostring(plate), src)
        cb({ success = false, message = validationError or "Invalid plate format" })
        return
    end
    
    plate = validatedPlate
    SafeLogDebug('Plate validated successfully: ' .. plate, src)

    -- Safe cache check with error handling
    local cacheCheckSuccess, cacheResult = pcall(function()
        if not Config.CacheResults then
            return false, 'Cache disabled'
        end
        
        if not vehicleCache[plate] then
            return false, 'No cache entry'
        end
        
        local cacheEntry = vehicleCache[plate]
        if not cacheEntry.timestamp or not cacheEntry.data then
            return false, 'Invalid cache entry'
        end
        
        local cacheAge = os.time() - cacheEntry.timestamp
        local maxAge = (Config.CacheExpiry or 300000) / 1000
        
        if cacheAge > maxAge then
            return false, 'Cache expired'
        end
        
        return true, cacheEntry.data
    end)
    
    if cacheCheckSuccess and cacheResult then
        SafeLogDebug('Cache hit for plate: ' .. plate, src)
        performanceStats.cacheHits = performanceStats.cacheHits + 1
        cb({ success = true, data = cacheResult })
        return
    end
    
    -- Cache miss or error
    SafeLogDebug('Cache miss for plate: ' .. plate .. ' (' .. tostring(cacheResult) .. ')', src)
    performanceStats.cacheMisses = performanceStats.cacheMisses + 1

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

    -- Enhanced async MySQL query with comprehensive error handling
    local queryStartTime = GetGameTimer()
    SafeLogDebug('Starting database query for plate: ' .. plate, src)
    print("^2[qb-hackerjob:server] ^7Starting MySQL query for plate: " .. plate)
    
    SafeQuery(
        'SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ?',
        {plate},
        function(result)
            local queryTime = GetGameTimer() - queryStartTime
            
            -- Performance monitoring: log slow queries and update stats
            updateQueryStats(queryTime)
            if queryTime > 50 then
                SafeLogError('Slow query detected: ' .. queryTime .. 'ms for plate ' .. plate, src)
            end
            
            if not result then
                SafeLogError('Database query returned null result for plate: ' .. plate, src)
                print("^1[qb-hackerjob:server] ^7Database query returned null, providing fallback response")
                
                -- Provide fallback response instead of failing completely
                local fallbackData = {
                    plate = plate,
                    owner = "Database Unavailable",
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
                    flags = { database_error = true },
                }
                
                cb({ success = true, data = fallbackData })
                return
            end
            
            SafeLogDebug('Query completed in ' .. queryTime .. 'ms, found ' .. #result .. ' results', src)

            -- Safe result processing with error handling
            local processingSuccess, vehicleData, lookupSuccessful = pcall(function()
                local vData = {
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
                
                local successful = false
                
                if result and #result > 0 then
                    successful = true
                    vData.owner = "Registered Vehicle"
                    vData.ownertype = "player"
                    vData.vehicle = result[1].vehicle
                    vData.citizenid = result[1].citizenid

                    -- Safe JSON decoding with enhanced error handling
                    local jsonSuccess, charinfo = pcall(function()
                        local charData = result[1].charinfo
                        if not charData or charData == '' then
                            return nil
                        end
                        
                        if type(charData) == 'string' then
                            return json.decode(charData)
                        else
                            return charData
                        end
                    end)
                    
                    if jsonSuccess and charinfo and type(charinfo) == 'table' then
                        if charinfo.firstname and charinfo.lastname then
                            vData.firstname = charinfo.firstname
                            vData.lastname = charinfo.lastname
                            vData.owner = charinfo.firstname .. " " .. charinfo.lastname
                        end
                    else
                        SafeLogDebug('Failed to decode character info for plate: ' .. plate)
                    end

                    -- Safe vehicle hash retrieval
                    local hashSuccess, hash = pcall(function()
                        if result[1].hash and type(result[1].hash) == 'number' then
                            return result[1].hash
                        elseif result[1].vehicle and type(result[1].vehicle) == 'string' then
                            return GetHashKey(result[1].vehicle:lower())
                        end
                        return nil
                    end)
                    
                    if hashSuccess and hash then
                        vData.hash = hash
                    end

                    -- Safe vehicle data retrieval
                    local vehicleDataSuccess, vehicleInfo = pcall(function()
                        if not vData.hash then
                            return nil
                        end
                        
                        -- Try QBShared first
                        if QBShared and QBShared.VehicleHashes and QBShared.VehicleHashes[vData.hash] then
                            return QBShared.VehicleHashes[vData.hash]
                        end
                        
                        return nil
                    end)
                    
                    if vehicleDataSuccess and vehicleInfo then
                        vData.make = vehicleInfo.brand or "Unknown"
                        vData.model = vehicleInfo.name or "Unknown"
                        if vehicleInfo.category and vehicleInfo.category ~= '' then
                            vData.class = vehicleInfo.category:sub(1,1):upper() .. vehicleInfo.category:sub(2)
                        else
                            vData.class = "Unknown"
                        end
                    elseif vData.hash then
                        -- Fallback vehicle info retrieval
                        local fallbackSuccess, fallbackInfo = pcall(function()
                            local info = GetVehicleInfo(vData.hash)
                            if info then
                                return info
                            end
                            return { make = "Unknown", model = "Unknown" }
                        end)
                        
                        if fallbackSuccess and fallbackInfo then
                            vData.make = fallbackInfo.make or "Unknown"
                            vData.model = fallbackInfo.model or "Unknown"
                            
                            local classSuccess, classId = pcall(GetVehicleClassFromModel, vData.hash)
                            if classSuccess and classId and Config.VehicleClasses then
                                vData.class = Config.VehicleClasses[classId] or "Unknown"
                            end
                        end
                    end
            
                    -- Safe flag checking with error handling
                    local flagCheckSuccess = pcall(function()
                        -- Check for emergency model
                        local isEmergencyModelCheck = false
                        if vData.hash then
                            local emergencyCheckSuccess, isEmergency = pcall(IsEmergencyModel, vData.hash)
                            if emergencyCheckSuccess then
                                isEmergencyModelCheck = isEmergency
                            end
                        end
                        
                        if isEmergencyModelCheck then
                            local classCheckSuccess, tempClassId = pcall(GetVehicleClassFromModel, vData.hash)
                            if classCheckSuccess and tempClassId == 18 then
                                vData.flags.police = true
                                vData.ownertype = "police"
                            else
                                vData.flags.emergency = true
                                vData.ownertype = "emergency"
                            end
                        else
                            -- Check for emergency plate
                            local plateCheckSuccess, isEmergencyPlate = pcall(IsEmergencyPlate, plate)
                            if plateCheckSuccess and isEmergencyPlate then
                                vData.flags.police = true
                                vData.ownertype = "police"
                            end
                        end
                        
                        -- Check other flags safely
                        if result[1] then
                            if result[1].fakeplate and result[1].fakeplate ~= "" then
                                vData.flags.suspicious = true
                            end
                            if result[1].state == 2 then
                                vData.flags.impounded = true
                            end
                        end
                    end)
                    
                    if not flagCheckSuccess then
                        SafeLogError('Error during flag checking for plate: ' .. plate)
                    end

                else
                    -- Not a player vehicle - safe emergency check
                    local emergencyCheckSuccess, isEmergency = pcall(IsEmergencyPlate, plate)
                    if emergencyCheckSuccess and isEmergency then
                        successful = true
                        vData.owner = "Government Vehicle"
                        vData.ownertype = "police"
                        vData.flags.police = true
                    else
                        successful = false
                        vData.owner = "Unregistered Vehicle"
                        vData.ownertype = "npc"
                    end
                end
                
                return vData, successful
            end)
            
            if not processingSuccess then
                SafeLogError('Error processing vehicle data: ' .. tostring(vehicleData), src)
                cb({ success = false, message = "Error processing vehicle information" })
                return
            end

            -- Safe cache addition
            local cacheAddSuccess = pcall(function()
                if Config.CacheResults and vehicleData and (vehicleData.ownertype == 'player' or vehicleData.ownertype == 'police' or vehicleData.ownertype == 'emergency') then
                    vehicleCache[plate] = { 
                        timestamp = os.time(), 
                        data = vehicleData 
                    }
                    SafeLogDebug('Added plate to cache: ' .. plate)
                end
            end)
            
            if not cacheAddSuccess then
                SafeLogError('Failed to add plate to cache: ' .. plate)
            end
            
            -- Return the final data
            SafeLogDebug('Plate lookup completed successfully: ' .. plate, src)
            cb({ success = true, data = vehicleData })

            -- Safe XP awarding
            if lookupSuccessful and Config.XPEnabled and Config.XPSettings and Config.XPSettings.plateLookup then
                local xpSuccess = pcall(function()
                    TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'plateLookup', plate, 'Vehicle lookup successful')
                end)
                
                if not xpSuccess then
                    SafeLogError('Failed to award XP for plate lookup', src)
                end
            end
        end,
        3 -- Retry up to 3 times
    )
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

-- Enhanced vehicle flagging endpoint with error handling
RegisterNetEvent('qb-hackerjob:server:flagVehicle')
AddEventHandler('qb-hackerjob:server:flagVehicle', function(plate, reason)
    local src = source
    
    -- Validate inputs
    if not src or type(src) ~= 'number' then
        SafeLogError('Invalid source in flagVehicle event', src)
        return
    end
    
    if not plate or type(plate) ~= 'string' then
        SafeLogError('Invalid plate in flagVehicle event', src)
        return
    end
    
    if not reason or type(reason) ~= 'string' then
        SafeLogError('Invalid reason in flagVehicle event', src)
        return
    end
    
    local Player = SafeGetPlayer(src)
    if not Player then
        SafeLogError('Player not found for flagVehicle', src)
        return
    end
    
    -- Enhanced authorization check with error handling
    local authSuccess, isAuthorized, authError = pcall(function()
        if not Player.PlayerData or not Player.PlayerData.job then
            return false, "Invalid player job data"
        end
        
        local playerJob = Player.PlayerData.job.name
        
        -- Check if player is hacker
        if playerJob == Config.HackerJobName then
            if Config.JobRank == 0 then
                return true, "Hacker job authorized"
            elseif Player.PlayerData.job.grade and Player.PlayerData.job.grade.level >= Config.JobRank then
                return true, "Hacker job rank authorized"
            else
                return false, "Insufficient hacker job rank"
            end
        end
        
        -- Check if player is police
        local policeJobs = {'police', 'lspd', 'bcso', 'sasp'}
        for _, jobName in pairs(policeJobs) do
            if playerJob == jobName then
                return true, "Police job authorized"
            end
        end
        
        return false, "No authorized job found"
    end)
    
    if not authSuccess then
        SafeLogError('Authorization check failed: ' .. tostring(isAuthorized), src)
        pcall(function()
            TriggerClientEvent('QBCore:Notify', src, 'System error during authorization', 'error')
        end)
        return
    end
    
    if not isAuthorized then
        SafeLogError('Authorization denied: ' .. tostring(authError), src)
        pcall(function()
            TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        end)
        return
    end
    
    -- Enhanced plate validation
    local plateValidationSuccess, validatedPlate, validationError = pcall(function()
        local cleanPlate = plate:gsub("%s+", ""):upper()
        
        if cleanPlate == "" then
            return nil, "Plate cannot be empty"
        end
        
        if not cleanPlate:match("^[A-Z0-9]+$") then
            return nil, "Plate can only contain letters and numbers"
        end
        
        if string.len(cleanPlate) < 2 or string.len(cleanPlate) > 8 then
            return nil, "Plate must be 2-8 characters long"
        end
        
        return cleanPlate, nil
    end)
    
    if not plateValidationSuccess then
        SafeLogError('Plate validation error: ' .. tostring(validatedPlate), src)
        pcall(function()
            TriggerClientEvent('QBCore:Notify', src, 'System error during validation', 'error')
        end)
        return
    end
    
    if not validatedPlate then
        SafeLogError('Invalid plate format: ' .. plate, src)
        pcall(function()
            TriggerClientEvent('QBCore:Notify', src, validationError or 'Invalid plate format', 'error')
        end)
        return
    end
    
    plate = validatedPlate
    
    -- Safe database insert with error handling
    local insertStartTime = GetGameTimer()
    local citizenid = Player.PlayerData.citizenid
    
    if not citizenid then
        SafeLogError('No citizenid found for player', src)
        pcall(function()
            TriggerClientEvent('QBCore:Notify', src, 'Player data error', 'error')
        end)
        return
    end
    
    SafeQuery(
        'INSERT INTO hackerjob_flagged_vehicles (plate, reason, flagged_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE reason = ?, flagged_by = ?',
        {plate, reason, citizenid, reason, citizenid},
        function(result)
            local insertTime = GetGameTimer() - insertStartTime
            
            if insertTime > 30 then
                SafeLogError('Slow vehicle flag insert: ' .. insertTime .. 'ms')
            end
            
            if result and result.insertId and result.insertId > 0 then
                SafeLogInfo('Vehicle flagged successfully: ' .. plate, src)
                
                -- Safe success notification
                pcall(function()
                    TriggerClientEvent('QBCore:Notify', src, 'Vehicle with plate ' .. plate .. ' has been flagged', 'success')
                end)
                
                -- Safe cache update
                pcall(function()
                    if Config.CacheResults and vehicleCache[plate] then
                        vehicleCache[plate].data.flags.flagged = true
                        vehicleCache[plate].data.flags.flagged_reason = reason
                    end
                end)
            else
                SafeLogError('Failed to flag vehicle: ' .. plate, src)
                pcall(function()
                    TriggerClientEvent('QBCore:Notify', src, 'Error flagging vehicle - please try again', 'error')
                end)
            end
        end,
        3 -- Retry up to 3 times
    )
end)

-- Enhanced flagged vehicle check callback with error handling
QBCore.Functions.CreateCallback('qb-hackerjob:server:isVehicleFlagged', function(source, cb, plate)
    -- Validate inputs
    if not source or type(source) ~= 'number' then
        SafeLogError('Invalid source in isVehicleFlagged callback', source)
        if cb then cb(false) end
        return
    end
    
    if not cb or type(cb) ~= 'function' then
        SafeLogError('Invalid callback in isVehicleFlagged', source)
        return
    end
    
    if not plate or type(plate) ~= 'string' or plate == '' then
        SafeLogError('Invalid plate in isVehicleFlagged', source)
        cb(false)
        return
    end
    
    -- Safe plate validation
    local plateValidationSuccess, validatedPlate = pcall(function()
        return plate:gsub("%s+", ""):upper()
    end)
    
    if not plateValidationSuccess or not validatedPlate or validatedPlate == '' then
        SafeLogError('Plate validation failed in isVehicleFlagged', source)
        cb(false)
        return
    end
    
    plate = validatedPlate
    
    -- Safe database query
    local queryStartTime = GetGameTimer()
    SafeQuery(
        'SELECT reason FROM hackerjob_flagged_vehicles WHERE plate = ? LIMIT 1',
        {plate},
        function(result)
            local queryTime = GetGameTimer() - queryStartTime
            
            if queryTime > 25 then
                SafeLogError('Slow flagged vehicle check: ' .. queryTime .. 'ms for plate ' .. plate)
            end
            
            if result and #result > 0 and result[1].reason then
                SafeLogDebug('Vehicle is flagged: ' .. plate)
                cb(true, result[1].reason)
            else
                SafeLogDebug('Vehicle not flagged: ' .. plate)
                cb(false)
            end
        end,
        2 -- Retry up to 2 times for flag checks
    )
end)

-- Update query performance stats
local function updateQueryStats(queryTime)
    performanceStats.totalQueries = performanceStats.totalQueries + 1
    if queryTime > 50 then
        performanceStats.slowQueries = performanceStats.slowQueries + 1
    end
    
    -- Calculate rolling average
    performanceStats.averageQueryTime = 
        (performanceStats.averageQueryTime * (performanceStats.totalQueries - 1) + queryTime) / performanceStats.totalQueries
end

-- Performance monitoring command (Admin only)
QBCore.Commands.Add('hackerperf', 'Show hacker job performance statistics (Admin Only)', {}, true, function(source, args)
    local src = source
    local AdminPlayer = QBCore.Functions.GetPlayer(src)
    
    if not AdminPlayer or not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    local cacheEntries = 0
    for _ in pairs(vehicleCache) do
        cacheEntries = cacheEntries + 1
    end
    
    local uptimeHours = (os.time() - performanceStats.lastResetTime) / 3600
    local cacheHitRatio = performanceStats.totalQueries > 0 and 
        (performanceStats.cacheHits / (performanceStats.cacheHits + performanceStats.cacheMisses) * 100) or 0
    
    print(string.format("^2[qb-hackerjob] ^7========== PERFORMANCE STATISTICS =========="))
    print(string.format("^2[qb-hackerjob] ^7Uptime: %.1f hours", uptimeHours))
    print(string.format("^2[qb-hackerjob] ^7Total DB Queries: %d", performanceStats.totalQueries))
    print(string.format("^2[qb-hackerjob] ^7Slow Queries (>50ms): %d (%.1f%%)", 
        performanceStats.slowQueries, 
        performanceStats.totalQueries > 0 and (performanceStats.slowQueries / performanceStats.totalQueries * 100) or 0))
    print(string.format("^2[qb-hackerjob] ^7Average Query Time: %.1fms", performanceStats.averageQueryTime))
    print(string.format("^2[qb-hackerjob] ^7Cache Entries: %d", cacheEntries))
    print(string.format("^2[qb-hackerjob] ^7Cache Hit Ratio: %.1f%%", cacheHitRatio))
    print(string.format("^2[qb-hackerjob] ^7Est. Memory Usage: ~%.2fMB", (cacheEntries * 0.5) / 1024))
    print(string.format("^2[qb-hackerjob] ^7==============================================="))
    
    TriggerClientEvent('QBCore:Notify', src, 'Performance stats displayed in console', 'success')
end, 'admin')

-- Export the GenerateVIN function for other resources
exports('GenerateVIN', GenerateVIN) 