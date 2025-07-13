local QBCore = exports['qb-core']:GetCoreObject()

-- Create item if it doesn't exist
Citizen.CreateThread(function()
    Citizen.Wait(5000) -- Wait for everything to initialize
    
    -- Debug print of item structure
    print('^3[qb-hackerjob] DEBUG: QBCore.Shared.Items is type: ^7' .. type(QBCore.Shared.Items))
    print('^3[qb-hackerjob] DEBUG: Trying to access ' .. Config.LaptopItem)
    
    -- Check if laptop item exists in QBCore items
    if QBCore.Shared.Items and not QBCore.Shared.Items[Config.LaptopItem] then
        print('^1[qb-hackerjob] Item lookup failed. Adding item programmatically...^7')
        
        -- Add the item programmatically
        QBCore.Functions.AddItem(Config.LaptopItem, {
            name = Config.LaptopItem,
            label = 'Hacking Laptop',
            weight = 2000,
            type = 'item',
            image = 'hacker_laptop.png',
            unique = true,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A specialized laptop for various hacking operations'
        })
        
        print('^2[qb-hackerjob] Added ' .. Config.LaptopItem .. ' item programmatically^7')
    else
        print('^2[qb-hackerjob] Successfully accessed ' .. Config.LaptopItem .. ' item^7')
    end
    
    -- Check if battery item exists
    if Config.Battery.enabled and QBCore.Shared.Items and not QBCore.Shared.Items[Config.Battery.batteryItemName] then
        -- Add the battery item programmatically
        QBCore.Functions.AddItem(Config.Battery.batteryItemName, {
            name = Config.Battery.batteryItemName,
            label = 'Laptop Battery',
            weight = 500,
            type = 'item',
            image = 'laptop_battery.png',
            unique = false,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A replacement battery for the hacking laptop'
        })
        
        print('^2[qb-hackerjob] Added ' .. Config.Battery.batteryItemName .. ' item programmatically^7')
    end
    
    -- Check if charger item exists
    if Config.Battery.enabled and QBCore.Shared.Items and not QBCore.Shared.Items[Config.Battery.chargerItemName] then
        -- Add the charger item programmatically
        QBCore.Functions.AddItem(Config.Battery.chargerItemName, {
            name = Config.Battery.chargerItemName,
            label = 'Laptop Charger',
            weight = 300,
            type = 'item',
            image = 'laptop_charger.png',
            unique = false,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = 'A charger for the hacking laptop'
        })
        
        print('^2[qb-hackerjob] Added ' .. Config.Battery.chargerItemName .. ' item programmatically^7')
    end
    
    -- Check if job exists
    if QBCore.Shared.Jobs and not QBCore.Shared.Jobs[Config.HackerJobName] then
        print('^1[qb-hackerjob] Job lookup failed. Adding job programmatically...^7')
        
        -- Add the job programmatically
        QBCore.Functions.AddJob(Config.HackerJobName, {
            label = 'Hacker',
            defaultDuty = true,
            offDutyPay = false,
            grades = {
                ['0'] = {
                    name = 'Script Kiddie',
                    payment = 50
                },
                ['1'] = {
                    name = 'Coder',
                    payment = 75
                },
                ['2'] = {
                    name = 'Security Analyst',
                    payment = 100
                },
                ['3'] = {
                    name = 'Elite Hacker',
                    payment = 125
                },
                ['4'] = {
                    name = 'Boss',
                    isboss = true,
                    payment = 150
                }
            }
        })
        
        print('^2[qb-hackerjob] Added ' .. Config.HackerJobName .. ' job programmatically^7')
    else
        print('^2[qb-hackerjob] Successfully accessed ' .. Config.HackerJobName .. ' job^7')
    end
    
    -- Make the item usable on the server side
    QBCore.Functions.CreateUseableItem(Config.LaptopItem, function(source)
        print('^2[qb-hackerjob] ^7Server: Player ' .. source .. ' used laptop item')
        TriggerClientEvent('qb-hackerjob:client:openLaptop', source)
    end)
    
    -- Make battery item usable
    QBCore.Functions.CreateUseableItem(Config.Battery.batteryItemName, function(source)
        print('^2[qb-hackerjob] ^7Server: Player ' .. source .. ' used battery item')
        TriggerClientEvent('qb-hackerjob:client:replaceBattery', source)
    end)
    
    -- Make charger item usable
    QBCore.Functions.CreateUseableItem(Config.Battery.chargerItemName, function(source)
        print('^2[qb-hackerjob] ^7Server: Player ' .. source .. ' used charger item')
        TriggerClientEvent('qb-hackerjob:client:toggleCharger', source)
    end)
end)

