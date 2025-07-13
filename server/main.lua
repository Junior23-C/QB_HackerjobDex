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

-- Database setup for hacker progression system (simplified)
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

-- Server event to log hacking activities
RegisterServerEvent('qb-hackerjob:server:logActivity')
AddEventHandler('qb-hackerjob:server:logActivity', function(activity, target, success, details)
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
                        ["name"] = "Target",
                        ["value"] = target or "N/A",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Status",
                        ["value"] = statusText,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Details",
                        ["value"] = details or "None",
                        ["inline"] = false
                    }
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Logging.discordWebhook.url, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), {['Content-Type'] = 'application/json'})
    end
end)

-- View recent hacker logs (Admin Command)
QBCore.Commands.Add('hackerlogs', 'View recent hacker activity logs (Admin Only)', {
    {name = 'count', help = 'Number of logs to retrieve (default: 10)'}
}, true, function(source, args)
    local src = source
    local count = tonumber(args[1]) or 10
    
    if count > 100 then count = 100 end -- Limit to prevent spam
    
    MySQL.query('SELECT hl.*, p.charinfo FROM hacker_logs hl LEFT JOIN players p ON hl.citizenid = p.citizenid ORDER BY hl.created_at DESC LIMIT ?', {count}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "Displaying last " .. #result .. " hacker logs in console", "primary")
            print("^3[qb-hackerjob] ^7========== RECENT HACKER LOGS ==========")
            
            for i, log in ipairs(result) do
                local charInfo = log.charinfo and json.decode(log.charinfo) or {}
                local playerName = (charInfo.firstname or "Unknown") .. " " .. (charInfo.lastname or "Player")
                local status = log.success == 1 and "^2SUCCESS^7" or "^1FAILED^7"
                local timestamp = log.created_at
                
                print(string.format("^3[%d] ^7%s | %s (%s) | %s -> %s | %s | %s", 
                    i, timestamp, playerName, log.citizenid, log.activity, log.target or "N/A", status, log.details or ""))
            end
            
            print("^3[qb-hackerjob] ^7=============================================")
        else
            TriggerClientEvent('QBCore:Notify', src, "No hacker logs found", "error")
        end
    end)
end, 'admin')

-- GPS Tracker shop functionality
QBCore.Functions.CreateCallback('qb-hackerjob:server:canBuyGPSTracker', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local price = Config.GPSTrackerPrice
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash >= price then
        -- Remove cash
        Player.Functions.RemoveMoney('cash', price, "bought-gps-tracker")
        
        -- Add GPS tracker item
        Player.Functions.AddItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], 'add')
        
        -- Success callback
        cb(true)
    else
        cb(false)
    end
end)

-- GPS tracker check and removal
QBCore.Functions.CreateCallback('qb-hackerjob:server:checkAndRemoveGPS', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb(false)
        return
    end
    
    local item = Player.Functions.GetItemByName(Config.GPSTrackerItem)
    if item and item.amount > 0 then
        -- Remove one GPS tracker
        Player.Functions.RemoveItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], 'remove')
        cb(true)
    else
        cb(false)
    end
end)

-- Battery level saving
RegisterServerEvent('qb-hackerjob:server:saveBatteryLevel')
AddEventHandler('qb-hackerjob:server:saveBatteryLevel', function(batteryLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Validate battery level
    if type(batteryLevel) ~= 'number' or batteryLevel < 0 or batteryLevel > 100 then
        print("^1[qb-hackerjob] ^7Invalid battery level received from player " .. src .. ": " .. tostring(batteryLevel))
        return
    end
    
    -- Save to player metadata
    Player.Functions.SetMetaData('laptopBattery', batteryLevel)
    print("^2[qb-hackerjob] ^7Saved battery level " .. batteryLevel .. "% for player " .. src)
end)

-- ===== NEW SIMPLE XP SYSTEM =====

-- Award XP for hacking activities
RegisterServerEvent('hackerjob:awardXP')
AddEventHandler('hackerjob:awardXP', function(activityType)
    if not Config.XPEnabled then return end
    
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local xpAmount = Config.XPSettings[activityType] or 0
    
    if xpAmount <= 0 then return end
    
    -- Get current stats
    MySQL.query('SELECT * FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        local currentXP = 0
        local currentLevel = 1
        
        if result and #result > 0 then
            currentXP = result[1].xp
            currentLevel = result[1].level
        end
        
        -- Add XP
        local newXP = currentXP + xpAmount
        
        -- Calculate new level
        local newLevel = currentLevel
        for level = 1, #Config.LevelThresholds do
            if newXP >= Config.LevelThresholds[level] then
                newLevel = level
            else
                break
            end
        end
        
        -- Update database
        MySQL.query('INSERT INTO hacker_skills (citizenid, xp, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = ?, level = ?', 
            {citizenid, newXP, newLevel, newXP, newLevel}, function()
            
            -- Calculate next level XP
            local nextLevelThreshold = Config.LevelThresholds[newLevel + 1] or Config.LevelThresholds[#Config.LevelThresholds]
            local levelName = Config.LevelNames[newLevel] or "Unknown"
            
            -- Notify player
            local leveledUp = newLevel > currentLevel
            if leveledUp then
                TriggerClientEvent('QBCore:Notify', src, "Level Up! You are now a " .. levelName, "success", 5000)
                TriggerClientEvent('QBCore:Notify', src, "+" .. xpAmount .. " XP gained!", "primary")
            else
                TriggerClientEvent('QBCore:Notify', src, "+" .. xpAmount .. " XP gained!", "success")
            end
            
            -- Update laptop UI if open
            TriggerClientEvent('hackerjob:updateStats', src, {
                level = newLevel,
                xp = newXP,
                nextLevelXP = nextLevelThreshold,
                levelName = levelName
            })
        end)
    end)
end)

-- Get player XP stats
QBCore.Functions.CreateCallback('hackerjob:getStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        cb({level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"})
        return 
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then
            local level = result[1].level
            local xp = result[1].xp
            local nextLevelThreshold = Config.LevelThresholds[level + 1] or Config.LevelThresholds[#Config.LevelThresholds]
            local levelName = Config.LevelNames[level] or "Unknown"
            
            cb({
                level = level,
                xp = xp,
                nextLevelXP = nextLevelThreshold,
                levelName = levelName
            })
        else
            cb({level = 1, xp = 0, nextLevelXP = 100, levelName = "Script Kiddie"})
        end
    end)
end)

-- Admin command to give XP
QBCore.Commands.Add('givexp', 'Give XP to a player (Admin)', {
    {name = 'id', help = 'Player ID'},
    {name = 'amount', help = 'XP Amount'}
}, true, function(source, args)
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('QBCore:Notify', source, "Invalid arguments", "error")
        return
    end
    
    TriggerEvent('hackerjob:awardXP', 'adminGrant')
    TriggerClientEvent('QBCore:Notify', source, "Gave " .. amount .. " XP to player " .. targetId, "success")
end, 'admin')

print('^2[qb-hackerjob] ^7Server script loaded successfully')