local QBCore = exports['qb-core']:GetCoreObject()

-- Minigame system state
local activeGame = nil
local gameCallbacks = {}
local playerPerformance = {}

-- Initialize minigame system
local function InitializeMinigames()
    -- Set up player performance tracking
    local Player = QBCore.Functions.GetPlayerData()
    if Player and Player.citizenid then
        playerPerformance[Player.citizenid] = {
            gamesPlayed = 0,
            averageScore = 0.0,
            bestScores = {},
            preferences = {}
        }
    end
    
    print("^2[MiniGames] ^7System initialized")
end

-- Calculate difficulty level based on player hacker level
local function GetDifficultyLevel(playerLevel, gameType)
    if not Config.MiniGames.difficultyScaling then
        return 1 -- Default difficulty if scaling disabled
    end
    
    local progression = Config.MiniGames.difficultyProgression[playerLevel]
    if progression then
        return progression.gameLevel
    end
    
    return math.min(playerLevel, 5) -- Cap at level 5
end

-- Get performance tier based on score
local function GetPerformanceTier(score)
    local metrics = Config.MiniGames.performanceMetrics
    
    if score >= metrics.excellent.threshold then
        return "excellent", metrics.excellent
    elseif score >= metrics.good.threshold then
        return "good", metrics.good
    elseif score >= metrics.average.threshold then
        return "average", metrics.average
    elseif score >= metrics.poor.threshold then
        return "poor", metrics.poor
    else
        return "failed", metrics.failed
    end
end

-- Start a minigame for a specific service
function StartMiniGame(serviceName, callback)
    if activeGame then
        QBCore.Functions.Notify("Another minigame is already active", "error")
        return false
    end
    
    if not Config.MiniGames.enabled then
        -- Minigames disabled, return success with average performance
        if callback then
            callback(true, 0.6, "average")
        end
        return true
    end
    
    local gameType = Config.MiniGames.serviceMapping[serviceName]
    if not gameType then
        print("^1[MiniGames] ^7No minigame mapped for service: " .. serviceName)
        if callback then
            callback(true, 0.6, "average") -- Default success
        end
        return true
    end
    
    local Player = QBCore.Functions.GetPlayerData()
    local playerLevel = (Player.metadata and Player.metadata.hackerLevel) or 1
    local difficulty = GetDifficultyLevel(playerLevel, gameType)
    
    -- Store callback for when game completes
    gameCallbacks[gameType] = callback
    
    -- Show tutorial if enabled and first time playing this game type
    if Config.MiniGames.tutorials.enabled and Config.MiniGames.tutorials.showOnFirstUse then
        local hasPlayedBefore = playerPerformance[Player.citizenid] and 
                               playerPerformance[Player.citizenid].bestScores[gameType]
        
        if not hasPlayedBefore then
            ShowGameTutorial(gameType, difficulty)
        else
            LaunchGame(gameType, difficulty)
        end
    else
        LaunchGame(gameType, difficulty)
    end
    
    return true
end

-- Show tutorial for a game type
function ShowGameTutorial(gameType, difficulty)
    local gameConfig = Config.MiniGames.gameTypes[gameType]
    local instruction = Config.MiniGames.tutorials.instructions[gameType]
    
    if not instruction then
        -- No tutorial available, proceed to game
        LaunchGame(gameType, difficulty)
        return
    end
    
    local tutorialDialog = exports['qb-input']:ShowInput({
        header = gameConfig.name .. " - Tutorial",
        submitText = "Start Game",
        inputs = {
            {
                text = instruction,
                name = "tutorial",
                type = "text",
                isRequired = false,
                default = "Click 'Start Game' when ready"
            },
            {
                text = "Skip tutorial in future?",
                name = "skip_future",
                type = "checkbox",
                isRequired = false
            }
        }
    })
    
    if tutorialDialog then
        if tutorialDialog.skip_future then
            -- Mark as having played this game before
            local Player = QBCore.Functions.GetPlayerData()
            if not playerPerformance[Player.citizenid].bestScores[gameType] then
                playerPerformance[Player.citizenid].bestScores[gameType] = 0.0
            end
        end
        LaunchGame(gameType, difficulty)
    else
        -- User cancelled tutorial
        if gameCallbacks[gameType] then
            gameCallbacks[gameType](false, 0.0, "failed")
            gameCallbacks[gameType] = nil
        end
    end
end

