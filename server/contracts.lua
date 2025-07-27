local QBCore = exports['qb-core']:GetCoreObject()

-- Helper function to get table keys
local function getTableKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

-- Contract system state
local ContractSystem = {
    activeContracts = {},      -- Currently available contracts
    playerContracts = {},      -- Player's active contracts
    completedContracts = {},   -- Recently completed contracts
    lastRefresh = 0,           -- Last time contracts were refreshed
    contractIdCounter = 1      -- Unique ID counter
}

-- Refresh available contracts
local function RefreshContracts()
    print("^2[Contracts] ^7Refreshing available contracts")
    
    -- Clear expired contracts
    local currentTime = os.time()
    for i = #ContractSystem.activeContracts, 1, -1 do
        local contract = ContractSystem.activeContracts[i]
        if contract.expiresAt and contract.expiresAt < currentTime then
            table.remove(ContractSystem.activeContracts, i)
            print("^3[Contracts] ^7Removed expired contract: " .. contract.title)
        end
    end
    
    -- Generate new contracts to maintain target count
    local targetContracts = Config.Contracts.maxActiveContracts or 6
    local currentCount = #ContractSystem.activeContracts
    local contractsToGenerate = targetContracts - currentCount
    
    print("^2[Contracts] ^7Current contracts: " .. currentCount .. ", Target: " .. targetContracts .. ", Need to generate: " .. contractsToGenerate)
    
    for i = 1, contractsToGenerate do
        local newContract = GenerateRandomContract()
        if newContract then
            table.insert(ContractSystem.activeContracts, newContract)
            print("^2[Contracts] ^7Generated new contract: " .. newContract.title)
        else
            print("^1[Contracts] ^7Failed to generate contract " .. i)
        end
    end
    
    ContractSystem.lastRefresh = currentTime
    print("^2[Contracts] ^7Refresh complete. Active contracts: " .. #ContractSystem.activeContracts)
end

-- Check for expired player contracts
local function CheckExpiredContracts()
    local currentTime = os.time()
    
    for citizenid, contracts in pairs(ContractSystem.playerContracts) do
        for i = #contracts, 1, -1 do
            local contract = contracts[i]
            if contract.expiresAt and contract.expiresAt < currentTime then
                table.remove(contracts, i)
                LogContractCompletion(citizenid, contract, "expired")
                
                -- Notify player if online
                local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                if Player then
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source,
                        'Contract expired: ' .. contract.title, 'error')
                end
                
                print("^3[Contracts] ^7Expired contract for " .. citizenid .. ": " .. contract.title)
            end
        end
    end
end

-- Update contract progress when player completes operations
function UpdateContractProgress(citizenid, operationType)
    if not ContractSystem.playerContracts[citizenid] then
        return
    end
    
    local contracts = ContractSystem.playerContracts[citizenid]
    
    for _, contract in ipairs(contracts) do
        if contract.status == "active" then
            -- Check if this operation type is needed for any objectives
            for _, objective in ipairs(contract.objectives) do
                if objective.type == operationType then
                    -- Initialize progress if not exists
                    if not contract.progress[objective.type] then
                        contract.progress[objective.type] = 0
                    end
                    
                    -- Increment progress
                    contract.progress[objective.type] = contract.progress[objective.type] + 1
                    
                    print(string.format("^2[Contracts] ^7Progress update for %s: %s %d/%d", 
                        citizenid, objective.type, contract.progress[objective.type], objective.count))
                    
                    -- Check if objective is complete
                    if contract.progress[objective.type] >= objective.count then
                        print(string.format("^2[Contracts] ^7Objective completed: %s", objective.description))
                    end
                    
                    -- Check if entire contract is complete
                    local allComplete = true
                    for _, obj in ipairs(contract.objectives) do
                        local progress = contract.progress[obj.type] or 0
                        if progress < obj.count then
                            allComplete = false
                            break
                        end
                    end
                    
                    if allComplete then
                        CompleteContract(citizenid, contract)
                    end
                    
                    break -- Only update one contract per operation
                end
            end
        end
    end
end

-- Initialize contract system
local function InitializeContracts()
    print("^2[Contracts] ^7System initializing...")
    
    -- Check if config is loaded
    if not Config or not Config.Contracts then
        print("^1[Contracts] ^7ERROR: Config.Contracts not found!")
        return
    end
    
    if not Config.Contracts.templates then
        print("^1[Contracts] ^7ERROR: No contract templates in config!")
        return
    end
    
    print("^2[Contracts] ^7Contract templates found: " .. #Config.Contracts.templates)
    print("^2[Contracts] ^7Categories found: " .. table.concat(getTableKeys(Config.Contracts.categories or {}), ", "))
    
    -- Generate initial contracts
    RefreshContracts()
    
    -- Start contract refresh thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.Contracts.refreshInterval)
            RefreshContracts()
        end
    end)
    
    -- Start contract expiry checking thread
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Check every minute
            CheckExpiredContracts()
        end
    end)
