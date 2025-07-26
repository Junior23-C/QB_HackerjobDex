local QBCore = exports['qb-core']:GetCoreObject()
local lastLookupTime = 0
local isLookingUp = false
local nearbyVehicles = {}
local currentHackerStats = {} -- Cache stats locally
local isLaptopOpen = false -- Track laptop state

-- START ADDED HELPER FUNCTION --
local function CanUseLaptop()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player then return false end -- Player data not loaded?

    -- Check Job Requirements (if enabled)
    if Config.RequireJob and Player.job.name ~= Config.HackerJobName then
        -- Allow LEO access? Example check, adjust if needed:
        -- if Player.job.type ~= 'leo' then
        QBCore.Functions.Notify("You don't have the right job to use this.", "error")
        return false
        -- end
    end

    -- Check if player has the item (if configured for item usage)
    if Config.UsableItem then
        local hasItem = QBCore.Functions.HasItem(Config.LaptopItem)
        if not hasItem then
            QBCore.Functions.Notify("You don't have a hacker laptop.", "error")
            return false
        end
    end

    return true -- All checks passed
end
-- END ADDED HELPER FUNCTION --

-- Function to detect nearby vehicles
local function GetNearbyVehicles(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')
    local results = {}
    
    for _, vehicle in ipairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)
        
        if distance <= maxDistance then
            local plate = GetVehicleNumberPlateText(vehicle)
            if plate then
                plate = plate:gsub("%s+", "") -- Remove spaces
                
                table.insert(results, {
                    vehicle = vehicle,
                    plate = plate,
                    distance = distance,
                    coords = vehicleCoords,
                    model = GetEntityModel(vehicle),
                    class = GetVehicleClass(vehicle),
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)
    
    return results
end

-- Main function to look up a vehicle plate
function LookupVehiclePlate(plate, manual)
    local currentTime = GetGameTimer()
    
    -- Check cooldown
    if (currentTime - lastLookupTime) < Config.VehicleLookupCooldown and not manual then
        local remainingTime = math.ceil((Config.VehicleLookupCooldown - (currentTime - lastLookupTime)) / 1000)
        QBCore.Functions.Notify(Lang:t('error.cooldown', {time = remainingTime}), "error")
        return false
    end
    
    -- Check if already looking up
    if isLookingUp then
        QBCore.Functions.Notify(Lang:t('info.processing_data'), "primary")
        return false
    end
    
    isLookingUp = true
    lastLookupTime = currentTime
    
    -- Normalize plate
    plate = plate:gsub("%s+", ""):upper()
    
    -- Validate plate format
    if not plate or plate == '' or string.len(plate) < 2 or string.len(plate) > 8 then
        QBCore.Functions.Notify(Lang:t('error.invalid_plate'), "error")
        isLookingUp = false
        return false
    end
    
    -- Start lookup animation and UI feedback
    if not manual then
        QBCore.Functions.Notify(Lang:t('info.accessing_database'), "primary")
        
        -- Progress bar for hacking animation
        QBCore.Functions.Progressbar("plate_lookup", Lang:t('info.searching_db'), Config.DefaultLookupDuration, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "anim@heists@prison_heiststation@cop_reactions",
            anim = "cop_b_idle",
            flags = 49,
        }, {}, {}, function() -- Done
            PerformLookupQuery(plate)
        end, function() -- Cancel
            isLookingUp = false
            QBCore.Functions.Notify(Lang:t('error.operation_failed'), "error")
        end)
    else
        -- Skip animation for direct lookup from UI
        QBCore.Functions.Notify(Lang:t('info.processing_data'), "primary")
        Wait(500) -- Small delay for realism
        PerformLookupQuery(plate)
    end
    
    return true
end

