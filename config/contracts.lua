-- Contract System Configuration for QB-HackerJob
-- This file defines the contract board system for daily player engagement

Config.Contracts = {
    enabled = true,
    refreshInterval = 3600000,  -- 1 hour (new contracts every hour)
    maxActiveContracts = 6,     -- Max contracts available at once
    maxPlayerContracts = 2,     -- Max contracts a player can have active
    contractDuration = 7200000, -- 2 hours to complete a contract
    
    -- Contract categories and their properties
    categories = {
        corporate = {
            name = "Corporate Intelligence",
            description = "Information gathering for business entities",
            weight = 40,           -- 40% chance of this type
            baseReward = 2500,
            xpReward = 25,
            minLevel = 1,
            maxLevel = 5,
            icon = "building"
        },
        
        personal = {
            name = "Personal Investigation",
            description = "Private detective work for individuals",
            weight = 35,           -- 35% chance
            baseReward = 1500,
            xpReward = 15,
            minLevel = 1,
            maxLevel = 3,
            icon = "user"
        },
        
        criminal = {
            name = "Underground Network",
            description = "High-risk operations for criminal organizations",
            weight = 20,           -- 20% chance
            baseReward = 4000,
            xpReward = 40,
            minLevel = 3,
            maxLevel = 5,
            icon = "mask"
        },
        
        government = {
            name = "Classified Operations",
            description = "Sensitive work for government agencies",
            weight = 5,            -- 5% rare contracts
            baseReward = 8000,
            xpReward = 80,
            minLevel = 4,
            maxLevel = 5,
            icon = "shield"
        }
    },
    
    -- Contract templates
    templates = {
        -- Corporate contracts
        {
            category = "corporate",
            title = "Competitor Analysis",
            description = "Gather intelligence on market competitors through vehicle tracking and employee surveillance.",
            objectives = {
                {type = "plateLookup", count = 3, description = "Look up 3 corporate vehicle plates"},
                {type = "phoneTracking", count = 2, description = "Track 2 executive phone numbers"}
            },
            difficulty = 2,
            timeLimit = 3600000 -- 1 hour
        },
        
        {
            category = "corporate", 
            title = "Security Audit",
            description = "Test corporate communication security by intercepting radio frequencies.",
            objectives = {
                {type = "radioDecrypt", count = 2, description = "Decrypt 2 corporate radio channels"},
                {type = "phoneHacking", count = 1, description = "Access 1 executive phone"}
            },
            difficulty = 3,
            timeLimit = 5400000 -- 1.5 hours
        },
        
        -- Personal contracts
        {
            category = "personal",
            title = "Missing Person",
            description = "Help locate a missing person by tracking their last known associates.",
            objectives = {
                {type = "phoneTracking", count = 2, description = "Track 2 associated phone numbers"},
                {type = "plateLookup", count = 1, description = "Look up their vehicle registration"}
            },
            difficulty = 1,
            timeLimit = 2700000 -- 45 minutes
        },
        
        {
            category = "personal",
            title = "Infidelity Investigation", 
            description = "Gather evidence of potential infidelity through digital surveillance.",
            objectives = {
                {type = "phoneHacking", count = 1, description = "Access suspect's phone records"},
                {type = "vehicleControl", count = 1, description = "Track vehicle movements"}
            },
            difficulty = 2,
            timeLimit = 3600000 -- 1 hour
        },
        
        -- Criminal contracts
        {
            category = "criminal",
            title = "Police Evasion",
            description = "Help criminal operations avoid law enforcement through radio intelligence.",
            objectives = {
                {type = "radioDecrypt", count = 3, description = "Monitor police radio frequencies"},
                {type = "plateLookup", count = 2, description = "Identify undercover police vehicles"}
            },
            difficulty = 4,
            timeLimit = 1800000 -- 30 minutes (high pressure)
        },
        
        {
            category = "criminal",
            title = "Asset Recovery",
            description = "Locate and track high-value targets for criminal organizations.",
            objectives = {
                {type = "vehicleControl", count = 2, description = "Take control of 2 luxury vehicles"},
                {type = "phoneTracking", count = 3, description = "Track 3 high-value targets"}
            },
            difficulty = 5,
            timeLimit = 7200000 -- 2 hours
        },
        
        -- Government contracts
        {
            category = "government",
            title = "National Security",
            description = "Classified surveillance operation for national security purposes.",
            objectives = {
                {type = "phoneHacking", count = 2, description = "Access 2 foreign agent communications"},
                {type = "radioDecrypt", count = 1, description = "Decrypt classified frequency"},
                {type = "vehicleControl", count = 1, description = "Track diplomatic vehicle"}
            },
            difficulty = 5,
            timeLimit = 10800000 -- 3 hours
        }
    },
    
    -- Difficulty multipliers
    difficultyMultipliers = {
        [1] = {reward = 0.8, xp = 0.8, trace = 0.5},   -- Easy: 80% reward, 50% trace risk
        [2] = {reward = 1.0, xp = 1.0, trace = 1.0},   -- Normal: Standard values
        [3] = {reward = 1.3, xp = 1.2, trace = 1.3},   -- Hard: 130% reward, 130% trace risk
        [4] = {reward = 1.6, xp = 1.5, trace = 1.6},   -- Very Hard: 160% reward, 160% trace
        [5] = {reward = 2.0, xp = 2.0, trace = 2.0}    -- Extreme: 200% reward, 200% trace
    },
    
    -- Contract completion bonuses
    bonuses = {
        timeBonus = {
            enabled = true,
            thresholds = {
                [0.5] = 0.5,  -- Complete in 50% of time = 50% bonus
                [0.7] = 0.3,  -- Complete in 70% of time = 30% bonus
                [0.9] = 0.1   -- Complete in 90% of time = 10% bonus
            }
        },
        
        streakBonus = {
            enabled = true,
            bonusPerStreak = 0.1,  -- 10% bonus per consecutive completion
            maxStreak = 5          -- Max 50% bonus at 5 streak
        },
        
        perfectBonus = {
            enabled = true,
            bonus = 0.25,          -- 25% bonus for perfect completion
            description = "Complete all objectives with excellent minigame performance"
        }
    },
    
    -- Failure penalties
    penalties = {
        timeoutPenalty = {
            enabled = true,
            cooldown = 1800000,    -- 30 minute cooldown after timeout
            description = "Failed to complete contract in time"
        },
        
        abandonPenalty = {
            enabled = true,
            cooldown = 900000,     -- 15 minute cooldown after abandoning
            description = "Contract abandoned"
        }
    },
    
    -- Reputation integration (for future use)
    reputationEffects = {
        enabled = false, -- Will be enabled when reputation system is implemented
        completionBonus = 5,
        failurePenalty = -3,
        timeoutPenalty = -1
    }
}