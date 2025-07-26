local QBCore = exports['qb-core']:GetCoreObject()

-- Economy system state
local marketDemand = {}
local playerLimits = {}
local economicMetrics = {
    dailyCirculation = 0,
    totalTransactions = 0,
    lastReset = os.time()
}

-- Initialize market demand for each service
local function InitializeMarketDemand()
    for serviceName, _ in pairs(Config.Economy.servicePricing) do
        marketDemand[serviceName] = {
            currentMultiplier = 1.0,
            recentJobs = 0,
            lastUpdate = GetGameTimer()
        }
    end
    
    print("^2[Economy] ^7Market demand system initialized")
end

-- Calculate dynamic pricing based on multiple factors
local function CalculateServicePrice(serviceName, citizenid, targetData)
    local pricing = Config.Economy.servicePricing[serviceName]
    if not pricing then
        print("^1[Economy] ^7Unknown service: " .. tostring(serviceName))
        return 0
    end
    
    local basePrice = pricing.base
    local finalMultiplier = 1.0
    
    -- Apply market demand multiplier
    local demand = marketDemand[serviceName]
    if demand then
        finalMultiplier = finalMultiplier * demand.currentMultiplier
    end
    
    -- Apply service-specific multipliers based on target data
    if targetData then
        if serviceName == "plateLookup" then
            if targetData.isEmergency then
                finalMultiplier = finalMultiplier * pricing.multipliers.emergency
            end
            if targetData.isStolen then
                finalMultiplier = finalMultiplier * pricing.multipliers.stolen
            end
            if targetData.isVIP then
                finalMultiplier = finalMultiplier * pricing.multipliers.vip
            end
        elseif serviceName == "phoneTracking" then
            if targetData.isOnline then
                finalMultiplier = finalMultiplier * pricing.multipliers.online
            end
            if targetData.isPolice then
                finalMultiplier = finalMultiplier * pricing.multipliers.police
            end
            if targetData.distance and targetData.distance > 5000 then
                finalMultiplier = finalMultiplier * pricing.multipliers.distance
            end
        elseif serviceName == "vehicleControl" then
            local controlType = targetData.controlType or "unlock"
            local multiplier = pricing.multipliers[controlType] or 1.0
            finalMultiplier = finalMultiplier * multiplier
        end
    end
    
    -- Apply customer history multiplier (repeat customer discount)
    if not playerLimits[citizenid] then
        playerLimits[citizenid] = {
            totalJobs = 0,
            dailyJobs = 0,
            dailyEarnings = 0,
            weeklyEarnings = 0,
            lastReset = os.time(),
            lastWeekReset = os.time()
        }
    end
    
    local customerData = playerLimits[citizenid]
    if customerData.totalJobs > 10 then -- After 10 jobs, get repeat customer discount
        finalMultiplier = finalMultiplier * pricing.multipliers.repeat
    end
    
    -- Calculate final price with bounds
    local finalPrice = math.floor(basePrice * finalMultiplier)
    finalPrice = math.max(pricing.min, math.min(pricing.max, finalPrice))
    
    return finalPrice
end

-- Check if player can afford and is within limits
local function ValidatePayment(source, serviceName, price)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, "Player not found"
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Initialize player limits if needed
    if not playerLimits[citizenid] then
        playerLimits[citizenid] = {
            totalJobs = 0,
            dailyJobs = 0,
            dailyEarnings = 0,
            weeklyEarnings = 0,
            lastReset = os.time(),
            lastWeekReset = os.time()
        }
    end
    
    local limits = playerLimits[citizenid]
    local now = os.time()
    
    -- Reset daily limits if needed
    if (now - limits.lastReset) >= 86400 then -- 24 hours
        limits.dailyJobs = 0
        limits.dailyEarnings = 0
        limits.lastReset = now
    end
    
    -- Reset weekly limits if needed
    if (now - limits.lastWeekReset) >= 604800 then -- 7 days
        limits.weeklyEarnings = 0
        limits.lastWeekReset = now
    end
    
    -- Check daily limits
    if limits.dailyJobs >= Config.Economy.limits.dailyJobs then
        return false, "Daily job limit reached (" .. Config.Economy.limits.dailyJobs .. " jobs)"
    end
    
    if (limits.dailyEarnings + price) > Config.Economy.limits.dailyEarnings then
        return false, "Daily earning limit would be exceeded"
    end
    
    -- Check weekly limits
    if (limits.weeklyEarnings + price) > Config.Economy.limits.weeklyEarnings then
        return false, "Weekly earning limit would be exceeded"
    end
    
    -- Check if player has enough money
    local totalMoney = Player.PlayerData.money.cash + Player.PlayerData.money.bank
    if totalMoney < (price + Config.Economy.payment.minimumBalance) then
        return false, string.format("Insufficient funds - need $%d (keeping $%d minimum balance)", 
            price, Config.Economy.payment.minimumBalance)
    end
    
    return true, "Payment validated"