-- Function to perform the actual lookup query to the server
function PerformLookupQuery(plate)
    print("^2[qb-hackerjob] ^7PerformLookupQuery called with plate: " .. tostring(plate))
    
    -- First, get the service price to show to the user
    if Config.Economy and Config.Economy.enabled then
        local targetData = {
            target = plate,
            isEmergency = false, -- Will be determined by server
            isStolen = false,
            isVIP = false
        }
        
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:getServicePrice', function(priceResult)
            if priceResult.success then
                local price = priceResult.price
                local marketMultiplier = priceResult.marketMultiplier or 1.0
                
                -- Show pricing info and get confirmation
                local marketText = ""
                if marketMultiplier > 1.1 then
                    marketText = " (High Demand: +" .. math.floor((marketMultiplier - 1) * 100) .. "%)"
                elseif marketMultiplier < 0.9 then
                    marketText = " (Low Demand: " .. math.floor((marketMultiplier - 1) * 100) .. "%)"
                end
                
                QBCore.Functions.Notify(string.format("Plate Lookup Service: $%d%s", price, marketText), "primary")
                
                -- Get user confirmation for payment
                local confirmDialog = exports['qb-input']:ShowInput({
                    header = "Confirm Plate Lookup",
                    submitText = "Pay & Lookup",
                    inputs = {
                        {
                            text = string.format("Service Cost: $%d%s", price, marketText),
                            name = "confirmation",
                            type = "text",
                            isRequired = false,
                            default = "Type 'confirm' to proceed"
                        }
                    }
                })
                
                if confirmDialog and confirmDialog.confirmation and confirmDialog.confirmation:lower() == "confirm" then
                    -- User confirmed, proceed with paid lookup
                    ActuallyPerformLookup(plate)
                else
                    -- User cancelled
                    isLookingUp = false
                    QBCore.Functions.Notify("Plate lookup cancelled", "error")
                end
            else
                -- Payment validation failed, show error
                isLookingUp = false
                QBCore.Functions.Notify("Service unavailable: " .. (priceResult.message or "Unknown error"), "error")
            end
        end, 'plateLookup', targetData)
    else
        -- Economy disabled, proceed with free lookup
        ActuallyPerformLookup(plate)
    end
end

-- Function to actually perform the lookup after payment confirmation
function ActuallyPerformLookup(plate)
    -- Start the minigame for plate lookup
    if Config.MiniGames and Config.MiniGames.enabled then
        QBCore.Functions.Notify("Starting database access challenge...", "primary")
        
        exports['qb-hackerjob']:StartMiniGame('plateLookup', function(success, score, tier)
            if success then
                -- Minigame completed successfully, proceed with lookup
                print("^2[qb-hackerjob] ^7Minigame completed with score: " .. score .. " (" .. tier .. ")")
                PerformActualLookupQuery(plate, score, tier)
            else
                -- Minigame failed
                isLookingUp = false
                QBCore.Functions.Notify("Database access failed - hacking attempt unsuccessful", "error")
            end
        end)
    else
        -- Minigames disabled, proceed directly
        PerformActualLookupQuery(plate, 0.6, "average")
    end
end

