# Detailed Installation Guide for QB-HackerJob

This guide provides a detailed step-by-step process for installing and configuring the qb-hackerjob resource with all extended features.

## Pre-Installation Requirements

Before installing qb-hackerjob, ensure your server meets these prerequisites:

1. **QBCore Framework**: Latest version installed and configured
2. **oxmysql**: Latest version installed and running
3. **Required Resources**:
   - qb-core
   - qb-input
   - qb-menu
   - qb-phone (for phone hacking features)
   - qb-inventory (or ox_inventory with appropriate configuration)

## Installation Steps

### 1. Download and Add Resource

1. Download the resource from [GitHub](https://github.com/yourusername/qb-hackerjob) or copy your existing files
2. Place the `qb-hackerjob` folder in your server's resources directory
3. Add the following line to your `server.cfg`:
   ```
   ensure qb-hackerjob
   ```

### 2. Database Setup for Hacker Progression System

The script will automatically set up the required database tables on first run. However, you can manually execute the following SQL queries if needed:

```sql
-- Create hacker_skills table for XP progression system
CREATE TABLE IF NOT EXISTS `hacker_skills` (
  `citizenid` varchar(50) NOT NULL,
  `xp` int(11) NOT NULL DEFAULT 0,
  `level` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create hacker_logs table for logging system
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
```

### 3. Item Configuration

Add the required items to your QBCore items.lua file. The script requires the following items:

```lua
-- Hacker Laptop Item
['hacker_laptop'] = {
    ['name'] = 'hacker_laptop',
    ['label'] = 'Hacking Laptop',
    ['weight'] = 2000,
    ['type'] = 'item',
    ['image'] = 'hacker_laptop.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A specialized laptop for various hacking operations'
},

-- GPS Tracker Item
['gps_tracker'] = {
    ['name'] = 'gps_tracker',
    ['label'] = 'GPS Tracker',
    ['weight'] = 500,
    ['type'] = 'item',
    ['image'] = 'gps_tracker.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = false,
    ['combinable'] = nil,
    ['description'] = 'A device used to track vehicles remotely'
},

-- Laptop Battery Item
['laptop_battery'] = {
    ['name'] = 'laptop_battery',
    ['label'] = 'Laptop Battery',
    ['weight'] = 200,
    ['type'] = 'item',
    ['image'] = 'laptop_battery.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A replacement battery for your hacking laptop'
},

-- Laptop Charger Item
['laptop_charger'] = {
    ['name'] = 'laptop_charger',
    ['label'] = 'Laptop Charger',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'laptop_charger.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A charger for your hacking laptop'
}
```

### 4. Job Configuration

Add the hacker job to your QBCore jobs.lua file:

```lua
['hacker'] = {
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
        },
    },
},
```

### 5. Image Files

Copy the following images to your inventory's image folder:
- `hacker_laptop.png` → Copy from `install/images/` to your inventory images folder
- `gps_tracker.png` → Copy from `install/images/` to your inventory images folder
- `laptop_battery.png` → Copy from `install/images/` to your inventory images folder
- `laptop_charger.png` → Copy from `install/images/` to your inventory images folder

### 6. Configuration

The script offers extensive configuration options. Edit the files in the `config/` directory:

#### config.lua

This file contains general settings like job requirements, vendor settings, UI preferences, and more. Key sections include:

- **Skill Progression System**
```lua
Config.XPEnabled = true -- Enable/disable XP progression system
Config.XPSettings = {
    plateLookup = 5,
    phoneTrack = 10,
    radioDecrypt = 15,
    phoneHack = 20,
    vehicleTrack = 10,
    vehicleControl = 25
}
Config.LevelThresholds = {
    [1] = 0,     -- Script Kiddie
    [2] = 100,   -- Coder
    [3] = 250,   -- Security Analyst
    [4] = 500,   -- Elite Hacker
    [5] = 1000   -- Mastermind
}
Config.LevelNames = {
    [1] = "Script Kiddie",
    [2] = "Coder",
    [3] = "Security Analyst",
    [4] = "Elite Hacker",
    [5] = "Mastermind"
}
```

- **Logging System**
```lua
Config.Logging = {
    enabled = true,
    databaseLogs = true,
    consoleLogs = true,
    discordWebhook = {
        enabled = false,
        url = "", -- Your Discord webhook URL
        username = "Hacker Logs",
        avatar = "" -- URL to an avatar image
    }
}
```

- **Phone Hacking Settings**
```lua
Config.PhoneHacking = {
    enabled = true,
    hackDuration = 10000, -- Time it takes to hack in ms
    cooldown = 120000, -- 2 minute cooldown
    minLevel = 4, -- Minimum hacker level required (Elite Hacker)
    captchaGridSize = 5, -- 5x5 grid for captcha challenge
    maxAttempts = 3, -- Max password attempts
    passwordLength = 6 -- Length of password to crack
}
```

- **Anti-Spam / Cooldowns**
```lua
Config.Cooldowns = {
    global = 5000, -- Global cooldown between any hacking attempts
    lookup = 20000, -- Cooldown for plate lookups
    phoneTrack = 30000, -- Cooldown for phone tracking
    radioDecrypt = 60000, -- Cooldown for radio decryption
    phoneHack = 120000, -- Cooldown for phone hacking
    vehicleHack = 180000 -- Cooldown for vehicle control
}

Config.TraceBuildUp = {
    enabled = true,
    maxTrace = 100, -- Maximum trace value
    decayRate = 5, -- Trace decay per minute
    alertThreshold = 80, -- Alert police when trace exceeds this
    increaseRates = {
        lookup = 5, -- Trace increase per lookup
        phoneTrack = 10, -- Trace increase per phone track
        radioDecrypt = 15, -- Trace increase per radio decrypt
        phoneHack = 20, -- Trace increase per phone hack
        vehicleHack = 25 -- Trace increase per vehicle hack
    }
}
```

#### vehicles.lua

Configure vehicle models, including which can be remotely controlled and their hacking difficulty:

```lua
Config.VehicleModels = {
    -- Modern vehicles with electronic systems (easy to hack)
    ["modern"] = {
        "adder",
        "autarch",
        "entityxf",
        "nero",
        "nero2",
        "t20",
        -- Add more modern vehicles
    },
    
    -- Standard vehicles (medium difficulty)
    ["standard"] = {
        "alpha",
        "banshee",
        "banshee2",
        "buffalo",
        "buffalo2",
        "carbonizzare",
        -- Add more standard vehicles
    },
    
    -- Old or low-tech vehicles (hard or impossible to hack)
    ["old"] = {
        "bfinjection",
        "bifta",
        "bodhi2",
        "dloader",
        "rebel",
        "rebel2",
        -- Add more old vehicles
    }
}

Config.VehicleHackDifficulty = {
    ["modern"] = {
        difficulty = "easy",
        time = 10000, -- 10 seconds to hack
        chance = 90, -- 90% success chance
        levelRequired = 3 -- Security Analyst or higher
    },
    ["standard"] = {
        difficulty = "medium",
        time = 15000, -- 15 seconds to hack
        chance = 70, -- 70% success chance
        levelRequired = 4 -- Elite Hacker or higher
    },
    ["old"] = {
        difficulty = "hard",
        time = 20000, -- 20 seconds to hack
        chance = 40, -- 40% success chance
        levelRequired = 5 -- Mastermind only
    }
}
```

### 7. Discord Webhook (Optional)

For Discord logging:

1. Create a webhook in your Discord server:
   - Go to Server Settings > Integrations > Webhooks
   - Click "New Webhook"
   - Name it "Hacker Logs" and select a channel
   - Copy the webhook URL

2. Add the webhook URL to `config.lua`:
```lua
Config.Logging = {
    -- other settings
    discordWebhook = {
        enabled = true,
        url = "YOUR_WEBHOOK_URL_HERE", -- Paste your Discord webhook URL
        username = "Hacker Logs",
        avatar = "https://i.imgur.com/your_avatar.png" -- Optional avatar URL
    }
}
```

### 8. Inventory Compatibility (Optional)

For ox_inventory compatibility, add to `config.lua`:

```lua
Config.Inventory = {
    type = "qb", -- Options: "qb" or "ox"
    oxInventory = {
        hacker_laptop = {
            name = "hacker_laptop",
            label = "Hacking Laptop",
            weight = 2000,
            stack = false,
            close = true,
            description = "A specialized laptop for various hacking operations"
        },
        gps_tracker = {
            name = "gps_tracker",
            label = "GPS Tracker", 
            weight = 500,
            stack = true,
            close = false,
            description = "A device used to track vehicles remotely"
        },
        -- Add other items similarly
    }
}
```

### 9. Localization (Optional)

To add a new language:

1. Copy `locales/en.lua` to a new file (e.g., `locales/fr.lua` for French)
2. Translate all strings in the new file
3. Update the language setting in `config.lua`:
```lua
Config.Language = 'fr' -- Change to your desired language code
```

### 10. Final Steps

1. Restart your server
2. Test that all features are working properly
3. Adjust configurations as needed for your server's economy and gameplay style

## Troubleshooting

- **Script Errors**: Check your server console for any error messages
- **Missing Dependencies**: Ensure all required resources are installed and running
- **Database Issues**: Verify database connection and that tables exist
- **Image Errors**: Make sure all image files are properly added to your inventory system

For more help, refer to the documentation in README.md or join our Discord support server. 