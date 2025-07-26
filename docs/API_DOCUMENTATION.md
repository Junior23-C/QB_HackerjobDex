# QB-HackerJob API Documentation

## Table of Contents
1. [API Overview](#api-overview)
2. [Server Events](#server-events)
3. [Client Events](#client-events)
4. [Commands Reference](#commands-reference)
5. [Configuration API](#configuration-api)
6. [Database Schema](#database-schema)
7. [Error Codes](#error-codes)
8. [Exports](#exports)
9. [Examples](#examples)
10. [Integration Guide](#integration-guide)

## API Overview

The QB-HackerJob system provides a comprehensive API for integrating hacking functionality into FiveM servers. The API is designed with security, performance, and extensibility in mind.

### API Principles
- **Security First**: All operations include validation and authorization
- **Event-Driven**: Asynchronous event-based communication
- **Error Handling**: Comprehensive error reporting and circuit breakers
- **Rate Limiting**: Built-in protection against abuse
- **Logging**: Complete audit trail of all operations

### Authentication & Authorization
```lua
-- All API calls require proper authentication
local function ValidateAccess(source, requiredLevel)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- Check job requirement
    if Config.RequireJob and Player.PlayerData.job.name ~= Config.HackerJobName then
        return false
    end
    
    -- Check minimum level
    if requiredLevel and GetPlayerHackerLevel(Player.PlayerData.citizenid) < requiredLevel then
        return false
    end
    
    return true
end
```

## Server Events

### Core System Events

#### qb-hackerjob:server:useItem
**Description**: Triggered when a player uses the hacking laptop item
**Parameters**:
- `source` (number): Player server ID
**Authorization**: Requires hacker job (if configured)
**Rate Limit**: Global cooldown applies

```lua
RegisterServerEvent('qb-hackerjob:server:useItem')
AddEventHandler('qb-hackerjob:server:useItem', function()
    local source = source
    
    -- Validate player and requirements
    if not ValidateAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_hacker'), 'error')
        return
    end
    
    -- Check rate limiting
    if not CheckRateLimit(source, 'global') then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.cooldown'), 'error')
        return
    end
    
    -- Open laptop interface
    TriggerClientEvent('qb-hackerjob:client:openLaptop', source)
end)
```

#### qb-hackerjob:server:logActivity
**Description**: Logs all hacking activities for audit and monitoring
**Parameters**:
- `action` (string): Type of action performed
- `target` (string): Target of the action (plate, phone, etc.)
- `success` (boolean): Whether the action succeeded
- `details` (string): Additional details about the action

```lua
RegisterServerEvent('qb-hackerjob:server:logActivity')
AddEventHandler('qb-hackerjob:server:logActivity', function(action, target, success, details)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Log to database
    MySQL.insert('INSERT INTO hacker_logs (citizenid, action, target, success, details, timestamp, ip_address, trace_level) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?)', {
        Player.PlayerData.citizenid,
        action,
        target,
        success,
        details,
        GetPlayerEndpoint(source),
        GetPlayerTrace(Player.PlayerData.citizenid)
    })
    
    -- Update trace buildup
    UpdateTraceBuildup(Player.PlayerData.citizenid, action, success)
    
    -- Award XP if successful
    if success and Config.XPEnabled then
        local xpAmount = Config.XPSettings[action] or 0
        if xpAmount > 0 then
            TriggerEvent('hackerjob:awardXP', source, xpAmount)
        end
    end
end)
```

### Plate Lookup Events

#### qb-hackerjob:server:lookupPlate
**Description**: Performs vehicle plate lookup in database
**Parameters**:
- `plate` (string): Vehicle plate number to lookup
**Returns**: Vehicle information object
**Rate Limit**: 30 seconds default
**Required Level**: 1 (Script Kiddie)

```lua
RegisterServerEvent('qb-hackerjob:server:lookupPlate')
AddEventHandler('qb-hackerjob:server:lookupPlate', function(plate)
    local source = source
    
    -- Validate input
    if not ValidatePlate(plate) then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.invalid_plate'), 'error')
        return
    end
    
    -- Check authorization and rate limit
    if not ValidateAccess(source, 1) or not CheckRateLimit(source, 'lookup') then
        return
    end
    
    -- Perform lookup with circuit breaker protection
    if not CheckCircuitBreaker('database') then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.system_overload'), 'error')
        return
    end
    
    -- Check cache first
    local cacheKey = 'plate_' .. plate:upper()
    local cachedResult = GetFromCache(cacheKey)
    
    if cachedResult then
        TriggerClientEvent('qb-hackerjob:client:plateResult', source, cachedResult)
        TriggerEvent('qb-hackerjob:server:logActivity', 'plateLookup', plate, true, 'Cache hit')
        return
    end
    
    -- Database query
    MySQL.query('SELECT pv.*, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ?', {
        plate:upper()
    }, function(result)
        if result and #result > 0 then
            local vehicleData = ProcessVehicleData(result[1])
            SetCache(cacheKey, vehicleData, Config.CacheExpiry)
            TriggerClientEvent('qb-hackerjob:client:plateResult', source, vehicleData)
            TriggerEvent('qb-hackerjob:server:logActivity', 'plateLookup', plate, true, 'Database hit')
            RecordSuccess('database')
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t('error.vehicle_not_found'), 'error')
            TriggerEvent('qb-hackerjob:server:logActivity', 'plateLookup', plate, false, 'Vehicle not found')
        end
    end)
end)
```

#### qb-hackerjob:server:flagVehicle
**Description**: Flags a vehicle in the database
**Parameters**:
- `plate` (string): Vehicle plate to flag
- `flag` (string): Type of flag to add
- `reason` (string): Reason for flagging
**Authorization**: Admin level 2+

### Phone Tracking Events

#### qb-hackerjob:server:trackPhone
**Description**: Tracks a player's phone location
**Parameters**:
- `phoneNumber` (string): Phone number to track
**Returns**: Location data if successful
**Rate Limit**: 45 seconds default
**Required Level**: 2 (Coder)

```lua
RegisterServerEvent('qb-hackerjob:server:trackPhone')
AddEventHandler('qb-hackerjob:server:trackPhone', function(phoneNumber)
    local source = source
    
    -- Validate input
    if not ValidatePhoneNumber(phoneNumber) then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.invalid_input'), 'error')
        return
    end
    
    -- Check authorization and rate limit
    if not ValidateAccess(source, 2) or not CheckRateLimit(source, 'phoneTrack') then
        return
    end
    
    -- Find target player
    local targetPlayer = GetPlayerByPhoneNumber(phoneNumber)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.target_offline'), 'error')
        TriggerEvent('qb-hackerjob:server:logActivity', 'phoneTrack', phoneNumber, false, 'Target offline')
        return
    end
    
    -- Get target location with accuracy modifier
    local targetCoords = GetEntityCoords(GetPlayerPed(targetPlayer.source))
    local accuracy = Config.PhoneTrackAccuracy
    
    -- Add random offset for realism
    local offsetX = math.random(-accuracy, accuracy)
    local offsetY = math.random(-accuracy, accuracy)
    
    local approximateLocation = {
        x = targetCoords.x + offsetX,
        y = targetCoords.y + offsetY,
        z = targetCoords.z,
        accuracy = accuracy
    }
    
    -- Send result to client
    TriggerClientEvent('qb-hackerjob:client:phoneTrackResult', source, approximateLocation)
    
    -- Notify target (chance based)
    if math.random(100) <= Config.AlertPolice.phoneTrackChance then
        TriggerClientEvent('QBCore:Notify', targetPlayer.source, 'Your phone signal was accessed', 'error')
        TriggerEvent('qb-hackerjob:server:alertTracked', targetPlayer.source)
    end
    
    TriggerEvent('qb-hackerjob:server:logActivity', 'phoneTrack', phoneNumber, true, 'Successfully tracked phone')
end)
```

### Radio Decryption Events

#### qb-hackerjob:server:decryptRadio
**Description**: Attempts to decrypt police radio frequencies
**Parameters**:
- `frequency` (string): Radio frequency to decrypt
**Returns**: Decrypted messages if successful
**Rate Limit**: 90 seconds default
**Required Level**: 3 (Security Analyst)

### Phone Hacking Events

#### qb-hackerjob:server:hackPhone
**Description**: Hacks into a phone to access messages and calls
**Parameters**:
- `phoneNumber` (string): Phone number to hack
- `password` (string): Cracked password
**Returns**: Phone data (messages, calls)
**Rate Limit**: 300 seconds default
**Required Level**: 4 (Elite Hacker)

### Vehicle Control Events

#### qb-hackerjob:server:controlVehicle
**Description**: Remotely controls tracked vehicles
**Parameters**:
- `plate` (string): Vehicle plate to control
- `action` (string): Control action (lock, unlock, engine, disable)
**Rate Limit**: 600 seconds default
**Required Level**: 5 (Mastermind)

## Client Events

### Laptop Interface Events

#### qb-hackerjob:client:openLaptop
**Description**: Opens the hacking laptop interface
**Triggered By**: Server after validation

```lua
RegisterNetEvent('qb-hackerjob:client:openLaptop')
AddEventHandler('qb-hackerjob:client:openLaptop', function()
    -- Check if player has laptop
    local hasLaptop = QBCore.Functions.HasItem(Config.LaptopItem)
    if not hasLaptop then
        QBCore.Functions.Notify(Lang:t('error.no_laptop'), 'error')
        return
    end
    
    -- Set NUI focus and display laptop
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openLaptop',
        playerData = {
            level = GetPlayerLevel(),
            xp = GetPlayerXP(),
            battery = GetBatteryLevel(),
            features = GetUnlockedFeatures()
        }
    })
    
    -- Start laptop session
    laptopOpen = true
    StartLaptopSession()
end)
```

#### qb-hackerjob:client:plateResult
**Description**: Receives plate lookup results
**Parameters**:
- `vehicleData` (object): Vehicle information

```lua
RegisterNetEvent('qb-hackerjob:client:plateResult')
AddEventHandler('qb-hackerjob:client:plateResult', function(vehicleData)
    SendNUIMessage({
        action = 'displayPlateResult',
        data = vehicleData
    })
end)
```

### Notification Events

#### qb-hackerjob:client:notify
**Description**: Displays notifications to the client
**Parameters**:
- `message` (string): Notification message
- `type` (string): Notification type (success, error, info)

#### qb-hackerjob:client:policeAlert
**Description**: Triggers police alert for suspicious activity
**Parameters**:
- `location` (vector3): Location of activity
- `alertType` (string): Type of alert

## Commands Reference

### User Commands

#### /hackerlaptop
**Description**: Opens the hacking laptop (if item mode disabled)
**Usage**: `/hackerlaptop`
**Aliases**: `/laptop`, `/hack`
**Requirements**: Hacker job (if configured)

```lua
RegisterCommand('hackerlaptop', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Check job requirement
    if Config.RequireJob and Player.PlayerData.job.name ~= Config.HackerJobName then
        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_hacker'), 'error')
        return
    end
    
    TriggerEvent('qb-hackerjob:server:useItem', source)
end, false)
```

#### /checkxp
**Description**: Check current hacker XP and level
**Usage**: `/checkxp`

```lua
RegisterCommand('checkxp', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local xpData = GetPlayerXPData(Player.PlayerData.citizenid)
    if xpData then
        local message = string.format('Hacker Level: %d (%s) | XP: %d/%d', 
            xpData.level, 
            Config.LevelNames[xpData.level], 
            xpData.xp, 
            Config.LevelThresholds[xpData.level + 1] or 'MAX'
        )
        TriggerClientEvent('QBCore:Notify', source, message, 'info')
    end
end, false)
```

### Administrative Commands

#### /givehackerlaptop [player_id]
**Description**: Give hacking laptop to a player
**Usage**: `/givehackerlaptop 1`
**Permission**: Admin level 2+

#### /hackerlevel [player_id] [level]
**Description**: Set player's hacker level
**Usage**: `/hackerlevel 1 5`
**Permission**: Admin level 3+
**Parameters**:
- `player_id`: Target player's server ID
- `level`: Level to set (1-5)

#### /hackerxp [player_id] [amount]
**Description**: Give XP to a player
**Usage**: `/hackerxp 1 100`
**Permission**: Admin level 2+

#### /hackerlogs [count] [filter]
**Description**: View hacking logs
**Usage**: `/hackerlogs 50 failed`
**Permission**: Admin level 1+
**Filters**: all, success, failed, suspicious

#### /hackerstatus
**Description**: Get system status and metrics
**Usage**: `/hackerstatus`
**Permission**: Admin level 1+

## Configuration API

### Core Configuration
```lua
-- Example configuration structure
Config = {
    -- Job Settings
    HackerJobName = 'hacker',
    RequireJob = true,
    JobRank = 0,
    
    -- Item Settings
    LaptopItem = 'hacker_laptop',
    UsableItem = true,
    
    -- Rate Limiting
    Cooldowns = {
        global = 5000,
        lookup = 20000,
        phoneTrack = 30000,
        radioDecrypt = 60000,
        phoneHack = 120000,
        vehicleHack = 180000
    },
    
    -- XP System
    XPEnabled = true,
    XPSettings = {
        plateLookup = 5,
        phoneTrack = 10,
        radioDecrypt = 15,
        phoneHack = 20,
        vehicleTrack = 10,
        vehicleControl = 25
    }
}
```

### Runtime Configuration Updates
```lua
-- Update configuration at runtime
exports['qb-hackerjob']:UpdateConfig(key, value)

-- Example usage
exports['qb-hackerjob']:UpdateConfig('Cooldowns.lookup', 25000)
```

## Database Schema

### hacker_logs Table
```sql
CREATE TABLE `hacker_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `action` varchar(100) NOT NULL,
  `target` varchar(100) DEFAULT NULL,
  `success` tinyint(1) DEFAULT 0,
  `details` text DEFAULT NULL,
  `timestamp` timestamp DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(45) DEFAULT NULL,
  `trace_level` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_action` (`action`),
  KEY `idx_success` (`success`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### hacker_skills Table
```sql
CREATE TABLE `hacker_skills` (
  `citizenid` varchar(50) NOT NULL,
  `xp` int(11) DEFAULT 0,
  `level` int(11) DEFAULT 1,
  `last_updated` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_level` (`level`),
  KEY `idx_xp` (`xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### hacker_security_logs Table
```sql
CREATE TABLE `hacker_security_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `event_type` varchar(100) NOT NULL,
  `threat_level` int(11) DEFAULT 1,
  `details` text DEFAULT NULL,
  `admin_action` varchar(255) DEFAULT NULL,
  `timestamp` timestamp DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_threat_level` (`threat_level`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Error Codes

### System Error Codes
```lua
local ERROR_CODES = {
    -- Authentication Errors (1000-1099)
    NOT_AUTHORIZED = { code = 1001, message = "User not authorized for this action" },
    INVALID_JOB = { code = 1002, message = "Invalid job for hacker operations" },
    INSUFFICIENT_LEVEL = { code = 1003, message = "Insufficient hacker level" },
    
    -- Rate Limiting Errors (1100-1199)
    RATE_LIMITED = { code = 1101, message = "Rate limit exceeded" },
    COOLDOWN_ACTIVE = { code = 1102, message = "Action on cooldown" },
    TOO_MANY_ATTEMPTS = { code = 1103, message = "Too many failed attempts" },
    
    -- Input Validation Errors (1200-1299)
    INVALID_PLATE = { code = 1201, message = "Invalid plate format" },
    INVALID_PHONE = { code = 1202, message = "Invalid phone number format" },
    INVALID_FREQUENCY = { code = 1203, message = "Invalid radio frequency" },
    
    -- Database Errors (1300-1399)
    DB_CONNECTION_FAILED = { code = 1301, message = "Database connection failed" },
    DB_QUERY_TIMEOUT = { code = 1302, message = "Database query timeout" },
    DB_CONSTRAINT_VIOLATION = { code = 1303, message = "Database constraint violation" },
    
    -- System Errors (1400-1499)
    CIRCUIT_BREAKER_OPEN = { code = 1401, message = "Circuit breaker open - service unavailable" },
    MEMORY_LIMIT_EXCEEDED = { code = 1402, message = "Memory limit exceeded" },
    SYSTEM_OVERLOADED = { code = 1403, message = "System overloaded" },
    
    -- Feature Errors (1500-1599)
    FEATURE_DISABLED = { code = 1501, message = "Feature is disabled" },
    MAINTENANCE_MODE = { code = 1502, message = "System in maintenance mode" },
    FEATURE_NOT_AVAILABLE = { code = 1503, message = "Feature not available" }
}
```

### Error Handling
```lua
local function HandleError(errorCode, context, source)
    local error = ERROR_CODES[errorCode]
    if not error then
        error = { code = 9999, message = "Unknown error" }
    end
    
    -- Log error
    LogError('ERROR', string.format('[%d] %s', error.code, error.message), context)
    
    -- Notify client
    if source then
        TriggerClientEvent('QBCore:Notify', source, error.message, 'error')
    end
    
    return error
end
```

## Exports

### Server Exports

#### GetPlayerHackerData
**Description**: Get comprehensive hacker data for a player
**Parameters**:
- `citizenid` (string): Player's citizen ID
**Returns**: Player hacker data object

```lua
-- Export definition
exports('GetPlayerHackerData', function(citizenid)
    return MySQL.query.await('SELECT * FROM hacker_skills WHERE citizenid = ?', {citizenid})[1]
end)

-- Usage
local hackerData = exports['qb-hackerjob']:GetPlayerHackerData(citizenid)
```

#### AwardXP
**Description**: Award XP to a player
**Parameters**:
- `source` (number): Player server ID
- `amount` (number): XP amount to award

```lua
exports('AwardXP', function(source, amount)
    TriggerEvent('hackerjob:awardXP', source, amount)
end)
```

#### CheckHackerLevel
**Description**: Check if player meets minimum hacker level
**Parameters**:
- `citizenid` (string): Player's citizen ID
- `requiredLevel` (number): Required level
**Returns**: Boolean

```lua
exports('CheckHackerLevel', function(citizenid, requiredLevel)
    local data = GetPlayerHackerData(citizenid)
    return data and data.level >= requiredLevel
end)
```

### Client Exports

#### IsLaptopOpen
**Description**: Check if laptop interface is currently open
**Returns**: Boolean

```lua
exports('IsLaptopOpen', function()
    return laptopOpen
end)
```

#### GetPlayerLevel
**Description**: Get current player's hacker level
**Returns**: Number

```lua
exports('GetPlayerLevel', function()
    return playerLevel or 1
end)
```

## Examples

### Basic Integration Example
```lua
-- Check if player can perform advanced hacking
local function CanPerformAdvancedHack(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- Check hacker level via export
    local hasLevel = exports['qb-hackerjob']:CheckHackerLevel(Player.PlayerData.citizenid, 4)
    
    return hasLevel
end

-- Award XP for custom action
local function RewardCustomHacking(source, difficulty)
    local xpAmount = difficulty * 10 -- Scale XP by difficulty
    exports['qb-hackerjob']:AwardXP(source, xpAmount)
end
```

### Custom Phone Tracking
```lua
-- Custom phone tracking implementation
RegisterServerEvent('myresource:trackPhone')
AddEventHandler('myresource:trackPhone', function(phoneNumber)
    local source = source
    
    -- Use hacker job validation
    if not exports['qb-hackerjob']:CheckHackerLevel(GetPlayerCitizenId(source), 2) then
        TriggerClientEvent('QBCore:Notify', source, 'Insufficient hacker level', 'error')
        return
    end
    
    -- Perform tracking logic
    -- ... custom implementation
    
    -- Award XP using export
    exports['qb-hackerjob']:AwardXP(source, 10)
end)
```

### Database Query Example
```lua
-- Get hacking statistics for a player
local function GetPlayerHackingStats(citizenid)
    local query = [[
        SELECT 
            action,
            COUNT(*) as total_attempts,
            COUNT(CASE WHEN success = 1 THEN 1 END) as successful_attempts,
            MAX(timestamp) as last_activity
        FROM hacker_logs 
        WHERE citizenid = ?
        GROUP BY action
    ]]
    
    return MySQL.query.await(query, {citizenid})
end
```

## Integration Guide

### QBCore Integration
```lua
-- Register items in qb-core/shared/items.lua
['hacker_laptop'] = {
    ['name'] = 'hacker_laptop',
    ['label'] = 'Hacking Laptop',
    ['weight'] = 2000,
    ['type'] = 'item',
    ['image'] = 'hacker_laptop.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'A specialized laptop for hacking operations'
}
```

### Custom Dispatch Integration
```lua
-- Integration with custom dispatch systems
RegisterNetEvent('qb-hackerjob:server:customPoliceAlert')
AddEventHandler('qb-hackerjob:server:customPoliceAlert', function(alertData)
    -- Forward to your dispatch system
    TriggerEvent('your-dispatch:server:CreateAlert', {
        type = 'hacking',
        coords = alertData.coords,
        message = alertData.message,
        priority = alertData.priority
    })
end)
```

### Phone System Integration
```lua
-- Integration with phone systems
local function GetPhoneMessages(phoneNumber)
    -- Integration with qb-phone or other phone systems
    local messages = exports['qb-phone']:GetMessages(phoneNumber)
    return messages
end
```

### Performance Monitoring Integration
```lua
-- Integration with monitoring systems
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        local metrics = exports['qb-hackerjob']:GetPerformanceMetrics()
        
        -- Send to your monitoring system
        TriggerEvent('your-monitoring:updateMetrics', 'hackerjob', metrics)
    end
end)
```

---

## Conclusion

This API documentation provides comprehensive coverage of all QB-HackerJob system interfaces. The API is designed for security, performance, and ease of integration with existing FiveM resources.

For additional examples and advanced usage patterns, refer to the source code and the Administrator Guide for operational procedures.

**Security Note**: Always validate inputs and check authorization before performing sensitive operations. The built-in validation functions should be used for all user inputs.