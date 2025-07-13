local QBCore = exports['qb-core']:GetCoreObject()

-- Callback for getting a player by phone number
QBCore.Functions.CreateCallback('qb-hackerjob:server:getPlayerByPhone', function(source, cb, phone)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    -- Check for hacker job if required
    if Config.RequireJob and Player.PlayerData.job.name ~= Config.HackerJobName then
        cb({ success = false, message = "Unauthorized access" })
        return
    end
    
    -- In a real implementation, this would search the database for the phone number
    -- and return the player data if found
    
    -- For now, this is a stub that returns simulated data
    -- You would typically query the database to find the player with this phone number
    
    -- This is a placeholder for the real implementation
    -- Simulating a 60% chance of finding a player
    local found = math.random(100) <= 60
    
    if found then
        -- Simulate finding a random online player
        local players = QBCore.Functions.GetPlayers()
        
        if #players <= 1 then
            -- Only the current player is online, simulate a not found
            cb({ success = false, message = "No player found with that phone number" })
            return
        end
        
        -- Get a random player that is not the source
        local targetId
        repeat
            targetId = players[math.random(#players)]
        until tonumber(targetId) ~= src
        
        local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
        
        if TargetPlayer then
            local targetData = {
                name = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname,
                source = targetId,
                cid = TargetPlayer.PlayerData.citizenid,
                isOnline = true
            }
            
            cb({ success = true, data = targetData })
        else
            cb({ success = false, message = "Player not found" })
        end
    else
        cb({ success = false, message = "No player found with that phone number" })
    end
end)

-- Event for alerting a player they are being tracked
RegisterNetEvent('qb-hackerjob:server:alertTracked')
AddEventHandler('qb-hackerjob:server:alertTracked', function(targetId)
    -- This would send a notification to the player being tracked
    -- only if the server has that feature enabled
    -- For now, this is just a stub
end)

-- Log tracking attempts for server admins
RegisterNetEvent('qb-hackerjob:server:logTracking')
AddEventHandler('qb-hackerjob:server:logTracking', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Log the tracking attempt to the server console and/or database
    -- This is important for anti-abuse monitoring
    print(string.format("[qb-hackerjob] Player %s (%s) attempted to track phone %s", 
        GetPlayerName(src), Player.PlayerData.citizenid, data.phone))
end) 