-- Handle item use directly
RegisterServerEvent('qb-hackerjob:server:useItem')
AddEventHandler('qb-hackerjob:server:useItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and Player.Functions.GetItemByName(Config.LaptopItem) then
        TriggerClientEvent('qb-hackerjob:client:openLaptop', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have a hacking laptop", "error")
    end
end)

-- Register server callback for job check
QBCore.Functions.CreateCallback('qb-hackerjob:server:hasHackerJob', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        cb(false)
        return
    end
    
    if not Config.RequireJob then
        cb(true)
        return
    end
    
    if Player.PlayerData.job.name == Config.HackerJobName then
        if Config.JobRank > 0 then
            cb(Player.PlayerData.job.grade.level >= Config.JobRank)
        else
            cb(true)
        end
        return
    end
    
    cb(false)
end)

-- Command to give hacker laptop
QBCore.Commands.Add('givehackerlaptop', 'Give a hacker laptop to a player (Admin Only)', {
    {name = 'id', help = 'Player ID'}
}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    
    if Player then
        Player.Functions.AddItem(Config.LaptopItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[Config.LaptopItem], 'add')
        TriggerClientEvent('QBCore:Notify', src, 'You gave a hacker laptop to ' .. Player.PlayerData.charinfo.firstname, 'success')
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You received a hacker laptop', 'success')
        print('^2[qb-hackerjob] ^7Admin gave hacker laptop to player ID ' .. args[1])
    else
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    end
end, 'admin')

-- Command to set job to hacker
QBCore.Commands.Add('makehacker', 'Set player job to hacker (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'grade', help = 'Job Grade (0-4)'}
}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local grade = tonumber(args[2]) or 0
    
    if grade < 0 or grade > 4 then grade = 0 end
    
    if Player then
        Player.Functions.SetJob(Config.HackerJobName, grade)
        TriggerClientEvent('QBCore:Notify', src, 'You set ' .. Player.PlayerData.charinfo.firstname .. ' as a hacker (grade ' .. grade .. ')', 'success')
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You are now a hacker (grade ' .. grade .. ')', 'success')
        print('^2[qb-hackerjob] ^7Admin set player ID ' .. args[1] .. ' to hacker job, grade ' .. grade)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    end
end, 'admin')

-- Debug log function
function DebugLog(msg)
    if GetConvar('qb_debug', 'false') == 'true' then
        print('^3[qb-hackerjob] DEBUG: ^7' .. msg)
    end
end

-- Export debug function
exports('DebugLog', DebugLog)

-- Event to notify vehicle owner/driver
RegisterServerEvent('qb-hackerjob:server:notifyDriver')
AddEventHandler('qb-hackerjob:server:notifyDriver', function(plate, message)
    local src = source
    
    -- Normalize plate
    plate = plate:gsub("%s+", ""):upper()
    
    -- Debug log
    print("^3[qb-hackerjob] ^7Notifying driver of vehicle with plate: " .. plate .. " - Message: " .. message)
    
    -- Find all players in vehicles
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local targetPlayer = QBCore.Functions.GetPlayer(playerId)
        
        if targetPlayer then
            -- Send the notification to check if they're in this vehicle
            TriggerClientEvent('qb-hackerjob:client:checkVehiclePlate', playerId, plate, message)
        end
    end
    
    -- Also check database to see if specific player owns this car
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            local ownerId = result[1].citizenid
            
            -- Find the owner if they're online
            for _, playerId in ipairs(players) do
                local targetPlayer = QBCore.Functions.GetPlayer(playerId)
                
                if targetPlayer and targetPlayer.PlayerData.citizenid == ownerId then
                    -- Notify the owner even if not in the vehicle
                    TriggerClientEvent('QBCore:Notify', playerId, "Your vehicle with plate " .. plate .. " has been tampered with!", "error", 10000)
                    break
                end
            end
        end
    end)
end)

-- Callback to check if player can buy the laptop
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyLaptop', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.Vendor.price
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-hacker-laptop")
        
        -- Add laptop item
        Player.Functions.AddItem(Config.LaptopItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.LaptopItem], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- Callback to check if player can buy a battery
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyBattery', function(source, cb)
    if not Config.Battery.enabled then
        cb(false)
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.Battery.batteryItemPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-laptop-battery")
        
        -- Add battery item
        Player.Functions.AddItem(Config.Battery.batteryItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.batteryItemName], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- Callback to check if player can buy a charger
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyCharger', function(source, cb)
    if not Config.Battery.enabled then
        cb(false)
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.Battery.chargerItemPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-laptop-charger")
        
        -- Add charger item
        Player.Functions.AddItem(Config.Battery.chargerItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.chargerItemName], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- Server callback to check if player has an item
