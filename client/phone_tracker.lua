local QBCore = exports['qb-core']:GetCoreObject()
local isTracking = false
local lastTrackTime = 0

-- Register NUI Callback for phone tracking
RegisterNUICallback('trackPhone', function(data, cb)
    local phone = data.phone
    
    if not phone then
        cb({success = false, message = "Invalid phone number"})
        return
    end
    
    local success = TrackPhoneNumber(phone, false)
    cb({success = success})
end)

-- Main function to track a phone number
function TrackPhoneNumber(phone, isCommand)
    local currentTime = GetGameTimer()
    
    -- Check for cooldown
    if (currentTime - lastTrackTime) < Config.PhoneTrackCooldown and not isCommand then
        local remainingTime = math.ceil((Config.PhoneTrackCooldown - (currentTime - lastTrackTime)) / 1000)
        QBCore.Functions.Notify(Lang:t('error.cooldown', {time = remainingTime}), "error")
        return false
    end
    
    -- Check if already tracking
    if isTracking then
        QBCore.Functions.Notify(Lang:t('info.processing_data'), "primary")
        return false
    end
    
    -- Make sure phone tracker is enabled
    if not Config.PhoneTrackerEnabled then
        QBCore.Functions.Notify(Lang:t('error.no_access'), "error")
        return false
    end
    
    isTracking = true
    lastTrackTime = currentTime
    
    -- Start tracking animation and UI feedback
    QBCore.Functions.Notify(Lang:t('info.triangulating_position'), "primary")
    
    -- Progress bar for tracking animation
    QBCore.Functions.Progressbar("phone_tracking", Lang:t('info.locating_target'), Config.PhoneTrackDuration, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@heists@prison_heiststation@cop_reactions",
        anim = "cop_b_idle",
        flags = 49,
    }, {}, {}, function() -- Done
        -- Note: This is a placeholder for the actual phone tracking functionality
        -- In a full implementation, this would call a server-side function to locate the player with that phone number
        
        -- For now, just simulate a random location
        local success = math.random(100) > 30 -- 70% success rate for testing
        
        if success then
            -- Simulate a random location
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Generate random offset coords (between 50-200 meters away)
            local offsetX = math.random(-200, 200)
            local offsetY = math.random(-200, 200)
            
            local trackData = {
                name = "Unknown", -- In a real implementation, this would be the player's name
                distance = math.sqrt(offsetX^2 + offsetY^2),
                coords = vector3(playerCoords.x + offsetX, playerCoords.y + offsetY, playerCoords.z),
                accuracy = Config.PhoneTrackAccuracy,
                lastActive = "Recently",
                signalStrength = math.random(30, 90)
            }
            
            -- Check for police notification chance
            if Config.AlertPolice.enabled and math.random(100) <= Config.AlertPolice.phoneTrackChance then
                TriggerServerEvent('police:server:policeAlert', 'Suspicious Electronic Activity')
            end
            
            -- Send data to NUI
            SendNUIMessage({
                action = "phoneTrackResult",
                success = true,
                data = trackData
            })
            
            QBCore.Functions.Notify(Lang:t('success.phone_tracked'), "success")
            
            -- Award XP and log success
            TriggerEvent('qb-hackerjob:client:handleHackSuccess', 'phoneTrack', phone, 'Successfully tracked phone')
            
            -- Return data for external use
            isTracking = false
            return true, trackData
        else
            -- Failed to track
            SendNUIMessage({
                action = "phoneTrackResult",
                success = false,
                message = "No signal found"
            })
            
            QBCore.Functions.Notify(Lang:t('error.no_signal'), "error")
            
            -- Log failure
            TriggerEvent('qb-hackerjob:client:handleHackFailure', 'phoneTrack', phone, 'Failed to track phone (no signal)')
            
            isTracking = false
            return false
        end
    end, function() -- Cancel
        isTracking = false
        QBCore.Functions.Notify(Lang:t('error.operation_failed'), "error")
        return false
    end)
    
    return true
end

-- Export function
exports('TrackPhoneNumber', TrackPhoneNumber)