-- Function to perform the actual server query after minigame completion
function PerformActualLookupQuery(plate, performance, tier)
    -- Add timeout protection to prevent getting stuck
    local timeoutTimer = SetTimeout(15000, function() -- 15 second timeout
        if isLookingUp then
            print("^1[qb-hackerjob] ^7Plate lookup timeout for plate: " .. tostring(plate))
            isLookingUp = false
            QBCore.Functions.Notify("Database lookup timed out - please try again", "error")
        end
    end)
    
    print("^2[qb-hackerjob] ^7Triggering server callback for plate: " .. tostring(plate))
    
    -- Pass performance data to server for reward calculation
    local performanceData = {
        score = performance,
        tier = tier,
        timestamp = GetGameTimer()
    }
    
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:lookupPlate', function(result)
        print("^2[qb-hackerjob] ^7Received callback response for plate: " .. tostring(plate))
        
        -- Clear the timeout since we got a response
        ClearTimeout(timeoutTimer)
        isLookingUp = false
        
        if result and result.success then
            local vehicleData = result.data
            
            -- ### DEBUGGING: Log the data received from the server ###
            print(string.format("[qb-hackerjob] Received vehicle data from server for plate %s: Make=%s, Model=%s, Class=%s", 
                  tostring(plate), tostring(vehicleData.make), tostring(vehicleData.model), tostring(vehicleData.class)))
            -- ########################################################
            
            -- ### HYBRID APPROACH: Try to override with local client data if vehicle is nearby ###
            local nearbyVehicleEntity = GetVehicleByPlate(plate) -- Use existing function to find vehicle by plate
            
            if nearbyVehicleEntity and DoesEntityExist(nearbyVehicleEntity) then
                print("[qb-hackerjob] Vehicle found nearby. Overriding make/model/class with client-side info.")
                local modelHash = GetEntityModel(nearbyVehicleEntity)
                local classId = GetVehicleClass(nearbyVehicleEntity)
                local localVehicleInfo = GetVehicleInfo(modelHash) -- Use the client-side function
                local localClassName = Config.VehicleClasses[classId] or "Unknown"
                
                vehicleData.make = localVehicleInfo.make
                vehicleData.model = localVehicleInfo.model
                vehicleData.class = localClassName
                
                -- Optional: Log the overridden values
                print(string.format("[qb-hackerjob] Overridden data: Make=%s, Model=%s, Class=%s", 
                      tostring(vehicleData.make), tostring(vehicleData.model), tostring(vehicleData.class)))
            else
                 print("[qb-hackerjob] Vehicle not found nearby. Using server-provided make/model/class.")
            end
            -- ###################################################################################

            -- Display basic info notification
            local vehicleText = vehicleData.make .. " " .. vehicleData.model
            QBCore.Functions.Notify(Lang:t('success.vehicle_found') .. ": " .. vehicleText, "success")
            
            -- Check for police notification chance
            if Config.AlertPolice.enabled and math.random(100) <= Config.AlertPolice.lookupChance then
                TriggerServerEvent('police:server:policeAlert', 'Suspicious Hacking Activity')
            end
            
            -- Trigger laptop UI update with vehicle data
            SendNUIMessage({
                action = "updateVehicleData",
                data = vehicleData
            })
            
            -- Award XP and log activity
            exports['QB_HackerjobDex']:AwardXP('plateLookup')
            TriggerServerEvent('qb-hackerjob:server:logActivity', 'plateLookup', plate, true, 'Successfully looked up vehicle')
            
            -- Return data for external use
            return vehicleData
        else
            -- Handle error
            print("^1[qb-hackerjob] ^7Plate lookup failed for plate: " .. tostring(plate) .. " - " .. tostring(result and result.message or "Unknown error"))
            QBCore.Functions.Notify(result and result.message or Lang:t('error.vehicle_not_found'), "error")
            
            -- Log failure
            TriggerServerEvent('qb-hackerjob:server:logActivity', 'plateLookup', plate, false, result and result.message or 'Vehicle not found')
            
            return nil
        end
    end, plate, performanceData)
end

-- Function to display nearby vehicle list in the laptop UI
function DisplayNearbyVehicles()
    -- ### DISABLED NEARBY VEHICLES ###
    print("[qb-hackerjob] Nearby vehicle scan disabled.")
    nearbyVehicles = {}
    -- Send empty list to UI to clear it if necessary
    SendNUIMessage({
        action = "updateNearbyVehicles",
        vehicles = {}
    })
    return {}
    -- #############################

    --[[ -- Original Code Below --
    nearbyVehicles = GetNearbyVehicles(Config.VehicleDetection.maxDistance)
    
    -- Limit to max results for UI
    if #nearbyVehicles > Config.VehicleDetection.maxResultsOnScreen then
        for i = Config.VehicleDetection.maxResultsOnScreen + 1, #nearbyVehicles do
            nearbyVehicles[i] = nil
        end
    end
    
    local vehicleList = {}
    for _, v in ipairs(nearbyVehicles) do
        local vehicleClass = Config.VehicleClasses[v.class] or "Unknown"
        local vehicleInfo = GetVehicleInfo(v.model)
        
        table.insert(vehicleList, {
            plate = v.plate,
            distance = math.floor(v.distance),
            make = vehicleInfo.make,
            model = vehicleInfo.model,
            class = vehicleClass
        })
    end
    
    -- Send to laptop UI
    SendNUIMessage({
        action = "updateNearbyVehicles",
        vehicles = vehicleList
    })
    
    return vehicleList
    ]]
