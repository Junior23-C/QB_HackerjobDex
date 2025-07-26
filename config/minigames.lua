-- Mini-Games Configuration for QB-HackerJob
-- This file defines all skill-based challenges that replace RNG mechanics

Config.MiniGames = {
    enabled = true,
    difficultyScaling = true,
    performanceTracking = true,
    showInstructions = true,
    
    -- Performance metrics and rewards
    performanceMetrics = {
        excellent = {
            threshold = 0.95,        -- 95% accuracy/speed
            rewardMultiplier = 1.5,  -- 50% bonus reward
            xpBonus = 1.3,          -- 30% bonus XP
            traceReduction = 0.7,    -- 30% less police trace
            batteryBonus = 0.8       -- Use 20% less battery
        },
        good = {
            threshold = 0.8,         -- 80% accuracy/speed
            rewardMultiplier = 1.2,  -- 20% bonus reward
            xpBonus = 1.1,          -- 10% bonus XP
            traceReduction = 0.9,    -- 10% less police trace
            batteryBonus = 0.9       -- Use 10% less battery
        },
        average = {
            threshold = 0.6,         -- 60% accuracy/speed
            rewardMultiplier = 1.0,  -- Standard reward
            xpBonus = 1.0,          -- Standard XP
            traceReduction = 1.0,    -- Normal police trace
            batteryBonus = 1.0       -- Normal battery usage
        },
        poor = {
            threshold = 0.3,         -- 30% accuracy/speed
            rewardMultiplier = 0.7,  -- 30% penalty
            xpBonus = 0.8,          -- 20% less XP
            traceReduction = 1.2,    -- 20% more police trace
            batteryBonus = 1.1       -- Use 10% more battery
        },
        failed = {
            threshold = 0.0,         -- Complete failure
            rewardMultiplier = 0.0,  -- No reward
            xpBonus = 0.0,          -- No XP
            traceReduction = 1.5,    -- 50% more police trace
            batteryBonus = 1.2       -- Use 20% more battery
        }
    },
    
    -- Game types for different hacking operations
    gameTypes = {
        -- Circuit connection puzzle for vehicle/device access
        circuitPuzzle = {
            name = "Circuit Connection",
            description = "Connect the circuit nodes to establish data flow",
            usedFor = {"plateLookup", "vehicleControl", "deviceAccess"},
            difficulty = {
                [1] = {gridSize = 4, connections = 3, timeLimit = 30000, complexity = 1},
                [2] = {gridSize = 5, connections = 4, timeLimit = 25000, complexity = 2},
                [3] = {gridSize = 6, connections = 5, timeLimit = 20000, complexity = 2},
                [4] = {gridSize = 7, connections = 6, timeLimit = 18000, complexity = 3},
                [5] = {gridSize = 8, connections = 7, timeLimit = 15000, complexity = 3}
            }
        },
        
        -- Code breaking for encrypted data
        codeBreaker = {
            name = "Code Decryption",
            description = "Analyze patterns and decode encrypted data streams",
            usedFor = {"radioDecrypt", "phoneHacking", "dataExtraction"},
            difficulty = {
                [1] = {codeLength = 6, attempts = 5, patterns = 2, timeLimit = 45000},
                [2] = {codeLength = 8, attempts = 4, patterns = 3, timeLimit = 40000},
                [3] = {codeLength = 10, attempts = 3, patterns = 4, timeLimit = 35000},
                [4] = {codeLength = 12, attempts = 3, patterns = 5, timeLimit = 30000},
                [5] = {codeLength = 15, attempts = 2, patterns = 6, timeLimit = 25000}
            }
        },
        
        -- Memory pattern for surveillance bypass
        memoryPattern = {
            name = "Pattern Recognition",
            description = "Memorize and reproduce security sequences",
            usedFor = {"phoneTracking", "surveillance", "securityBypass"},
            difficulty = {
                [1] = {gridSize = 4, sequenceLength = 4, showTime = 3000, timeLimit = 15000},
                [2] = {gridSize = 5, sequenceLength = 5, showTime = 2500, timeLimit = 12000},
                [3] = {gridSize = 6, sequenceLength = 6, showTime = 2000, timeLimit = 10000},
                [4] = {gridSize = 7, sequenceLength = 7, showTime = 1500, timeLimit = 8000},
                [5] = {gridSize = 8, sequenceLength = 8, showTime = 1000, timeLimit = 6000}
            }
        },
        
        -- Timing-based for system exploitation
        timingChallenge = {
            name = "Timing Sequence",
            description = "Execute precise timing for system exploitation",
            usedFor = {"vehicleControl", "systemExploit", "remoteAccess"},
            difficulty = {
                [1] = {sequences = 3, precision = 500, speed = 2000, timeLimit = 20000},
                [2] = {sequences = 4, precision = 400, speed = 1800, timeLimit = 18000},
                [3] = {sequences = 5, precision = 300, speed = 1600, timeLimit = 16000},
                [4] = {sequences = 6, precision = 250, speed = 1400, timeLimit = 14000},
                [5] = {sequences = 7, precision = 200, speed = 1200, timeLimit = 12000}
            }
        },
        
        -- Rapid typing for brute force attacks
        hackingRush = {
            name = "Hacking Rush",
            description = "Rapid command execution under pressure",
            usedFor = {"bruteForce", "rapidAccess", "emergencyHack"},
            difficulty = {
                [1] = {words = 8, wpm = 40, accuracy = 85, timeLimit = 30000},
                [2] = {words = 10, wpm = 50, accuracy = 88, timeLimit = 25000},
                [3] = {words = 12, wpm = 60, accuracy = 90, timeLimit = 20000},
                [4] = {words = 15, wpm = 70, accuracy = 92, timeLimit = 18000},
                [5] = {words = 18, wpm = 80, accuracy = 95, timeLimit = 15000}
            }
        }
    },
    
    -- Service to game mapping
    serviceMapping = {
        plateLookup = "circuitPuzzle",
        phoneTracking = "memoryPattern", 
        radioDecrypt = "codeBreaker",
        vehicleControl = "timingChallenge",
        phoneHacking = "codeBreaker"
    },
    
    -- Game-specific settings
    gameSettings = {
        circuitPuzzle = {
            nodeColors = {"#00ff00", "#ff0000", "#0000ff", "#ffff00"},
            connectionColor = "#ffffff",
            completedColor = "#00ffff",
            gridSpacing = 60,
            nodeSize = 20
        },
        
        codeBreaker = {
            characterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
            hintTypes = {"position", "character", "pattern"},
            successColor = "#00ff00",
            errorColor = "#ff0000"
        },
        
        memoryPattern = {
            highlightColor = "#00ffff",
            correctColor = "#00ff00",
            incorrectColor = "#ff0000",
            cellSize = 50,
            pulseSpeed = 300
        },
        
        timingChallenge = {
            targetColor = "#ffff00",
            perfectColor = "#00ff00",
            missColor = "#ff0000",
            indicatorSize = 30,
            barWidth = 300
        },
        
        hackingRush = {
            promptColor = "#00ffff",
            correctColor = "#00ff00",
            incorrectColor = "#ff0000",
            fontSize = "18px",
            wordPool = {
                "EXECUTE", "BYPASS", "DECRYPT", "ACCESS", "SECURE", "BREACH", 
                "SYSTEM", "KERNEL", "MATRIX", "CIPHER", "PACKET", "TUNNEL",
                "FIREWALL", "PROTOCOL", "DATABASE", "TERMINAL", "NETWORK", "EXPLOIT"
            }
        }
    },
    
    -- Difficulty progression based on player level
    difficultyProgression = {
        [1] = {gameLevel = 1, successRate = 0.8},  -- Script Kiddie
        [2] = {gameLevel = 2, successRate = 0.7},  -- Coder  
        [3] = {gameLevel = 3, successRate = 0.6},  -- Security Analyst
        [4] = {gameLevel = 4, successRate = 0.5},  -- Elite Hacker
        [5] = {gameLevel = 5, successRate = 0.4}   -- Mastermind
    },
    
    -- Tutorial and help system
    tutorials = {
        enabled = true,
        showOnFirstUse = true,
        skipOption = true,
        
        instructions = {
            circuitPuzzle = "Click and drag to connect circuit nodes. Complete all required connections before time runs out.",
            codeBreaker = "Analyze the encrypted data and find the correct decryption key using the given patterns.",
            memoryPattern = "Watch the sequence carefully, then reproduce it exactly in the same order.",
            timingChallenge = "Click at the precise moment when the indicator aligns with the target zone.",
            hackingRush = "Type the displayed commands as quickly and accurately as possible."
        }
    }
}