-- Launch the actual minigame
function LaunchGame(gameType, difficulty)
    local gameConfig = Config.MiniGames.gameTypes[gameType]
    local difficultySettings = gameConfig.difficulty[difficulty]
    
    if not difficultySettings then
        print("^1[MiniGames] ^7Invalid difficulty level: " .. difficulty .. " for game: " .. gameType)
        if gameCallbacks[gameType] then
            gameCallbacks[gameType](false, 0.0, "failed")
            gameCallbacks[gameType] = nil
        end
        return
    end
    
    activeGame = {
        type = gameType,
        difficulty = difficulty,
        settings = difficultySettings,
        startTime = GetGameTimer(),
        score = 0.0
    }
    
    QBCore.Functions.Notify("Starting " .. gameConfig.name .. " (Level " .. difficulty .. ")", "primary")
    
    -- Route to specific game implementation
    if gameType == "circuitPuzzle" then
        StartCircuitPuzzle(difficultySettings)
    elseif gameType == "codeBreaker" then
        StartCodeBreaker(difficultySettings)
    elseif gameType == "memoryPattern" then
        StartMemoryPattern(difficultySettings)
    elseif gameType == "timingChallenge" then
        StartTimingChallenge(difficultySettings)
    elseif gameType == "hackingRush" then
        StartHackingRush(difficultySettings)
    else
        print("^1[MiniGames] ^7Unknown game type: " .. gameType)
        CompleteGame(false, 0.0)
    end
end

-- Circuit puzzle implementation
function StartCircuitPuzzle(settings)
    -- Use the existing hacking progress bar as a simplified circuit puzzle
    local success = true
    local startTime = GetGameTimer()
    
    QBCore.Functions.Progressbar("circuit_puzzle", "Connecting circuit nodes...", settings.timeLimit, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@heists@prison_heiststation@cop_reactions",
        anim = "cop_b_idle",
        flags = 49,
    }, {}, {}, function() -- Done
        local completionTime = GetGameTimer() - startTime
        local timeScore = math.max(0, 1.0 - (completionTime / settings.timeLimit))
        local finalScore = timeScore * 0.8 + 0.2 -- Minimum 20% score for completion
        CompleteGame(true, finalScore)
    end, function() -- Cancel
        CompleteGame(false, 0.0)
    end)
end

-- Code breaker implementation (simplified)
function StartCodeBreaker(settings)
    local attempts = 0
    local maxAttempts = settings.attempts
    local success = false
    local startTime = GetGameTimer()
    
    local function AttemptCode()
        attempts = attempts + 1
        
        -- Simulate code breaking with user input
        local codeInput = exports['qb-input']:ShowInput({
            header = "Code Decryption - Attempt " .. attempts .. "/" .. maxAttempts,
            submitText = "Submit Code",
            inputs = {
                {
                    text = "Enter decryption key (" .. settings.codeLength .. " characters)",
                    name = "code",
                    type = "text",
                    isRequired = true,
                    default = ""
                }
            }
        })
        
        if codeInput and codeInput.code then
            local code = codeInput.code:upper()
            local correctLength = string.len(code) == settings.codeLength
            
            -- Simple success rate based on attempts and correct length
            local successChance = correctLength and (0.8 - (attempts - 1) * 0.15) or 0.1
            success = math.random() < successChance
            
            if success then
                local completionTime = GetGameTimer() - startTime
                local timeScore = math.max(0, 1.0 - (completionTime / settings.timeLimit))
                local attemptScore = math.max(0, 1.0 - (attempts - 1) * 0.2)
                local finalScore = (timeScore + attemptScore) / 2
                CompleteGame(true, finalScore)
            elseif attempts < maxAttempts then
                QBCore.Functions.Notify("Incorrect code. Try again.", "error")
                Citizen.Wait(1000)
                AttemptCode()
            else
                CompleteGame(false, 0.0)
            end
        else
            CompleteGame(false, 0.0)
        end
    end
    
    AttemptCode()
end

-- Memory pattern implementation (simplified)
function StartMemoryPattern(settings)
    QBCore.Functions.Notify("Watch the pattern carefully...", "primary")
    
    -- Show pattern phase
    Citizen.Wait(settings.showTime)
    
    -- User input phase
    local patternInput = exports['qb-input']:ShowInput({
        header = "Pattern Recognition",
        submitText = "Submit Pattern",
        inputs = {
            {
                text = "Enter the pattern you saw (numbers 1-" .. settings.gridSize .. ")",
                name = "pattern",
                type = "text",
                isRequired = true,
                default = ""
            }
        }
    })
    
    if patternInput and patternInput.pattern then
        -- Simple validation - check if pattern length is reasonable
        local pattern = patternInput.pattern
        local expectedLength = settings.sequenceLength
        local accuracy = string.len(pattern) == expectedLength and 0.8 or 0.3
        
        CompleteGame(true, accuracy)
    else
        CompleteGame(false, 0.0)
    end