end

-- Process service payment with full validation and logging
local function ProcessServicePayment(source, serviceName, targetData, onSuccess, onFailure)
    if not Config.Economy.enabled then
        print("^3[Economy] ^7Economy system disabled, allowing free service")
        onSuccess(0)
        return
    end
    
    -- Check security and rate limits first
    local securityCheck, securityMessage = exports['qb-hackerjob']:CheckRateLimit(source, serviceName)
    if not securityCheck then
        onFailure("Security check failed: " .. securityMessage)
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        onFailure("Player not found")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local price = CalculateServicePrice(serviceName, citizenid, targetData)
    
    -- Validate payment
    local valid, message = ValidatePayment(source, serviceName, price)
    if not valid then
        onFailure(message)
        return
    end
    
    -- Process payment - prefer cash, then bank
    local paymentMethod = "cash"
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, "hacker-service-" .. serviceName)
    else
        Player.Functions.RemoveMoney('bank', price, "hacker-service-" .. serviceName)
        paymentMethod = "bank"
    end
    
    -- Calculate and process server tax
    local tax = math.floor(price * Config.Economy.payment.taxRate)
    local netEarning = price - tax
    
    -- Update player limits
    local limits = playerLimits[citizenid]
    limits.totalJobs = limits.totalJobs + 1
    limits.dailyJobs = limits.dailyJobs + 1
    limits.dailyEarnings = limits.dailyEarnings + netEarning
    limits.weeklyEarnings = limits.weeklyEarnings + netEarning
    
    -- Update market demand
    UpdateMarketDemand(serviceName)
    
    -- Update economic metrics
    economicMetrics.dailyCirculation = economicMetrics.dailyCirculation + price
    economicMetrics.totalTransactions = economicMetrics.totalTransactions + 1
    
    -- Log transaction if enabled
    if Config.Economy.monitoring.logTransactions then
        LogTransaction(citizenid, serviceName, price, tax, paymentMethod, targetData)
    end
    
    -- Notify player of successful payment
    TriggerClientEvent('QBCore:Notify', source, 
        string.format("Service completed: $%d charged (Tax: $%d)", price, tax), 'success')
    
    print(string.format("^2[Economy] ^7%s paid $%d for %s (Method: %s, Tax: $%d)", 
        citizenid, price, serviceName, paymentMethod, tax))
    
    onSuccess(price)
end

-- Update market demand based on service usage
local function UpdateMarketDemand(serviceName)
    local demand = marketDemand[serviceName]
    if not demand then return end
    
    demand.recentJobs = demand.recentJobs + 1
    
    -- Increase price based on demand (diminishing returns)
    local demandIncrease = 0.02 * math.sqrt(demand.recentJobs)
    demand.currentMultiplier = math.min(
        Config.Economy.marketDemand.maxDemandBonus,
        demand.currentMultiplier + demandIncrease
    )
    
    print(string.format("^2[Economy] ^7%s demand: %.2fx (%d recent jobs)", 
        serviceName, demand.currentMultiplier, demand.recentJobs))
end

