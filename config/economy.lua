-- Economy Configuration for QB-HackerJob
-- This file defines all pricing, payment, and economic balance settings

Config.Economy = {
    enabled = true,
    dynamicPricing = true,
    
    -- Base service pricing (in dollars)
    servicePricing = {
        plateLookup = {
            base = 500,          -- $500 base price
            min = 250,           -- Minimum $250
            max = 1500,          -- Maximum $1,500
            multipliers = {
                emergency = 2.5,  -- 2.5x for police vehicles
                stolen = 3.0,     -- 3x for stolen vehicles
                vip = 4.0,        -- 4x for government/VIP vehicles
                repeat = 0.8      -- 20% discount for repeat customers
            }
        },
        phoneTracking = {
            base = 2500,         -- $2,500 base price
            min = 1000,          -- Minimum $1,000
            max = 8000,          -- Maximum $8,000
            multipliers = {
                online = 1.5,     -- 1.5x if target is online
                police = 3.0,     -- 3x for police officers
                government = 4.0, -- 4x for government officials
                distance = 1.2    -- 1.2x if target is >5km away
            }
        },
        radioDecryption = {
            base = 1800,         -- $1,800 base price
            min = 800,           -- Minimum $800
            max = 5000,          -- Maximum $5,000
            multipliers = {
                police = 2.0,     -- 2x for police frequencies
                encrypted = 2.5,  -- 2.5x for encrypted channels
                emergency = 3.0   -- 3x for emergency services
            }
        },
        vehicleControl = {
            base = 5000,         -- $5,000 base price
            min = 2500,          -- Minimum $2,500
            max = 15000,         -- Maximum $15,000
            multipliers = {
                unlock = 1.0,     -- 1x for unlock only
                engine = 1.5,     -- 1.5x for engine control
                tracking = 2.0,   -- 2x for GPS tracking install
                full = 3.0        -- 3x for full vehicle control
            }
        },
        phoneHacking = {
            base = 4000,         -- $4,000 base price
            min = 2000,          -- Minimum $2,000
            max = 12000,         -- Maximum $12,000
            multipliers = {
                messages = 1.0,   -- 1x for message access
                calls = 1.5,      -- 1.5x for call logs
                contacts = 1.2,   -- 1.2x for contact list
                full = 2.0        -- 2x for full phone access
            }
        }
    },
    
    -- Market demand affects pricing
    marketDemand = {
        updateInterval = 300000, -- 5 minutes
        baseMultiplier = 1.0,
        demandDecay = 0.95,      -- 5% decay per interval
        maxDemandBonus = 2.0,    -- Max 100% price increase
        minDemandPenalty = 0.5   -- Max 50% price decrease
    },
    
    -- Payment methods and validation
    payment = {
        acceptCash = true,
        acceptBank = true,
        minimumBalance = 100,    -- Always leave $100 in account
        taxRate = 0.1,          -- 10% server tax on earnings
        feeAccount = 'server'    -- Where taxes go
    },
    
    -- Daily/Weekly limits to prevent exploitation
    limits = {
        dailyEarnings = 25000,   -- Max $25k per day
        weeklyEarnings = 150000, -- Max $150k per week
        dailyJobs = 50,          -- Max 50 jobs per day
        hourlyJobs = 15          -- Max 15 jobs per hour
    },
    
    -- Economic monitoring and balance
    monitoring = {
        enabled = true,
        alertThreshold = 1000000, -- Alert if daily circulation > $1M
        adjustmentRate = 0.05,    -- 5% price adjustment when needed
        logTransactions = true    -- Log all transactions to database
    }
}