end

-- Timing challenge implementation (simplified)
function StartTimingChallenge(settings)
    local sequences = settings.sequences
    local completed = 0
    local totalScore = 0
    
    local function NextSequence()
        if completed >= sequences then
            local finalScore = totalScore / sequences
            CompleteGame(true, finalScore)
            return
        end
        
        completed = completed + 1
        QBCore.Functions.Notify("Sequence " .. completed .. "/" .. sequences .. " - Press [E] at the right moment!", "primary")
        
        -- Simulate timing challenge with a countdown
        local timing = math.random(2000, 4000) -- Random timing between 2-4 seconds
        Citizen.Wait(timing)
        
        -- Check if player presses E at the right moment (simplified)
        local sequenceScore = math.random(60, 95) / 100 -- Random score between 0.6-0.95
        totalScore = totalScore + sequenceScore
        
        QBCore.Functions.Notify("Score: " .. math.floor(sequenceScore * 100) .. "%", "success")
        Citizen.Wait(500)
        NextSequence()
    end
    
    NextSequence()
end

-- Hacking rush implementation (simplified)
function StartHackingRush(settings)
    local wordsCompleted = 0
    local totalWords = settings.words
    local totalScore = 0
    local startTime = GetGameTimer()
    
    local function NextWord()
        if wordsCompleted >= totalWords then
            local finalScore = totalScore / totalWords
            CompleteGame(true, finalScore)
            return
        end
        
        wordsCompleted = wordsCompleted + 1
        local wordPool = Config.MiniGames.gameSettings.hackingRush.wordPool
        local targetWord = wordPool[math.random(#wordPool)]
        
        local wordInput = exports['qb-input']:ShowInput({
            header = "Hacking Rush - " .. wordsCompleted .. "/" .. totalWords,
            submitText = "Submit",
            inputs = {
                {
                    text = "Type: " .. targetWord,
                    name = "word",
                    type = "text",
                    isRequired = true,
                    default = ""
                }
            }
        })
        
        if wordInput and wordInput.word then
            local accuracy = (wordInput.word:upper() == targetWord) and 1.0 or 0.3
            totalScore = totalScore + accuracy
            
            if accuracy == 1.0 then
                QBCore.Functions.Notify("Correct!", "success")
            else
                QBCore.Functions.Notify("Incorrect: " .. targetWord, "error")
            end
            
            Citizen.Wait(300)
            NextWord()
        else
            CompleteGame(false, 0.0)
        end
    end
    
    NextWord()
end

-- Complete the current minigame
function CompleteGame(success, score)
    if not activeGame then return end
    
    local gameType = activeGame.type
    local tier, metrics = GetPerformanceTier(score)
    
    -- Update player performance tracking
    local Player = QBCore.Functions.GetPlayerData()
    if Player and Player.citizenid and playerPerformance[Player.citizenid] then
        local perf = playerPerformance[Player.citizenid]
        perf.gamesPlayed = perf.gamesPlayed + 1
        perf.averageScore = (perf.averageScore * (perf.gamesPlayed - 1) + score) / perf.gamesPlayed
        
        if not perf.bestScores[gameType] or score > perf.bestScores[gameType] then
            perf.bestScores[gameType] = score
        end
    end
    
    -- Show result to player
    if success then
        local scorePercent = math.floor(score * 100)
        QBCore.Functions.Notify(string.format("%s Complete! Score: %d%% (%s)", 
            Config.MiniGames.gameTypes[gameType].name, scorePercent, tier:upper()), "success")
    else
        QBCore.Functions.Notify("Minigame failed!", "error")
    end
    
    -- Execute callback
    if gameCallbacks[gameType] then
        gameCallbacks[gameType](success, score, tier)
        gameCallbacks[gameType] = nil
    end
    
    activeGame = nil
end

-- Export functions for use by other scripts
exports('StartMiniGame', StartMiniGame)
exports('GetPlayerPerformance', function() return playerPerformance end)

-- Initialize when resource starts
Citizen.CreateThread(function()
    while not QBCore do
        Citizen.Wait(100)
    end
    InitializeMinigames()
end)