-- Log transaction to database
local function LogTransaction(citizenid, serviceName, amount, tax, paymentMethod, targetData)
    local transactionData = {
        citizenid = citizenid,
        service = serviceName,
        amount = amount,
        tax = tax,
        payment_method = paymentMethod,
        target_data = targetData and json.encode(targetData) or nil,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    MySQL.insert([[
        INSERT INTO hacker_transactions 
        (citizenid, service, amount, tax, payment_method, target_data, created_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        transactionData.citizenid,
        transactionData.service,
        transactionData.amount,
        transactionData.tax,
        transactionData.payment_method,
        transactionData.target_data,
        transactionData.created_at
    })
end

-- Market decay system (runs every 5 minutes)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.Economy.marketDemand.updateInterval)
        
        for serviceName, demand in pairs(marketDemand) do
            -- Decay recent jobs count
            demand.recentJobs = math.floor(demand.recentJobs * Config.Economy.marketDemand.demandDecay)
            
            -- Adjust pricing multiplier toward base (1.0)
            if demand.currentMultiplier > 1.0 then
                demand.currentMultiplier = math.max(1.0, demand.currentMultiplier * 0.98)
            elseif demand.currentMultiplier < 1.0 then
                demand.currentMultiplier = math.min(1.0, demand.currentMultiplier * 1.02)
            end
        end
        
        -- Monitor economic health
        if Config.Economy.monitoring.enabled then
            MonitorEconomicHealth()
        end
    end
end)

-- Economic health monitoring
local function MonitorEconomicHealth()
    local now = os.time()
    
    -- Reset daily circulation if needed
    if (now - economicMetrics.lastReset) >= 86400 then -- 24 hours
        if economicMetrics.dailyCirculation > Config.Economy.monitoring.alertThreshold then
            print(string.format("^3[Economy Alert] ^7High daily circulation: $%d", 
                economicMetrics.dailyCirculation))
            
            -- Auto-adjust prices down if too much money flowing
            AdjustBasePrices(-Config.Economy.monitoring.adjustmentRate)
        elseif economicMetrics.dailyCirculation < 50000 then
            print("^3[Economy Alert] ^7Low economic activity detected")
        end
        
        economicMetrics.dailyCirculation = 0
        economicMetrics.lastReset = now
    end
end

-- Adjust base prices for economic balance
local function AdjustBasePrices(percentChange)
    for serviceName, pricing in pairs(Config.Economy.servicePricing) do
        local newBase = math.floor(pricing.base * (1 + percentChange))
        pricing.base = math.max(pricing.min, math.min(pricing.max * 0.8, newBase))
        
        print(string.format("^2[Economy] ^7Adjusted %s base price to $%d (%.1f%% change)", 
            serviceName, pricing.base, percentChange * 100))
    end
end

-- Callback to get service pricing for client
QBCore.Functions.CreateCallback('qb-hackerjob:server:getServicePrice', function(source, cb, serviceName, targetData)
    if not Config.Economy.enabled then
        cb({ success = true, price = 0, message = "Free service (economy disabled)" })
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    local price = CalculateServicePrice(serviceName, Player.PlayerData.citizenid, targetData)
    local valid, message = ValidatePayment(source, serviceName, price)
    
    cb({
        success = valid,
        price = price,
        message = message,
        marketMultiplier = marketDemand[serviceName] and marketDemand[serviceName].currentMultiplier or 1.0
    })
end)

-- Initialize economy system when server starts
Citizen.CreateThread(function()
    -- Wait for database to be ready
    while not MySQL do
        Citizen.Wait(100)
    end
    
    -- Create transaction table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_transactions` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(50) NOT NULL,
            `amount` int(11) NOT NULL,
            `tax` int(11) NOT NULL DEFAULT 0,
            `payment_method` varchar(10) NOT NULL DEFAULT 'cash',
            `target_data` text DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `service` (`service`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    InitializeMarketDemand()
    print("^2[Economy] ^7System initialized successfully")
end)

-- Export functions for use by other scripts
exports('ProcessServicePayment', ProcessServicePayment)
exports('CalculateServicePrice', CalculateServicePrice)
exports('GetMarketDemand', function() return marketDemand end)
exports('GetEconomicMetrics', function() return economicMetrics end)