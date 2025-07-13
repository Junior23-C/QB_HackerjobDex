# QBCore Hacker Job

A comprehensive hacker job script for QBCore framework featuring a robust vehicle plate lookup system, phone tracking, radio decryption tools, and a skill progression system.

![Hacker Job Banner](html/img/banner.png)

## Features

- **Robust Vehicle Plate Lookup System**: Query vehicle ownership details with accurate handling of player-owned, NPC-owned, and emergency vehicles
- **Interactive Hacker Laptop**: Sleek interface with multiple hacking tools
- **Vehicle Tracking**: Install GPS trackers on vehicles to monitor their movements in real-time
- **Phone Tracking Tool**: Track player phones using their number
- **Radio Decryption**: Attempt to decrypt police radio frequencies
- **Phone Hacking by Number**: Access SMS and call history from player phones after password cracking
- **Skill Progression System**: Gain XP for successful hacks and unlock advanced features as you level up
- **Vehicle Remote Control**: Remotely unlock, start, or disable vehicles with advanced hacking techniques
- **Configurable Settings**: Extensive configuration options for all features
- **Multi-language Support**: Easy translation with locale files
- **Admin Logging System**: Track all hacking attempts with optional Discord webhook integration
- **Reliable Architecture**: Efficient caching and error handling systems

## Prerequisites

- [qb-core](https://github.com/qbcore-framework/qb-core) - Latest version
- [qb-input](https://github.com/qbcore-framework/qb-input) - For input dialogs
- [qb-menu](https://github.com/qbcore-framework/qb-menu) - For interactive menus
- [qb-phone](https://github.com/qbcore-framework/qb-phone) - Required for phone tracking and hacking features
- [oxmysql](https://github.com/overextended/oxmysql) - Database middleware

## Installation

### Step 1: Resource Installation
1. Add the `qb-hackerjob` folder to your server resources directory
2. Add the following to your server.cfg:
```
ensure qb-hackerjob
```

### Step 2: Job Configuration
Add the hacker job to your QBCore jobs.lua file or use the provided `install/jobs.lua`:

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

### Step 3: Item Configuration
Add the items to your QBCore items.lua file or use the provided `install/items.lua`:

```lua
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
},
```

### Step 4: Images
Add the item images to your inventory images folder:
- hacker_laptop.png
- gps_tracker.png
- laptop_battery.png
- laptop_charger.png

### Step 5: Configuration
1. Review and adjust settings in `config/config.lua` to your liking
2. Configure vehicle models in `config/vehicles.lua`
3. Review and adjust permissions in the `fxmanifest.lua` if needed

### Step 6: Server Restart
Restart your server to apply all changes

## Laptop Vendor Location

A special vendor NPC can be found at location **-1055.49, -230.57** near the LifeInvader building. Players can purchase:
- Hacking Laptop: $50,000
- GPS Vehicle Tracker: $3,000
- Laptop Battery: $1,500
- Laptop Charger: $2,500

![Vendor Location](html/img/vendor_location.png)

### Map Blip

The vendor location has a configurable map blip that can be toggled:

- Use the command `/togglehackerblip` to show or hide the blip on the map
- Configure the blip appearance in the config.lua file

## Usage Guide

### Admin Commands
- `/givehackerlaptop [id]` - Give a hacker laptop to a player (admin only)
- `/hackerlevel [id] [level]` - Set a player's hacker level (admin only)
- `/hackerxp [id] [amount]` - Give XP to a player's hacker skill (admin only)
- `/hackerlogs [count]` - View recent hacking logs (admin only)

### Regular Commands
- Default keybind or command to open laptop: `/hackerlaptop`
- Can be used as an item from inventory if `Config.UsableItem = true`
- `/togglehackerblip` - Toggle the visibility of the vendor blip on the map
- `/checkxp` - Check your current hacker XP and level

### Plate Lookup Tool
1. Open the hacker laptop
2. Select "Vehicle Plate Lookup"
3. Enter a plate number or choose from nearby vehicles
4. View detailed vehicle information

### Vehicle Tracking System
1. Purchase a GPS tracker from the hacker vendor
2. Find a target vehicle within 15 meters
3. Open the hacker laptop and look up the vehicle
4. Click the "Track Vehicle" action button
5. The vehicle will appear on your map with a red blip for 5 minutes

### Phone Tracking
1. Open the hacker laptop
2. Select "Phone Tracker"
3. Enter a phone number
4. If successful, the target's location will appear on your map temporarily

### Phone Hacking
1. Open the hacker laptop
2. Select "Phone Hacking"
3. Enter a phone number
4. Complete the password cracking mini-game
5. View SMS and call history if successful

### Radio Decryption
1. Open the hacker laptop
2. Select "Radio Decryption"
3. Complete the decryption mini-game
4. If successful, gain temporary access to police radio communications

### Vehicle Remote Control (Elite Hackers Only)
1. Open the hacker laptop
2. Select "Vehicle Control"
3. Select a vehicle you've previously tracked
4. Choose options to unlock, start, or disable the vehicle remotely

## Skill Progression System

Players gain XP for successful hacking operations:
- Plate Lookup: 5 XP
- Phone Tracking: 10 XP
- Radio Decryption: 15 XP
- Phone Hacking: 20 XP
- Vehicle Tracking: 10 XP
- Vehicle Remote Control: 25 XP

### Hacker Levels

| Level | Name | XP Required | Features Unlocked |
|-------|------|-------------|-------------------|
| 1 | Script Kiddie | 0 | Basic Plate Lookup |
| 2 | Coder | 100 | Phone Tracking |
| 3 | Security Analyst | 250 | Radio Decryption, Vehicle Tracking |
| 4 | Elite Hacker | 500 | Phone Hacking |
| 5 | Mastermind | 1000 | Vehicle Remote Control |

## Configuration Options

The script is highly configurable via the `config/config.lua` file. Some key settings:

### General Settings
- `Config.RequireJob`: Set to true to require the hacker job to use the laptop
- `Config.JobRank`: Minimum job rank required (0 = any rank)
- `Config.UseableItem`: Enable/disable using the laptop as an item

### Skill Progression
- `Config.XPSettings`: Configure XP rewards for different activities
- `Config.LevelThresholds`: XP required to reach each level
- `Config.LevelUnlocks`: Features unlocked at each level

### Police Alerts
- `Config.AlertPolice`: Settings for police notifications
- `Config.TraceBuildUp`: Configure the trace buildup system

### Cooldowns
- Various cooldown settings to prevent spam

## Troubleshooting

### Common Issues

1. **Laptop doesn't open**:
   - Check if you have the required job (if `Config.RequireJob = true`)
   - Ensure the item is properly configured in items.lua
   - Check for script errors in the server console

2. **Plate lookup fails**:
   - Ensure your database is properly connected
   - Check if the player has the minimum hacker level
   - Verify the plate format is correct

3. **Police not being alerted**:
   - Check `Config.AlertPolice.enabled` is set to true
   - Verify your dispatch resource is compatible and properly set up

4. **XP not accumulating**:
   - Check server logs for database errors
   - Verify the player data is saving properly

### Support

For support with this resource, please join our Discord server: [Discord Invite Link]

## Compatibility

This resource is compatible with:
- QBCore Latest Version
- ESX (with minimal modifications)
- ox_inventory (toggle in config)
- Various police/dispatch systems

## Credits & License

- Created by Your Name
- Based on QBCore framework
- Icons from [Flaticon](https://www.flaticon.com)
- Contributions from the QBCore community

### License
MIT License #   q b - h a c k e r j o b  
 