QBCore.Functions.CreateCallback('qb-hackerjob:server:hasItem', function(source, cb, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print("^1[qb-hackerjob] ^7hasItem callback: Player not found")
        cb(false)
        return
    end
    
    local item = Player.Functions.GetItemByName(itemName)
    if item and item.amount > 0 then
        print("^2[qb-hackerjob] ^7hasItem callback: Player has " .. item.amount .. " " .. itemName)
        cb(true)
    else
        print("^1[qb-hackerjob] ^7hasItem callback: Player does not have " .. itemName)
        cb(false)
    end
end)

-- Server event to remove an item (used for battery replacement)
RegisterServerEvent('qb-hackerjob:server:removeItem')
AddEventHandler('qb-hackerjob:server:removeItem', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print("^1[qb-hackerjob] ^7removeItem: Player not found")
        return 
    end
    
    -- Make sure player actually has the item
    local hasItem = Player.Functions.GetItemByName(itemName)
    if not hasItem or hasItem.amount < amount then
        print("^1[qb-hackerjob] ^7removeItem: Player doesn't have enough " .. itemName .. " (has: " .. (hasItem and hasItem.amount or 0) .. ", needs: " .. amount .. ")")
        TriggerClientEvent('QBCore:Notify', src, "You don't have this item!", "error")
        return
    end
    
    print("^2[qb-hackerjob] ^7removeItem: Removing " .. amount .. " " .. itemName .. " from player " .. src)
    
    -- Remove the item
    Player.Functions.RemoveItem(itemName, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    
    print("^2[qb-hackerjob] ^7removeItem: Successfully removed item")
end)

-- Database setup for hacker progression system
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for database connection
    
    -- Create hacker_skills table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_skills` (
            `citizenid` varchar(50) NOT NULL,
            `xp` int(11) NOT NULL DEFAULT 0,
            `level` int(11) NOT NULL DEFAULT 1,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Create hacker_logs table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `activity` varchar(100) NOT NULL,
            `target` varchar(100) DEFAULT NULL,
            `success` tinyint(1) NOT NULL DEFAULT 0,
            `details` text DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('^2[qb-hackerjob] ^7Database tables initialized successfully')
end)

-- Get player hacker level
QBCore.Functions.CreateCallback('qb-hackerjob:server:getHackerLevel', function(source, cb)
    if not Config.XPEnabled then
        cb(5, 1000, 1000) -- Return max level if XP system is disabled
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        print("^1[qb-hackerjob:getHackerLevel] Player not found for source: " .. tostring(source))
        cb(1, 0, 100)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local xp = tonumber(result[1].xp) or 0
            local level = tonumber(result[1].level) or 1
            
            -- Calculate max XP for the current level
            local nextLevelThreshold = Config.LevelThresholds[level + 1] or Config.LevelThresholds[5] or 1000
            local currentLevelThreshold = Config.LevelThresholds[level] or 0
            local xpForNextLevel = nextLevelThreshold - currentLevelThreshold
            
            print(string.format("^2[qb-hackerjob:getHackerLevel] Retrieved stats for %s: Level=%d, XP=%d, NextXP=%d", citizenid, level, xp, xpForNextLevel))
            cb(level, xp, xpForNextLevel)
        else
            -- Create new entry for player if doesn't exist
            print(string.format("^3[qb-hackerjob:getHackerLevel] Creating new hacker profile for %s", citizenid))
            MySQL.insert('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, ?)', {
                citizenid, 0, 1
            }, function(insertId)
                if insertId then
                    print(string.format("^2[qb-hackerjob:getHackerLevel] Successfully created profile for %s", citizenid))
                else
                    print(string.format("^1[qb-hackerjob:getHackerLevel] Failed to create profile for %s", citizenid))
                end
            end)
            
            cb(1, 0, Config.LevelThresholds[2] or 100)
        end
    end)
end)

-- Check if player can use a feature based on their level
QBCore.Functions.CreateCallback('qb-hackerjob:server:canUseFeature', function(source, cb, feature)
    if not Config.XPEnabled then
        cb(true) -- Allow all features if XP system is disabled
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        cb(false)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local level = result[1].level
            
            -- Check if feature is in the unlocks for this level
            local featureUnlocked = false
            for _, availableFeature in ipairs(Config.LevelUnlocks[level]) do
                if availableFeature == feature then
                    featureUnlocked = true
                    break
                end
            end
            
            cb(featureUnlocked)
        else
            -- Create new entry for player if doesn't exist
            MySQL.insert('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, ?)', {
                citizenid, 0, 1
            })
            
            -- Check if feature is available at level 1
            local featureUnlocked = false
            for _, availableFeature in ipairs(Config.LevelUnlocks[1]) do
                if availableFeature == feature then
                    featureUnlocked = true
                    break
                end
            end
            
            cb(featureUnlocked)
        end
    end)
end)

-- Add XP to a player for successful hacking (Reverted Logic with Debugging)
RegisterServerEvent('qb-hackerjob:server:addXP')
AddEventHandler('qb-hackerjob:server:addXP', function(activity)
    if not Config.XPEnabled then
        print("^3[qb-hackerjob:addXP] XP system disabled.^7")
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        print("^1[qb-hackerjob:addXP] Player object not found for source: " .. tostring(src) .. "^7")
        return
    end

    -- Super detailed debugging for vehicle actions
    print("^1[qb-hackerjob:addXP] Activity received: " .. tostring(activity) .. "^7")
    print("^1[qb-hackerjob:addXP] Available XP types: ")
    for k, v in pairs(Config.XPSettings) do
        print("  - " .. k .. ": " .. v .. " XP")
    end
    
    -- For vehicle actions, they might be sending activity "engine" but config needs "vehicleControl"
    if activity == "engine" or activity == "lock" or activity == "unlock" or 
       activity == "disable_brakes" or activity == "accelerate" then
        print("^2[qb-hackerjob:addXP] Converting vehicle action " .. activity .. " to vehicleControl^7")
        activity = "vehicleControl"
    end

    local citizenid = Player.PlayerData.citizenid
    local xpToAdd = Config.XPSettings[activity] or 0

    if xpToAdd <= 0 then
        print(string.format("^3[qb-hackerjob:addXP] No XP configured or 0 XP for activity '%s'.^7", tostring(activity)))
        return
    end

    print(string.format("^2[qb-hackerjob:addXP] Attempting to add %d XP for activity '%s' to player %s.^7", xpToAdd, tostring(activity), citizenid))

    -- Step 1: Check if player exists and get current XP/Level
    MySQL.query('SELECT xp, level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        local currentXP = 0
        local currentLevel = 1
        local playerExists = (result and #result > 0)

        if playerExists then
            currentXP = result[1].xp
            currentLevel = result[1].level
            print(string.format("^3[qb-hackerjob:addXP] Player %s exists. Current XP: %d, Level: %d^7", citizenid, currentXP, currentLevel))
            -- Step 2a: Player exists, update their XP
            local newXP = currentXP + xpToAdd
            MySQL.update('UPDATE hacker_skills SET xp = ? WHERE citizenid = ?', {newXP, citizenid}, function(updateResult)
                print(string.format("^3[qb-hackerjob:addXP] UPDATE result for %s: affectedRows = %s^7", citizenid, tostring(updateResult)))
                if updateResult and updateResult > 0 then
                    print(string.format("^2[qb-hackerjob:addXP] Successfully updated XP for %s to %d.^7", citizenid, newXP))
                    CheckForLevelUp(src, citizenid, xpToAdd) -- Check for level up after successful update
                else
                    print(string.format("^1[qb-hackerjob:addXP] Failed to UPDATE XP for player %s.^7", citizenid))
                end
            end)
        else
            print(string.format("^3[qb-hackerjob:addXP] Player %s does not exist. Inserting new record.^7", citizenid))
            -- Step 2b: Player doesn't exist, insert new record
            MySQL.insert('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, 1)', {citizenid, xpToAdd}, function(insertResult)
                -- Check if insertResult is valid and has insertId or affectedRows
                 local success = false
                 if type(insertResult) == 'number' and insertResult > 0 then -- affectedRows for older oxmysql?
                     success = true
                 elseif type(insertResult) == 'table' and insertResult.insertId then -- insertId for newer oxmysql?
                     success = true
                 end
                 print(string.format("^3[qb-hackerjob:addXP] INSERT result for %s: %s^7", citizenid, json.encode(insertResult)))

                if success then
                    print(string.format("^2[qb-hackerjob:addXP] Successfully inserted new record for %s with %d XP.^7", citizenid, xpToAdd))
                    CheckForLevelUp(src, citizenid, xpToAdd) -- Check for level up after successful insert
                else
                    print(string.format("^1[qb-hackerjob:addXP] Failed to INSERT new record for player %s.^7", citizenid))
                end
            end)
        end
    end)
end)

-- Helper function to check for level up and notify client
function CheckForLevelUp(src, citizenid, xpAdded)
    print(string.format("^2[qb-hackerjob:CheckLevelUp] Checking level for %s after adding %d XP.^7", citizenid, xpAdded))
    MySQL.query('SELECT xp, level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local finalXP = result[1].xp
            local currentLevel = result[1].level -- Use currentLevel consistently
            print(string.format("^3[qb-hackerjob:CheckLevelUp] Fetched stats for %s: XP=%d, CurrentLevel=%d^7", citizenid, finalXP, currentLevel))

            -- Check for level up based on the FINAL XP total
            local newLevel = currentLevel
            local maxLevelDefined = 0
            for level, _ in pairs(Config.LevelThresholds) do
                if level > maxLevelDefined then maxLevelDefined = level end
            end

            -- Important: Check from current level UPWARDS
            for level = currentLevel + 1, maxLevelDefined do
                if Config.LevelThresholds[level] and finalXP >= Config.LevelThresholds[level] then
                    newLevel = level -- Keep updating if they cross multiple thresholds
                else
                    break -- Stop checking once a threshold isn't met
                end
            end
             -- Ensure level doesn't exceed the max defined level name
            local maxLevelName = 0
            for level, _ in pairs(Config.LevelNames) do
                if level > maxLevelName then maxLevelName = level end
            end
            if newLevel > maxLevelName then
                newLevel = maxLevelName
            end

            print(string.format("^3[qb-hackerjob:CheckLevelUp] Level check for %s: CurrentLevel=%d, Calculated NewLevel=%d^7", citizenid, currentLevel, newLevel))

            -- Calculate necessary info for client update *before* potential level update query
            local levelName = Config.LevelNames[newLevel] or "Unknown Rank"
            local nextLevelXPThreshold = Config.LevelThresholds[newLevel + 1] or Config.LevelThresholds[#Config.LevelThresholds] -- Use max level threshold if next doesn't exist
            local currentLevelXPThreshold = Config.LevelThresholds[newLevel] or 0
            local xpForNextLevel = nextLevelXPThreshold - currentLevelXPThreshold

            -- Always trigger client stats update
            print(string.format("^2[qb-hackerjob:CheckLevelUp] Triggering client stats update for %s: Level=%d, XP=%d, NextXP=%d, Name=%s^7", citizenid, newLevel, finalXP, xpForNextLevel, levelName))
            TriggerClientEvent('qb-hackerjob:client:updateStats', src, {
                level = newLevel,
                xp = finalXP,
                nextLevelXP = xpForNextLevel,
                levelName = levelName
            })

            -- If a level up occurred, update the level in the database
            if newLevel > currentLevel then
                print(string.format("^2[qb-hackerjob:CheckLevelUp] Level up detected for %s! Updating level from %d to %d.^7", citizenid, currentLevel, newLevel))
                MySQL.update('UPDATE hacker_skills SET level = ? WHERE citizenid = ?', {newLevel, citizenid}, function(updateResult)
                    print(string.format("^3[qb-hackerjob:CheckLevelUp] Level update result for %s: affectedRows = %s^7", citizenid, tostring(updateResult)))
                    if updateResult and updateResult > 0 then
                        -- Notify player about XP gain AND level up (Notifications handled separately now)
                        TriggerClientEvent('QBCore:Notify', src, "Hacking XP: +" .. xpAdded, "success")
                        TriggerClientEvent('QBCore:Notify', src, "Level Up! You are now a " .. levelName, "success")
                        -- TriggerClientEvent('qb-hackerjob:client:levelUp', src, newLevel, levelName) -- client:updateStats handles UI refresh now
                    else
                        -- Level update failed, log error, but still notify about XP
                        print(string.format("^1[qb-hackerjob:CheckLevelUp] Failed to update level for player %s after XP gain. Update query affected %s rows.^7", citizenid, tostring(updateResult)))
                        TriggerClientEvent('QBCore:Notify', src, "Hacking XP: +" .. xpAdded, "success") -- Still notify XP gain
                    end
                end)
            else
                -- No level up, just notify about XP gain
                print(string.format("^2[qb-hackerjob:CheckLevelUp] No level up for %s. Notifying XP gain only.^7", citizenid))
                TriggerClientEvent('QBCore:Notify', src, "Hacking XP: +" .. xpAdded, "success")
            end
        else
            -- Failed to fetch data for level up check
            print(string.format("^1[qb-hackerjob:CheckLevelUp] Failed to fetch XP/level for player %s to check level up.^7", citizenid))
        end
    end)
end

-- Log hacking activity
RegisterServerEvent('qb-hackerjob:server:logActivity')
AddEventHandler('qb-hackerjob:server:logActivity', function(activity, target, success, details)
    if not Config.Logging.enabled then return end
    
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local charInfo = Player.PlayerData.charinfo
    local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
    
    -- Format details as string if it's a table
    if type(details) == 'table' then
        details = json.encode(details)
    end
    
    -- Log to database if enabled
    if Config.Logging.databaseLogs then
        MySQL.insert('INSERT INTO hacker_logs (citizenid, activity, target, success, details) VALUES (?, ?, ?, ?, ?)', {
            citizenid, activity, target, success and 1 or 0, details or ''
        })
    end
    
    -- Log to console if enabled
    if Config.Logging.consoleLogs then
        local status = success and "^2Success^7" or "^1Failed^7"
        print(string.format("^3[qb-hackerjob:LOG] ^7Player: %s (%s) | Activity: %s | Target: %s | Status: %s", 
            playerName, citizenid, activity, target or 'N/A', status))
    end
    
    -- Send to Discord webhook if enabled
    if Config.Logging.discordWebhook.enabled and Config.Logging.discordWebhook.url ~= "" then
        local statusText = success and "Success" or "Failed"
        local color = success and 65280 or 16711680 -- Green or Red
        
        local embed = {
            {
                ["title"] = "Hacker Activity Log",
                ["color"] = color,
                ["fields"] = {
                    {
                        ["name"] = "Player",
                        ["value"] = playerName .. " (" .. citizenid .. ")",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Activity",
                        ["value"] = activity,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Status",
                        ["value"] = statusText,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Target",
                        ["value"] = target or "N/A",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Details",
                        ["value"] = details or "N/A",
                        ["inline"] = false
                    }
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Logging.discordWebhook.url, function(err, text, headers) end, 'POST', json.encode({
            username = Config.Logging.discordWebhook.username,
            embeds = embed,
            avatar_url = Config.Logging.discordWebhook.avatar
        }), { ['Content-Type'] = 'application/json' })
    end
end)

-- Command to check hacker XP/level
QBCore.Commands.Add('checkxp', 'Check your hacker skill progress', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local xp = result[1].xp
            local level = result[1].level
            
            -- Calculate progress to next level
            local nextLevelThreshold = Config.LevelThresholds[level + 1] or Config.LevelThresholds[5] * 2
            local currentLevelThreshold = Config.LevelThresholds[level]
            local progress = math.floor(((xp - currentLevelThreshold) / (nextLevelThreshold - currentLevelThreshold)) * 100)
            
            if level == 5 then
                progress = 100 -- Max level
            end
            
            local levelName = Config.LevelNames[level]
            
            TriggerClientEvent('QBCore:Notify', src, "Hacker Level: " .. level .. " (" .. levelName .. ")", "primary")
            TriggerClientEvent('QBCore:Notify', src, "XP: " .. xp .. " | Progress to next level: " .. progress .. "%", "primary")
        else
            TriggerClientEvent('QBCore:Notify', src, "You have no hacking experience yet.", "error")
        end
    end)
end)

-- Admin command to set a player's hacker level
QBCore.Commands.Add('hackerlevel', 'Set a player\'s hacker level (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'level', help = 'Level (1-5)'}
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local level = tonumber(args[2])
    
    if not targetId or not level then
        TriggerClientEvent('QBCore:Notify', src, "Invalid parameters", "error")
        return
    end
    
    if level < 1 or level > 5 then
        TriggerClientEvent('QBCore:Notify', src, "Level must be between 1 and 5", "error")
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
        return
    end
    
    local citizenid = TargetPlayer.PlayerData.citizenid
    
    -- Set XP to the threshold for this level
    local xp = Config.LevelThresholds[level]
    
    MySQL.update('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = ?, level = ?', {
        citizenid, xp, level, xp, level
    })
    
    TriggerClientEvent('QBCore:Notify', src, "Set " .. TargetPlayer.PlayerData.charinfo.firstname .. "'s hacker level to " .. level, "success")
    TriggerClientEvent('QBCore:Notify', targetId, "Your hacker level has been set to " .. level, "success")
end, 'admin')

-- Admin command to give XP to a player (Reverted Logic with Debugging)
QBCore.Commands.Add('hackerxp', 'Give XP to a player\'s hacker skill (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'amount', help = 'Amount of XP'}
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not targetId or not amount then
        TriggerClientEvent('QBCore:Notify', src, "Invalid parameters", "error")
        return
    end

    if amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "XP amount must be positive", "error")
        return
    end

    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)

    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
        return
    end

    local citizenid = TargetPlayer.PlayerData.citizenid

    print(string.format("^2[qb-hackerjob:hackerxp] Admin %d attempting to add %d XP to player %s (%d).^7", src, amount, citizenid, targetId))

    -- Step 1: Check if player exists and get current XP/Level
    MySQL.query('SELECT xp, level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        local currentXP = 0
        local currentLevel = 1
        local playerExists = (result and #result > 0)

        if playerExists then
            currentXP = result[1].xp
            currentLevel = result[1].level
            print(string.format("^3[qb-hackerjob:hackerxp] Player %s exists. Current XP: %d, Level: %d^7", citizenid, currentXP, currentLevel))
            -- Step 2a: Player exists, update their XP
            local newXP = currentXP + amount
            MySQL.update('UPDATE hacker_skills SET xp = ? WHERE citizenid = ?', {newXP, citizenid}, function(updateResult)
                print(string.format("^3[qb-hackerjob:hackerxp] UPDATE result for %s: affectedRows = %s^7", citizenid, tostring(updateResult)))
                if updateResult and updateResult > 0 then
                    print(string.format("^2[qb-hackerjob:hackerxp] Successfully updated XP for %s to %d.^7", citizenid, newXP))
                    CheckForLevelUpAdmin(src, targetId, citizenid, amount) -- Check for level up after successful update
                else
                    print(string.format("^1[qb-hackerjob:hackerxp] Failed to UPDATE XP for player %s.^7", citizenid))
                    TriggerClientEvent('QBCore:Notify', src, "Failed to update XP for player.", "error")
                end
            end)
        else
            print(string.format("^3[qb-hackerjob:hackerxp] Player %s does not exist. Inserting new record.^7", citizenid))
            -- Step 2b: Player doesn't exist, insert new record
            MySQL.insert('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, 1)', {citizenid, amount}, function(insertResult)
                 local success = false
                 if type(insertResult) == 'number' and insertResult > 0 then success = true
                 elseif type(insertResult) == 'table' and insertResult.insertId then success = true end
                 print(string.format("^3[qb-hackerjob:hackerxp] INSERT result for %s: %s^7", citizenid, json.encode(insertResult)))

                if success then
                    print(string.format("^2[qb-hackerjob:hackerxp] Successfully inserted new record for %s with %d XP.^7", citizenid, amount))
                    CheckForLevelUpAdmin(src, targetId, citizenid, amount) -- Check for level up after successful insert
                else
                    print(string.format("^1[qb-hackerjob:hackerxp] Failed to INSERT new record for player %s.^7", citizenid))
                    TriggerClientEvent('QBCore:Notify', src, "Failed to insert XP record for player.", "error")
                end
            end)
        end
    end)
end, 'admin')

-- Helper function to check for level up after admin XP grant
function CheckForLevelUpAdmin(adminSrc, targetSrc, citizenid, xpAdded)
    print(string.format("^2[qb-hackerjob:CheckLevelUpAdmin] Checking level for %s after admin grant of %d XP.^7", citizenid, xpAdded))
    MySQL.query('SELECT xp, level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local finalXP = result[1].xp
            local initialLevel = result[1].level
            print(string.format("^3[qb-hackerjob:CheckLevelUpAdmin] Fetched stats for %s: XP=%d, InitialLevel=%d^7", citizenid, finalXP, initialLevel))

            local newLevel = initialLevel
            local maxLevelDefined = 0
            for level, _ in pairs(Config.LevelThresholds) do if level > maxLevelDefined then maxLevelDefined = level end end
            for level = initialLevel + 1, maxLevelDefined do
                if Config.LevelThresholds[level] and finalXP >= Config.LevelThresholds[level] then newLevel = level else break end
            end
            local maxLevelName = 0
            for level, _ in pairs(Config.LevelNames) do if level > maxLevelName then maxLevelName = level end end
            if newLevel > maxLevelName then newLevel = maxLevelName end

            print(string.format("^3[qb-hackerjob:CheckLevelUpAdmin] Level check for %s: InitialLevel=%d, Calculated NewLevel=%d^7", citizenid, initialLevel, newLevel))

            if newLevel > initialLevel then
                print(string.format("^2[qb-hackerjob:CheckLevelUpAdmin] Level up detected for %s! Updating level from %d to %d.^7", citizenid, initialLevel, newLevel))
                MySQL.update('UPDATE hacker_skills SET level = ? WHERE citizenid = ?', {newLevel, citizenid}, function(updateResult)
                    print(string.format("^3[qb-hackerjob:CheckLevelUpAdmin] Level update result for %s: affectedRows = %s^7", citizenid, tostring(updateResult)))
                    if updateResult and updateResult > 0 then
                        TriggerClientEvent('QBCore:Notify', adminSrc, "Added " .. xpAdded .. " XP to player " .. citizenid, "success")
                        TriggerClientEvent('QBCore:Notify', targetSrc, "You received " .. xpAdded .. " hacker XP", "success")
                        local levelName = Config.LevelNames[newLevel] or "Unknown Rank"
                        TriggerClientEvent('QBCore:Notify', targetSrc, "Level Up! You are now a " .. levelName, "success")
                        TriggerClientEvent('qb-hackerjob:client:levelUp', targetSrc, newLevel, levelName)
                    else
                        print(string.format("^1[qb-hackerjob:CheckLevelUpAdmin] Failed to update level for player %s after admin XP grant. Update query affected %s rows.^7", citizenid, tostring(updateResult)))
                        TriggerClientEvent('QBCore:Notify', adminSrc, "Added " .. xpAdded .. " XP to player " .. citizenid .. " (level update failed)", "warning")
                        TriggerClientEvent('QBCore:Notify', targetSrc, "You received " .. xpAdded .. " hacker XP", "success")
                    end
                end)
            else
                print(string.format("^2[qb-hackerjob:CheckLevelUpAdmin] No level up for %s. Notifying XP gain only.^7", citizenid))
                TriggerClientEvent('QBCore:Notify', adminSrc, "Added " .. xpAdded .. " XP to player " .. citizenid, "success")
                TriggerClientEvent('QBCore:Notify', targetSrc, "You received " .. xpAdded .. " hacker XP", "success")
            end
        else
            print(string.format("^1[qb-hackerjob:CheckLevelUpAdmin] Failed to fetch XP/level for player %s to check level up.^7", citizenid))
            TriggerClientEvent('QBCore:Notify', adminSrc, "Added " .. xpAdded .. " XP to player " .. citizenid .. " (failed to verify level)", "warning")
            TriggerClientEvent('QBCore:Notify', targetSrc, "You received " .. xpAdded .. " hacker XP", "success")
        end
    end)
end

-- Admin command to view hacker logs
QBCore.Commands.Add('hackerlogs', 'View recent hacking logs (Admin Only)', {
    {name = 'count', help = 'Number of logs to show (default: 10)'}
}, false, function(source, args)
    local src = source
    local count = tonumber(args[1]) or 10
    
    if count < 1 or count > 50 then
        count = 10
    end
    
    MySQL.query('SELECT * FROM hacker_logs ORDER BY created_at DESC LIMIT ?', {count}, function(results)
        if results and #results > 0 then
            TriggerClientEvent('QBCore:Notify', src, "Retrieved " .. #results .. " hacking logs", "success")
            
            for i, log in ipairs(results) do
                local successText = log.success == 1 and "Success" or "Failed"
                local logMessage = string.format("[%s] Player: %s | Activity: %s | Target: %s | Status: %s", 
                    log.created_at, log.citizenid, log.activity, log.target or 'N/A', successText)
                
                -- Send log entries with a delay to prevent chat spam
                Citizen.SetTimeout(i * 200, function()
                    TriggerClientEvent('chat:addMessage', src, {
                        color = {255, 255, 0},
                        multiline = true,
                        args = {"Hacker Logs", logMessage}
                    })
                end)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "No hacking logs found", "error")
        end
    end)
end, 'admin')

-- Add trace buildup when performing hacking operations
RegisterServerEvent('qb-hackerjob:server:increaseTraceLevel')
AddEventHandler('qb-hackerjob:server:increaseTraceLevel', function(activity)
    if not Config.TraceBuildUp.enabled then return end
    
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local traceIncrease = Config.TraceBuildUp.increaseRates[activity] or 0
    
    -- Get current trace level from player metadata
    local currentTrace = Player.PlayerData.metadata.tracelevel or 0
    
    -- Increase trace
    local newTrace = math.min(Config.TraceBuildUp.maxTrace, currentTrace + traceIncrease)
    
    -- Update metadata
    Player.Functions.SetMetaData('tracelevel', newTrace)
    
    -- Determine if we need to alert police
    if newTrace >= Config.TraceBuildUp.alertThreshold then
        -- Only alert if we've crossed the threshold
        if currentTrace < Config.TraceBuildUp.alertThreshold then
            -- Alert police
            TriggerClientEvent('qb-hackerjob:client:alertPoliceTraceLevel', -1, src)
            
            -- Notify the hacker
            TriggerClientEvent('QBCore:Notify', src, "Warning: Your trace level is critically high!", "error")
        end
    elseif newTrace >= Config.TraceBuildUp.alertThreshold * 0.7 then
        -- Warning at 70% of alert threshold
        TriggerClientEvent('QBCore:Notify', src, "Warning: Your trace level is getting high!", "error")
    end
end)

-- Decay trace level over time
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Run every minute
        
        if Config.TraceBuildUp.enabled and Config.TraceBuildUp.decayRate > 0 then
            local players = QBCore.Functions.GetPlayers()
            
            for _, playerId in ipairs(players) do
                local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
                
                if Player then
                    local currentTrace = Player.PlayerData.metadata.tracelevel or 0
                    
                    if currentTrace > 0 then
                        -- Decrease trace
                        local newTrace = math.max(0, currentTrace - Config.TraceBuildUp.decayRate)
                        
                        -- Update metadata
                        Player.Functions.SetMetaData('tracelevel', newTrace)
                        
                        -- Notify player if they went below threshold
                        if currentTrace >= Config.TraceBuildUp.alertThreshold and newTrace < Config.TraceBuildUp.alertThreshold then
                            TriggerClientEvent('QBCore:Notify', playerId, "Your trace level has decreased to a safer level.", "success")
                        end
                    end
                end
            end
        end
    end
end)

-- Test command to give battery and charger items
QBCore.Commands.Add('givehackerbatteryitems', 'Give battery and charger items for testing (Admin Only)', {}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        -- Add battery item
        Player.Functions.AddItem(Config.Battery.batteryItemName, 5)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.batteryItemName], 'add')
        
        -- Add charger item
        Player.Functions.AddItem(Config.Battery.chargerItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Battery.chargerItemName], 'add')
        
        TriggerClientEvent('QBCore:Notify', src, 'You received 5 batteries and 1 charger', 'success')
        print('^2[qb-hackerjob] ^7Admin gave battery items to player ID ' .. src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    end
end, 'admin')

-- Server event to save battery level to player metadata
RegisterServerEvent('qb-hackerjob:server:saveBatteryLevel')
AddEventHandler('qb-hackerjob:server:saveBatteryLevel', function(batteryLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Validate battery level
    if type(batteryLevel) ~= "number" or batteryLevel < 0 or batteryLevel > 100 then
        print("^1[qb-hackerjob] ^7Invalid battery level received from player " .. src .. ": " .. tostring(batteryLevel))
        return
    end
    
    -- Save to player metadata
    Player.Functions.SetMetaData("laptopBattery", batteryLevel)
    print("^2[qb-hackerjob] ^7Saved battery level " .. batteryLevel .. "% for player " .. src)
end)