end

-- Generate unique contract ID
local function GenerateContractId()
    local id = "CONTRACT_" .. ContractSystem.contractIdCounter .. "_" .. os.time()
    ContractSystem.contractIdCounter = ContractSystem.contractIdCounter + 1
    return id
end

-- Generate a random contract based on templates
local function GenerateRandomContract()
    if not Config.Contracts.templates or #Config.Contracts.templates == 0 then
        print("^1[Contracts] ^7No contract templates found!")
        return nil
    end
    
    -- Select random template
    local template = Config.Contracts.templates[math.random(#Config.Contracts.templates)]
    local category = Config.Contracts.categories[template.category]
    
    if not category then
        print("^1[Contracts] ^7Unknown category: " .. template.category)
        return nil
    end
    
    -- Generate contract data
    local contract = {
        id = GenerateContractId(),
        category = template.category,
        title = template.title,
        description = template.description,
        objectives = {},
        difficulty = template.difficulty,
        timeLimit = template.timeLimit,
        createdAt = os.time(),
        expiresAt = os.time() + (Config.Contracts.contractDuration / 1000),
        status = "available",
        assignedTo = nil,
        progress = {}
    }
    
    -- Copy objectives
    for _, objective in ipairs(template.objectives) do
        table.insert(contract.objectives, {
            type = objective.type,
            count = objective.count,
            description = objective.description,
            completed = 0
        })
    end
    
    -- Calculate rewards based on difficulty
    local difficultyMultiplier = Config.Contracts.difficultyMultipliers[contract.difficulty] or {reward = 1.0, xp = 1.0}
    contract.reward = math.floor(category.baseReward * difficultyMultiplier.reward)
    contract.xpReward = math.floor(category.xpReward * difficultyMultiplier.xp)
    contract.minLevel = category.minLevel
    contract.maxLevel = category.maxLevel
    contract.icon = category.icon
    
    return contract
end

-- Refresh available contracts
function RefreshContracts()
    local currentTime = os.time()
    
    -- Remove expired contracts
    local newActiveContracts = {}
    for _, contract in ipairs(ContractSystem.activeContracts) do
        if contract.expiresAt > currentTime and contract.status == "available" then
            table.insert(newActiveContracts, contract)
        end
    end
    ContractSystem.activeContracts = newActiveContracts
    
    -- Generate new contracts if needed
    local contractsNeeded = Config.Contracts.maxActiveContracts - #ContractSystem.activeContracts
    
    for i = 1, contractsNeeded do
        local contract = GenerateRandomContract()
        if contract then
            table.insert(ContractSystem.activeContracts, contract)
        end
    end
    
    ContractSystem.lastRefresh = currentTime
    print(string.format("^2[Contracts] ^7Refreshed contracts - %d available", #ContractSystem.activeContracts))
    
    -- Notify all players with hacker laptops that contracts have refreshed
    TriggerClientEvent('qb-hackerjob:client:contractsRefreshed', -1)
end

-- Check for expired player contracts
function CheckExpiredContracts()
    local currentTime = os.time()
    local expiredCount = 0
    
    for citizenid, contracts in pairs(ContractSystem.playerContracts) do
        local activeContracts = {}
        
        for _, contract in ipairs(contracts) do
            if contract.expiresAt <= currentTime then
                -- Contract expired
                expiredCount = expiredCount + 1
                
                -- Apply timeout penalty
                if Config.Contracts.penalties.timeoutPenalty.enabled then
                    -- Add cooldown logic here if needed
                end
                
                -- Log completion to database
                LogContractCompletion(citizenid, contract, "timeout")
                
                -- Notify player if online
                local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                if Player then
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 
                        'Contract "' .. contract.title .. '" has expired', 'error')
                end
            else
                table.insert(activeContracts, contract)
            end
        end
        
        ContractSystem.playerContracts[citizenid] = activeContracts
    end
    
    if expiredCount > 0 then
        print(string.format("^3[Contracts] ^7%d contracts expired", expiredCount))
    end
end

-- Get available contracts for a player
QBCore.Functions.CreateCallback('qb-hackerjob:server:getAvailableContracts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    -- Filter contracts by player level
    local playerLevel = (Player.PlayerData.metadata and Player.PlayerData.metadata.hackerLevel) or 1
    local availableContracts = {}
    
    for _, contract in ipairs(ContractSystem.activeContracts) do
        if contract.status == "available" and 
           playerLevel >= contract.minLevel and 
           playerLevel <= contract.maxLevel then
            table.insert(availableContracts, contract)
        end
    end
    
    cb({
        success = true,
        contracts = availableContracts,
        playerLevel = playerLevel,
        maxPlayerContracts = Config.Contracts.maxPlayerContracts
    })
end)

-- Get player's active contracts
QBCore.Functions.CreateCallback('qb-hackerjob:server:getPlayerContracts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local contracts = ContractSystem.playerContracts[citizenid] or {}
    
    cb({
        success = true,
        contracts = contracts
    })
end)

-- Accept a contract
QBCore.Functions.CreateCallback('qb-hackerjob:server:acceptContract', function(source, cb, contractId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check if player already has max contracts
    local playerContracts = ContractSystem.playerContracts[citizenid] or {}
    if #playerContracts >= Config.Contracts.maxPlayerContracts then
        cb({ success = false, message = "You already have the maximum number of active contracts" })
        return
    end
    
    -- Find the contract
    local contract = nil
    local contractIndex = nil
    
    for i, c in ipairs(ContractSystem.activeContracts) do
        if c.id == contractId and c.status == "available" then
            contract = c
            contractIndex = i
            break
        end
    end
    
    if not contract then
        cb({ success = false, message = "Contract not found or already taken" })
        return
    end
    
    -- Assign contract to player
    contract.status = "active"
    contract.assignedTo = citizenid
    contract.acceptedAt = os.time()
    contract.expiresAt = os.time() + (contract.timeLimit / 1000)
    
    -- Initialize progress tracking
    for _, objective in ipairs(contract.objectives) do
        objective.completed = 0
    end
    
    -- Add to player's contracts
    if not ContractSystem.playerContracts[citizenid] then
        ContractSystem.playerContracts[citizenid] = {}
    end
    table.insert(ContractSystem.playerContracts[citizenid], contract)
    
    -- Remove from available contracts
    table.remove(ContractSystem.activeContracts, contractIndex)
    
    print(string.format("^2[Contracts] ^7Player %s accepted contract: %s", citizenid, contract.title))
    
    cb({ success = true, message = "Contract accepted successfully" })
end)

-- Update contract progress when player completes a hacking operation
function UpdateContractProgress(citizenid, operationType)
    local playerContracts = ContractSystem.playerContracts[citizenid]
    if not playerContracts then return end
    
    for _, contract in ipairs(playerContracts) do
        if contract.status == "active" then
            for _, objective in ipairs(contract.objectives) do
                if objective.type == operationType and objective.completed < objective.count then
                    objective.completed = objective.completed + 1
                    
                    -- Check if contract is completed
                    local allCompleted = true
                    for _, obj in ipairs(contract.objectives) do
                        if obj.completed < obj.count then
                            allCompleted = false
                            break
                        end
                    end
                    
                    if allCompleted then
                        CompleteContract(citizenid, contract)
                    else
                        -- Notify player of progress
                        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                        if Player then
                            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source,
                                string.format('Contract progress: %s (%d/%d)', 
                                    objective.description, objective.completed, objective.count), 'primary')
                        end
                    end
                    
                    break
                end
            end
        end
    end
end

-- Complete a contract
function CompleteContract(citizenid, contract)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return end
    
    -- Calculate final rewards
    local finalReward = contract.reward
    local finalXP = contract.xpReward
    local bonusText = ""
    
    -- Time bonus
    if Config.Contracts.bonuses.timeBonus.enabled then
        local timeTaken = os.time() - contract.acceptedAt
        local timeRatio = timeTaken / (contract.timeLimit / 1000)
        
        for threshold, bonus in pairs(Config.Contracts.bonuses.timeBonus.thresholds) do
            if timeRatio <= threshold then
                finalReward = math.floor(finalReward * (1 + bonus))
                finalXP = math.floor(finalXP * (1 + bonus))
                bonusText = bonusText .. string.format(" +%.0f%% time bonus", bonus * 100)
                break
            end
        end
    end
    
    -- Give rewards to player
    Player.Functions.AddMoney('cash', finalReward, "contract-completion")
    
    -- Add XP if enabled
    if Config.XPEnabled then
        local currentXP = Player.PlayerData.metadata.hackerXP or 0
        Player.Functions.SetMetaData('hackerXP', currentXP + finalXP)
        
        -- Check for level up
        TriggerEvent('qb-hackerjob:server:checkLevelUp', Player.PlayerData.source)
    end
    
    -- Update contract status
    contract.status = "completed"
    contract.completedAt = os.time()
    contract.finalReward = finalReward
    contract.finalXP = finalXP
    
    -- Remove from player's active contracts
    local playerContracts = ContractSystem.playerContracts[citizenid] or {}
    for i, c in ipairs(playerContracts) do
        if c.id == contract.id then
            table.remove(playerContracts, i)
            break
        end
    end
    
    -- Log completion
    LogContractCompletion(citizenid, contract, "completed")
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source,
        string.format('Contract completed! Reward: $%d, XP: %d%s', finalReward, finalXP, bonusText), 'success')
    
    print(string.format("^2[Contracts] ^7Player %s completed contract: %s (Reward: $%d, XP: %d)", 
        citizenid, contract.title, finalReward, finalXP))
end

-- Log contract completion to database
function LogContractCompletion(citizenid, contract, status)
    if not Config.Economy or not Config.Economy.monitoring or not Config.Economy.monitoring.logTransactions then
        return
    end
    
    MySQL.insert([[
        INSERT INTO hacker_contract_logs 
        (citizenid, contract_id, contract_title, category, difficulty, status, reward, xp_reward, completed_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        contract.id,
        contract.title,
        contract.category,
        contract.difficulty,
        status,
        contract.finalReward or 0,
        contract.finalXP or 0,
        os.date('%Y-%m-%d %H:%M:%S')
    })
end

-- Event handler for tracking hacking operations
RegisterNetEvent('qb-hackerjob:server:operationCompleted')
AddEventHandler('qb-hackerjob:server:operationCompleted', function(operationType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    UpdateContractProgress(citizenid, operationType)
end)

-- Get contracts for the new UI (combines available and player contracts)
QBCore.Functions.CreateCallback('qb-hackerjob:server:getContracts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    print("^3[Contracts] ^7Getting contracts for player " .. source .. ". Active contracts: " .. #ContractSystem.activeContracts)
    
    -- If no contracts, create some test contracts
    if #ContractSystem.activeContracts == 0 then
        print("^3[Contracts] ^7No contracts available, creating test contracts")
        ContractSystem.activeContracts = {
            {
                id = "TEST001",
                category = "corporate",
                title = "Test Contract - Data Retrieval",
                description = "Retrieve sensitive data from corporate servers",
                difficulty = 2,
                reward = 2500,
                xpReward = 25,
                timeLimit = 3600000,
                expiresAt = os.time() + 7200,
                objectives = {
                    {type = "plateLookup", count = 2, description = "Look up 2 vehicle plates", current = 0}
                }
            },
            {
                id = "TEST002", 
                category = "personal",
                title = "Test Contract - Missing Person",
                description = "Track down a missing person using phone data",
                difficulty = 1,
                reward = 1500,
                xpReward = 15,
                timeLimit = 2700000,
                expiresAt = os.time() + 7200,
                objectives = {
                    {type = "phoneTracking", count = 1, description = "Track 1 phone number", current = 0}
                }
            }
        }
    end
    
    cb({
        success = true,
        contracts = ContractSystem.activeContracts or {}
    })
end)

-- Admin command to force refresh contracts
QBCore.Commands.Add('refreshcontracts', 'Force refresh available contracts (Admin Only)', {}, false, function(source, args)
    local src = source
    
    -- Check for admin or god permission
    if src ~= 0 and not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('QBCore:Notify', src, 'Access denied - insufficient permissions', 'error')
        return
    end
    
    RefreshContracts()
    TriggerClientEvent('QBCore:Notify', src, 'Contracts refreshed successfully', 'success')
end, 'admin')

-- Export functions
exports('UpdateContractProgress', UpdateContractProgress)
exports('GetPlayerContracts', function(citizenid) 
    return ContractSystem.playerContracts[citizenid] or {} 
end)
exports('GetActiveContracts', function()
    return ContractSystem.activeContracts or {}
end)

-- Initialize system when server starts
Citizen.CreateThread(function()
    -- Wait for database to be ready
    while not MySQL do
        Citizen.Wait(100)
    end
    
    -- Create contract logs table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `hacker_contract_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `contract_id` varchar(100) NOT NULL,
            `contract_title` varchar(200) NOT NULL,
            `category` varchar(50) NOT NULL,
            `difficulty` int(1) NOT NULL,
            `status` varchar(20) NOT NULL,
            `reward` int(11) NOT NULL DEFAULT 0,
            `xp_reward` int(11) NOT NULL DEFAULT 0,
            `completed_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `category` (`category`),
            KEY `completed_at` (`completed_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    InitializeContracts()
    print("^2[Contracts] ^7System initialized successfully")
end)