end

-- Function to manually lookup a specific vehicle from list
function LookupVehicleByIndex(index)
    print("^2[qb-hackerjob] ^7Attempting to lookup vehicle at index: " .. tostring(index))
    
    if not nearbyVehicles or #nearbyVehicles == 0 then
        print("^1[qb-hackerjob] ^7No nearby vehicles found")
        QBCore.Functions.Notify(Lang:t('error.no_vehicle'), "error")
        return false
    end
    
    -- Log all nearby vehicles for debugging
    print("^3[qb-hackerjob] ^7Total nearby vehicles: " .. #nearbyVehicles)
    for i, v in ipairs(nearbyVehicles) do
        print("^3[qb-hackerjob] ^7Vehicle " .. i .. ": " .. v.plate .. " - " .. GetDisplayNameFromVehicleModel(v.model))
    end
    
    index = tonumber(index)
    if not index then
        print("^1[qb-hackerjob] ^7Invalid index: not a number")
        QBCore.Functions.Notify(Lang:t('error.no_vehicle'), "error")
        return false
    end
    
    -- Array indices in Lua start at 1, but JavaScript starts at 0
    -- Check if the index is using JavaScript convention (0-based) and adjust if needed
    index = index + 1
    
    if not nearbyVehicles[index] then
        print("^1[qb-hackerjob] ^7Vehicle at index " .. tostring(index) .. " does not exist, total vehicles: " .. #nearbyVehicles)
        QBCore.Functions.Notify(Lang:t('error.no_vehicle'), "error")
        return false
    end
    
    print("^2[qb-hackerjob] ^7Found vehicle with plate: " .. nearbyVehicles[index].plate)
    return LookupVehiclePlate(nearbyVehicles[index].plate, true)
end

-- Function to get vehicle information from the hash (used by UI)
function GetVehicleInfo(modelHash)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    
    -- Check if it's in our config first
    if Config.VehicleModelInfo[modelHash] then
        print("^2[qb-hackerjob] ^7Found vehicle in Config.VehicleModelInfo: " .. modelHash)
        return Config.VehicleModelInfo[modelHash]
    end
    
    -- Check QBCore shared vehicles
    if QBCore.Shared.Vehicles then
        for model, data in pairs(QBCore.Shared.Vehicles) do
            if tonumber(data.hash) == modelHash or GetHashKey(model) == modelHash then
                print("^2[qb-hackerjob] ^7Found vehicle in QBCore.Shared.Vehicles: " .. model)
                return {
                    make = data.brand or "Unknown Brand",
                    model = data.name or model
                }
            end
        end
    end
    
    -- Try to get name from game directly
    if modelName and modelName ~= "CARNOTFOUND" and modelName ~= "" then
        print("^2[qb-hackerjob] ^7Using game model name: " .. modelName)
        -- Try to split into make and model (e.g., ADDER -> Truffade Adder)
        return {
            make = "Los Santos",
            model = string.upper(modelName:sub(1,1)) .. modelName:sub(2):lower() -- Capitalize first letter
        }
    end
    
    -- Absolute fallback
    print("^1[qb-hackerjob] ^7Could not find vehicle info for hash: " .. modelHash)
    return {
        make = "Unknown",
        model = "Vehicle"
    }
end

-- Export functions for external resources
exports('LookupVehiclePlate', LookupVehiclePlate)
exports('DisplayNearbyVehicles', DisplayNearbyVehicles)
exports('LookupVehicleByIndex', LookupVehicleByIndex)

-- Register command to lookup plate
RegisterCommand('lookupplate', function(source, args, rawCommand)
    if args[1] then
        LookupVehiclePlate(args[1], false)
    else
        QBCore.Functions.Notify(Lang:t('error.invalid_input'), "error")
    end
end, false)

-- NUI Callbacks for laptop interface
RegisterNUICallback('lookupPlate', function(data, cb)
    print("^2[qb-hackerjob] ^7NUI Callback: lookupPlate with plate " .. tostring(data.plate))
    local success = LookupVehiclePlate(data.plate, true)
    cb({success = success})
end)

RegisterNUICallback('getNearbyVehicles', function(data, cb)
    -- ### DISABLED NEARBY VEHICLES ###
    print("[qb-hackerjob] NUI Callback: getNearbyVehicles (DISABLED)")
    cb({success = true, vehicles = {}})
    -- #############################

    --[[ -- Original Code Below --
    print("^2[qb-hackerjob] ^7NUI Callback: getNearbyVehicles")
    local vehicles = DisplayNearbyVehicles()
    cb({success = true, vehicles = vehicles})
    ]]
end)

RegisterNUICallback('lookupVehicleByIndex', function(data, cb)
    print("^2[qb-hackerjob] ^7NUI Callback: lookupVehicleByIndex with index " .. tostring(data.index))
    local success = LookupVehicleByIndex(data.index)
    cb({success = success})
end)

-- Event for flagging vehicles
RegisterNetEvent('qb-hackerjob:client:flagVehicle')
AddEventHandler('qb-hackerjob:client:flagVehicle', function(plate, reason)
    TriggerServerEvent('qb-hackerjob:server:flagVehicle', plate, reason)
end)

-- Register NUI callback for vehicle actions
-- Note: performVehicleAction callback moved to laptop.lua to handle battery drain

-- Function to find a vehicle by its plate
function GetVehicleByPlate(plate)
    -- Normalize the plate (remove spaces, uppercase)
    plate = plate:gsub("%s+", ""):upper()
    
    -- First check nearby vehicles (which should already be cached)
    for _, v in ipairs(nearbyVehicles) do
        if v.plate == plate then
            return v.vehicle
        end
    end
    
    -- If not found in cache, do a wider search
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(vehicle):gsub("%s+", ""):upper()
        if vehPlate == plate then
            return vehicle
        end
    end
    
    return nil
end

-- Register NUI callback for vehicle tracking
RegisterNUICallback('trackVehicle', function(data, cb)
    print("^2[qb-hackerjob] ^7NUI Callback: trackVehicle with plate " .. tostring(data.plate))
    
    -- Check if tracking is enabled
    if not Config.VehicleTracking.enabled then
        QBCore.Functions.Notify("Vehicle tracking is not enabled", "error")
        cb({success = false})
        return
    end
    
    -- Normalize plate
    local normalizedPlate = data.plate:gsub("%s+", ""):upper()
    
    -- Find the vehicle
    local vehicles = GetGamePool('CVehicle')
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local foundVehicle = nil
    
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
        QBCore.Functions.Notify("Cannot find vehicle with plate " .. data.plate .. " nearby", "error")
        cb({success = false})
        return
    end
    
    -- Check if player has GPS tracker and remove it
    QBCore.Functions.TriggerCallback('qb-hackerjob:server:checkAndRemoveGPS', function(hasGPS)
        if hasGPS then
            -- Create a blip for the vehicle
            local blip = AddBlipForEntity(foundVehicle)
            
            -- If entity blip failed, try coordinate blip
            if not blip or blip == 0 then
                local coords = GetEntityCoords(foundVehicle)
                blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            end
            
            if blip and blip ~= 0 then
                -- Configure the blip
                SetBlipSprite(blip, Config.VehicleTracking.blipSprite)
                SetBlipColour(blip, Config.VehicleTracking.blipColor)
                SetBlipScale(blip, Config.VehicleTracking.blipScale)
                SetBlipAsShortRange(blip, false)
                SetBlipAlpha(blip, Config.VehicleTracking.blipAlpha)
                
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Tracked Vehicle: " .. normalizedPlate)
                EndTextCommandSetBlipName(blip)
                
                -- Flash the blip
                SetBlipFlashes(blip, true)
                
                -- Store tracking data (using TrackVehicle function)
                exports["qb-hackerjob"]:TrackVehicle(foundVehicle, normalizedPlate)
                
                -- Notify vehicle owner
                TriggerServerEvent('qb-hackerjob:server:notifyVehicleOwner', normalizedPlate)
                
                QBCore.Functions.Notify("Vehicle tracking activated", "success")
                
                -- Award XP for successful tracking (handled in vehicle_tracker.lua now)
                -- HandleHackSuccess('vehicleTrack', normalizedPlate, 'Successfully initiated tracking')
            else
                QBCore.Functions.Notify("Failed to establish GPS connection", "error")
                -- Log failure (handled in vehicle_tracker.lua now)
                -- HandleHackFailure('vehicleTrack', normalizedPlate, 'Failed to create blip')
            end
        end
    end)
    
    -- Return success immediately for UI
    cb({success = true})
end)

-- Function to open the laptop UI
local function OpenLaptopUI()
    -- ... existing logic to check job, conditions, etc. ...

    SetNuiFocus(true, true)
    isLaptopOpen = true -- Set flag

    -- Send the most recently known stats to the UI immediately upon opening
    if currentHackerStats and currentHackerStats.level then
         SendNUIMessage({
            action = 'updateHackerStats',
            level = tonumber(currentHackerStats.level) or 1,
            xp = tonumber(currentHackerStats.xp) or 0,
            nextLevelXP = tonumber(currentHackerStats.nextLevelXP) or 100,
            levelName = tostring(currentHackerStats.levelName) or "Unknown Rank"
        })
    else
        -- If stats are empty, maybe send defaults or wait for server update
        SendNUIMessage({
            action = 'updateHackerStats',
            level = 1, xp = 0, nextLevelXP = Config.LevelThresholds[2] or 100, levelName = Config.LevelNames[1] or "Script Kiddie"
        })
        -- Optional: Request stats from server if needed (uncomment if server doesn't send on load)
        -- TriggerServerEvent('qb-hackerjob:server:requestInitialStats')
    end

    SendNUIMessage({ action = 'openLaptop' }) -- Send the open action *after* stats
end

-- Function to close the laptop UI
local function CloseLaptopUI()
    SetNuiFocus(false, false)
    isLaptopOpen = false -- Clear flag
    SendNUIMessage({ action = 'closeLaptop' })
end

-- Assuming you have NUI callbacks for opening/closing apps or the main laptop
RegisterNUICallback('closeLaptop', function(data, cb)
    CloseLaptopUI()
    cb('ok')
end)

-- Integrate OpenLaptopUI and CloseLaptopUI into your existing laptop activation logic
-- Example: Using the item
RegisterNetEvent('qb-hackerjob:client:useLaptop', function()
    if not CanUseLaptop() then return end

    -- Check if player has the item (if configured) - MOVED INSIDE CanUseLaptop
    -- if Config.UsableItem then
    --    local hasItem = QBCore.Functions.HasItem(Config.LaptopItem)
    --    if not hasItem then
    --       QBCore.Functions.Notify("You don't have a hacker laptop.", "error")
    --       return
    --    end
    -- end

    if not isLaptopOpen then
        OpenLaptopUI()
    end
end)

-- Example: Using the command (if Config.UsableItem is false)
if not Config.UsableItem then
    RegisterCommand(Config.LaptopCommand, function()
        -- Use the helper function (item check is skipped internally if UsableItem is false)
        if not CanUseLaptop() then return end
        
        -- No item check needed for command usage - Handled by CanUseLaptop

        if not isLaptopOpen then
            OpenLaptopUI()
        end
    end, false) -- false means it's not restricted command
end
