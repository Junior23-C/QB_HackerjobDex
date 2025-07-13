local QBCore = exports['qb-core']:GetCoreObject()

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
        
        -- Give item
        Player.Functions.AddItem(Config.LaptopItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.LaptopItem], "add")
        
        -- Log the purchase
        local playerInfo = QBCore.Functions.GetIdentifier(src, 'license')
        local citizenId = Player.PlayerData.citizenid
        local charInfo = Player.PlayerData.charinfo
        local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
        
        print("^2[qb-hackerjob] ^7Player " .. playerName .. " (ID: " .. citizenId .. ") purchased a hacking laptop for $" .. price)
        
        cb(true)
    elseif Player.PlayerData.money.bank >= price then
        -- Remove from bank if not enough cash
        Player.Functions.RemoveMoney('bank', price, "bought-hacker-laptop")
        
        -- Give item
        Player.Functions.AddItem(Config.LaptopItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.LaptopItem], "add")
        
        -- Log the purchase
        local playerInfo = QBCore.Functions.GetIdentifier(src, 'license')
        local citizenId = Player.PlayerData.citizenid
        local charInfo = Player.PlayerData.charinfo
        local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
        
        print("^2[qb-hackerjob] ^7Player " .. playerName .. " (ID: " .. citizenId .. ") purchased a hacking laptop for $" .. price)
        
        cb(true)
    else
        -- Not enough money
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough money ($" .. price .. " required)", "error")
        cb(false)
    end
end)

-- Callback to check if player can buy the GPS tracker
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
        
        -- Give item
        Player.Functions.AddItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], "add")
        
        -- Log the purchase
        local charInfo = Player.PlayerData.charinfo
        local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
        
        print("^2[qb-hackerjob] ^7Player " .. playerName .. " purchased a GPS tracker for $" .. price)
        
        cb(true)
    elseif Player.PlayerData.money.bank >= price then
        -- Remove from bank if not enough cash
        Player.Functions.RemoveMoney('bank', price, "bought-gps-tracker")
        
        -- Give item
        Player.Functions.AddItem(Config.GPSTrackerItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.GPSTrackerItem], "add")
        
        -- Log the purchase
        local charInfo = Player.PlayerData.charinfo
        local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
        
        print("^2[qb-hackerjob] ^7Player " .. playerName .. " purchased a GPS tracker for $" .. price)
        
        cb(true)
    else
        -- Not enough money
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough money ($" .. price .. " required)", "error")
        cb(false)
    end
end) 