# QB-HackerJob Administrator Guide

## Table of Contents
1. [Administrative Overview](#administrative-overview)
2. [Admin Commands Reference](#admin-commands-reference)
3. [Monitoring and Analytics](#monitoring-and-analytics)
4. [Performance Management](#performance-management)
5. [User Management](#user-management)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Security Monitoring](#security-monitoring)
8. [Maintenance Procedures](#maintenance-procedures)
9. [Incident Response](#incident-response)
10. [Best Practices](#best-practices)

## Administrative Overview

The QB-HackerJob system provides comprehensive administrative tools for monitoring, managing, and maintaining the hacker job functionality. This guide covers all aspects of day-to-day administration and emergency procedures.

### Administrative Responsibilities
- **System Monitoring**: Track performance, errors, and user activity
- **User Management**: Manage player progression, resolve issues
- **Security Oversight**: Monitor for abuse, implement security measures
- **Performance Optimization**: Ensure optimal system performance
- **Incident Response**: Handle security incidents and system failures

### Access Levels
```lua
-- Administrative access levels
local ADMIN_PERMISSIONS = {
    ['god'] = {
        level = 4,
        permissions = {'all'}
    },
    ['admin'] = {
        level = 3,
        permissions = {'view_logs', 'manage_users', 'system_control'}
    },
    ['moderator'] = {
        level = 2,
        permissions = {'view_logs', 'manage_users'}
    },
    ['support'] = {
        level = 1,
        permissions = {'view_logs'}
    }
}
```

## Admin Commands Reference

### Core Administrative Commands

#### User Management Commands
```lua
-- Give hacker laptop to player
/givehackerlaptop [player_id]
-- Usage: /givehackerlaptop 1
-- Requires: Admin level 2+

-- Set player hacker level
/hackerlevel [player_id] [level]
-- Usage: /hackerlevel 1 5
-- Requires: Admin level 3+
-- Levels: 1-5 (Script Kiddie to Mastermind)

-- Give XP to player
/hackerxp [player_id] [amount]
-- Usage: /hackerxp 1 100
-- Requires: Admin level 2+

-- Reset player hacker progress
/resetHackerProgress [player_id]
-- Usage: /resetHackerProgress 1
-- Requires: Admin level 3+
-- WARNING: This permanently deletes all progress
```

#### Monitoring Commands
```lua
-- View recent hacking logs
/hackerlogs [count] [filter]
-- Usage: /hackerlogs 50 failed
-- Filters: all, success, failed, suspicious
-- Requires: Admin level 1+

-- Get system status
/hackerstatus
-- Shows: Active users, system health, performance metrics
-- Requires: Admin level 1+

-- View active hacking sessions
/activehackers
-- Shows: Currently active users and their activities
-- Requires: Admin level 2+

-- Get player hacker info
/hackerinfo [player_id]
-- Usage: /hackerinfo 1
-- Shows: Level, XP, recent activity, current trace
-- Requires: Admin level 1+
```

#### System Control Commands
```lua
-- Toggle system maintenance mode
/hackermaintenance [on/off]
-- Usage: /hackermaintenance on
-- Disables hacking for all non-admin users
-- Requires: Admin level 3+

-- Reload configuration
/reloadhackerconfig
-- Reloads config files without restart
-- Requires: Admin level 3+

-- Clear system cache
/clearhackercache
-- Clears all cached data (plates, phones, etc.)
-- Requires: Admin level 3+

-- Force garbage collection
/hackergc
-- Forces Lua garbage collection
-- Requires: Admin level 3+
```

#### Security Commands
```lua
-- Ban player from hacking system
/banHacker [player_id] [reason]
-- Usage: /banHacker 1 "Exploit attempts"
-- Requires: Admin level 3+

-- Unban player from hacking system
/unbanHacker [player_id]
-- Usage: /unbanHacker 1
-- Requires: Admin level 3+

-- View security alerts
/securityalerts [hours]
-- Usage: /securityalerts 24
-- Shows security alerts from last N hours
-- Requires: Admin level 2+

-- Reset player trace
/resettrace [player_id]
-- Usage: /resettrace 1
-- Resets trace buildup to 0
-- Requires: Admin level 2+
```

### Emergency Commands
```lua
-- Emergency shutdown
/emergencyShutdownHacker
-- Immediately disables all hacking functionality
-- Requires: Admin level 4 (God)

-- Force unlock all vehicles (emergency)
/emergencyUnlockAll
-- Unlocks all remotely locked vehicles
-- Requires: Admin level 4 (God)

-- System panic mode
/hackerPanic
-- Activates emergency protocols
-- Requires: Admin level 4 (God)
```

## Monitoring and Analytics

### Real-Time Monitoring Dashboard
```lua
-- Access monitoring data
RegisterServerEvent('qb-hackerjob:admin:getMetrics')
AddEventHandler('qb-hackerjob:admin:getMetrics', function()
    local source = source
    if not ValidateAdminAccess(source, 1) then return end
    
    local metrics = {
        activeUsers = GetActiveHackers(),
        systemHealth = GetSystemHealth(),
        performance = GetPerformanceMetrics(),
        recentActivity = GetRecentActivity(60), -- Last 60 minutes
        errorCount = GetErrorCount(),
        cacheHitRatio = GetCacheHitRatio(),
        databaseHealth = GetDatabaseHealth()
    }
    
    TriggerClientEvent('qb-hackerjob:admin:metricsResponse', source, metrics)
end)
```

### Key Performance Indicators

#### System Health Metrics
- **Active Users**: Current number of players using hacking tools
- **Database Response Time**: Average query execution time
- **Memory Usage**: Current memory consumption
- **Cache Hit Ratio**: Percentage of requests served from cache
- **Error Rate**: Percentage of failed operations
- **Uptime**: System uptime since last restart

#### User Activity Metrics
- **Daily Active Users**: Unique users per day
- **Operations per Hour**: Number of hacking attempts
- **Success Rate**: Percentage of successful operations
- **Average Session Duration**: Time users spend hacking
- **Most Popular Features**: Usage statistics by feature

#### Security Metrics
- **Failed Attempts**: Number of failed hacking attempts
- **Trace Levels**: Distribution of user trace levels
- **Police Alerts**: Number of alerts generated
- **Suspicious Activity**: Flagged activities requiring review
- **Ban Statistics**: Number of banned users and reasons

### Analytics Queries
```sql
-- Daily usage statistics
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as total_attempts,
    COUNT(CASE WHEN success = 1 THEN 1 END) as successful_attempts,
    COUNT(DISTINCT citizenid) as unique_users,
    AVG(trace_level) as avg_trace_level
FROM hacker_logs 
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Most active users
SELECT 
    citizenid,
    COUNT(*) as total_attempts,
    COUNT(CASE WHEN success = 1 THEN 1 END) as successful_attempts,
    MAX(timestamp) as last_activity,
    AVG(trace_level) as avg_trace_level
FROM hacker_logs 
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY citizenid
ORDER BY total_attempts DESC
LIMIT 20;

-- Feature usage statistics
SELECT 
    action,
    COUNT(*) as usage_count,
    COUNT(CASE WHEN success = 1 THEN 1 END) as success_count,
    ROUND(AVG(CASE WHEN success = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) as success_rate
FROM hacker_logs 
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY action
ORDER BY usage_count DESC;
```

## Performance Management

### Performance Monitoring
```lua
-- Performance monitoring thread
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        local metrics = {
            memory = collectgarbage("count"),
            activeUsers = #GetActivePlayers(),
            cacheSize = GetCacheSize(),
            databaseQueries = GetQueryCount(),
            averageQueryTime = GetAverageQueryTime(),
            errorCount = GetErrorCount()
        }
        
        -- Log performance metrics
        if Config.Production.performanceMonitoring then
            LogPerformanceMetrics(metrics)
        end
        
        -- Alert if thresholds exceeded
        CheckPerformanceThresholds(metrics)
    end
end)
```

### Performance Optimization Commands
```lua
-- Manual performance optimization
RegisterCommand('optimizeHacker', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 3) then return end
    
    -- Clear old cache entries
    ClearExpiredCache()
    
    -- Force garbage collection
    collectgarbage('collect')
    
    -- Optimize database
    OptimizeDatabaseTables()
    
    -- Report results
    TriggerClientEvent('QBCore:Notify', source, 'System optimization completed', 'success')
end, true)
```

### Performance Thresholds
```lua
local PERFORMANCE_THRESHOLDS = {
    memory_usage_mb = 512,        -- Alert if memory > 512MB
    avg_query_time_ms = 100,      -- Alert if avg query time > 100ms
    cache_hit_ratio = 0.85,       -- Alert if cache hit ratio < 85%
    error_rate = 0.05,            -- Alert if error rate > 5%
    concurrent_users = 45,        -- Alert if concurrent users > 45
    database_connections = 8      -- Alert if DB connections > 8
}
```

## User Management

### Player Progression Management
```lua
-- View player progression
function GetPlayerHackerInfo(citizenid)
    local query = [[
        SELECT 
            hs.xp,
            hs.level,
            hs.last_updated,
            COUNT(hl.id) as total_attempts,
            COUNT(CASE WHEN hl.success = 1 THEN 1 END) as successful_attempts,
            MAX(hl.timestamp) as last_activity
        FROM hacker_skills hs
        LEFT JOIN hacker_logs hl ON hs.citizenid = hl.citizenid
        WHERE hs.citizenid = ?
        GROUP BY hs.citizenid
    ]]
    
    MySQL.query(query, {citizenid}, function(result)
        if result[1] then
            local info = result[1]
            info.success_rate = info.total_attempts > 0 and 
                               (info.successful_attempts / info.total_attempts * 100) or 0
            return info
        end
    end)
end

-- Bulk level adjustment
RegisterCommand('bulkLevelAdjust', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 4) then return end
    
    local adjustment = tonumber(args[1])
    if not adjustment then return end
    
    MySQL.query('UPDATE hacker_skills SET level = GREATEST(1, LEAST(5, level + ?))', {
        adjustment
    }, function(affectedRows)
        TriggerClientEvent('QBCore:Notify', source, 
            string.format('Adjusted %d player levels by %d', affectedRows, adjustment), 'success')
    end)
end, true)
```

### Player Activity Tracking
```lua
-- Track suspicious activity patterns
function DetectSuspiciousActivity(citizenid)
    local query = [[
        SELECT 
            action,
            COUNT(*) as count,
            MIN(timestamp) as first_attempt,
            MAX(timestamp) as last_attempt,
            COUNT(CASE WHEN success = 0 THEN 1 END) as failed_attempts
        FROM hacker_logs 
        WHERE citizenid = ? 
        AND timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
        GROUP BY action
        HAVING count > 10 OR failed_attempts > 5
    ]]
    
    MySQL.query(query, {citizenid}, function(result)
        if result and #result > 0 then
            for _, activity in ipairs(result) do
                if activity.failed_attempts > 5 then
                    TriggerEvent('qb-hackerjob:suspiciousActivity', citizenid, activity)
                end
            end
        end
    end)
end
```

### User Support Tools
```lua
-- Help desk commands for support staff
RegisterCommand('hackerSupport', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 1) then return end
    
    local subcommand = args[1]
    local playerId = tonumber(args[2])
    
    if subcommand == 'info' and playerId then
        -- Get comprehensive player info
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local info = GetPlayerHackerInfo(Player.PlayerData.citizenid)
            TriggerClientEvent('qb-hackerjob:admin:showPlayerInfo', source, info)
        end
    elseif subcommand == 'reset' and playerId then
        -- Reset player's trace level
        ResetPlayerTrace(playerId)
        TriggerClientEvent('QBCore:Notify', source, 'Player trace reset', 'success')
    elseif subcommand == 'unlock' and playerId then
        -- Unlock player's cooldowns
        ResetPlayerCooldowns(playerId)
        TriggerClientEvent('QBCore:Notify', source, 'Player cooldowns reset', 'success')
    end
end, true)
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: "Laptop won't open"
**Symptoms**: Players report laptop item not working
**Diagnosis**:
```lua
-- Check if player has required job
local Player = QBCore.Functions.GetPlayer(source)
if Config.RequireJob and Player.PlayerData.job.name ~= Config.HackerJobName then
    return false
end

-- Check if item exists in inventory
local hasLaptop = Player.Functions.GetItemByName(Config.LaptopItem)
if not hasLaptop then
    return false
end
```
**Solutions**:
1. Verify player has hacker job (if required)
2. Check if laptop item is properly configured
3. Ensure player has laptop in inventory
4. Restart qb-hackerjob resource

#### Issue: "Database queries failing"
**Symptoms**: Plate lookups returning no results
**Diagnosis**:
```sql
-- Test database connectivity
SELECT COUNT(*) FROM player_vehicles;

-- Check for missing indexes
SHOW INDEX FROM player_vehicles WHERE Key_name = 'idx_plate';

-- Check table structure
DESCRIBE player_vehicles;
```
**Solutions**:
1. Verify database connection in oxmysql
2. Add missing database indexes
3. Check table permissions for hackerjob user
4. Restart MySQL service if needed

#### Issue: "High memory usage"
**Symptoms**: Server lag, memory warnings
**Diagnosis**:
```lua
-- Check memory usage
local memoryUsage = collectgarbage("count")
print(string.format("Memory usage: %.2f MB", memoryUsage / 1024))

-- Check cache size
local cacheSize = 0
for _ in pairs(plateCache) do
    cacheSize = cacheSize + 1
end
print(string.format("Cache entries: %d", cacheSize))
```
**Solutions**:
1. Reduce cache expiry time in config
2. Implement aggressive garbage collection
3. Clear cache manually: `/clearhackercache`
4. Reduce max concurrent users

#### Issue: "Players getting banned incorrectly"
**Symptoms**: Legitimate players receiving automatic bans
**Diagnosis**:
```lua
-- Check trace buildup settings
if Config.TraceBuildUp.maxTrace < 100 then
    -- Trace limit might be too low
end

-- Check rate limiting
if Config.Cooldowns.global < 5000 then
    -- Cooldowns might be too aggressive
end
```
**Solutions**:
1. Adjust trace buildup thresholds
2. Increase cooldown periods
3. Review automatic ban logic
4. Manually unban affected players

### Diagnostic Commands
```lua
-- System diagnostics
RegisterCommand('hackerDiag', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 2) then return end
    
    local diagnostics = {
        memory_usage = collectgarbage("count"),
        cache_size = GetCacheSize(),
        database_status = TestDatabaseConnection(),
        active_users = GetActiveHackers(),
        error_count = GetErrorCount(),
        uptime = GetServerUptime(),
        config_valid = ValidateConfig()
    }
    
    TriggerClientEvent('qb-hackerjob:admin:diagnostics', source, diagnostics)
end, true)

-- Player-specific diagnostics
RegisterCommand('playerDiag', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 2) then return end
    
    local playerId = tonumber(args[1])
    if not playerId then return end
    
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local diagnostics = {
        citizenid = Player.PlayerData.citizenid,
        job = Player.PlayerData.job,
        items = Player.PlayerData.items,
        online = true,
        trace_level = GetPlayerTrace(Player.PlayerData.citizenid),
        cooldowns = GetPlayerCooldowns(Player.PlayerData.citizenid),
        recent_activity = GetRecentActivity(Player.PlayerData.citizenid, 24)
    }
    
    TriggerClientEvent('qb-hackerjob:admin:playerDiag', source, diagnostics)
end, true)
```

## Security Monitoring

### Security Alert System
```lua
-- Security monitoring thread
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds
        
        -- Check for suspicious patterns
        CheckSuspiciousActivity()
        
        -- Monitor failed attempts
        MonitorFailedAttempts()
        
        -- Check trace levels
        MonitorTraceLevels()
        
        -- Verify system integrity
        VerifySystemIntegrity()
    end
end)
```

### Automated Security Responses
```lua
-- Automatic response to security threats
function HandleSecurityThreat(citizenid, threatLevel, details)
    local responses = {
        [1] = function() -- Low threat
            -- Increase monitoring
            AddToWatchList(citizenid)
        end,
        [2] = function() -- Medium threat
            -- Temporary cooldown increase
            IncreaseCooldowns(citizenid, 2.0)
        end,
        [3] = function() -- High threat
            -- Temporary ban from hacking
            TempBanFromHacking(citizenid, 3600) -- 1 hour
        end,
        [4] = function() -- Critical threat
            -- Immediate ban and admin notification
            BanFromHacking(citizenid, "Automated security response")
            NotifyAdmins("Critical security threat detected", citizenid, details)
        end
    }
    
    if responses[threatLevel] then
        responses[threatLevel]()
        LogSecurityEvent(citizenid, threatLevel, details)
    end
end
```

### Security Audit Logs
```sql
-- Create security audit table
CREATE TABLE IF NOT EXISTS `hacker_security_logs` (
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

### Security Report Generation
```lua
-- Generate security reports
RegisterCommand('securityReport', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 2) then return end
    
    local timeframe = args[1] or '24' -- Default 24 hours
    local report = GenerateSecurityReport(tonumber(timeframe))
    
    TriggerClientEvent('qb-hackerjob:admin:securityReport', source, report)
end, true)

function GenerateSecurityReport(hours)
    local query = [[
        SELECT 
            event_type,
            threat_level,
            COUNT(*) as incident_count,
            COUNT(DISTINCT citizenid) as affected_users,
            MAX(timestamp) as latest_incident
        FROM hacker_security_logs 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        GROUP BY event_type, threat_level
        ORDER BY threat_level DESC, incident_count DESC
    ]]
    
    return MySQL.query.await(query, {hours})
end
```

## Maintenance Procedures

### Routine Maintenance Tasks

#### Daily Maintenance (Automated)
```lua
-- Daily maintenance script
CreateThread(function()
    while true do
        Wait(86400000) -- 24 hours
        
        -- Clean old logs (keep last 30 days)
        MySQL.query([[
            DELETE FROM hacker_logs 
            WHERE timestamp < DATE_SUB(NOW(), INTERVAL 30 DAY)
        ]])
        
        -- Clean old security logs (keep last 90 days)
        MySQL.query([[
            DELETE FROM hacker_security_logs 
            WHERE timestamp < DATE_SUB(NOW(), INTERVAL 90 DAY)
        ]])
        
        -- Optimize database tables
        MySQL.query('OPTIMIZE TABLE hacker_logs, hacker_skills, hacker_security_logs')
        
        -- Clear expired cache entries
        ClearExpiredCache()
        
        -- Generate daily report
        GenerateDailyReport()
        
        LogInfo("Daily maintenance completed")
    end
end)
```

#### Weekly Maintenance (Manual)
```bash
#!/bin/bash
# Weekly maintenance script

echo "Starting weekly maintenance..."

# 1. Database backup
mysqldump -u backup_user -p$BACKUP_PASS fivem_production hacker_logs hacker_skills hacker_security_logs > /backups/weekly_$(date +%Y%m%d).sql

# 2. Log rotation
find /server-data/logs/ -name "*.log" -mtime +7 -exec gzip {} \;

# 3. Performance analysis
mysql -u hackerjob_prod -p$DB_PASS -e "ANALYZE TABLE hacker_logs, hacker_skills;"

# 4. Security scan
/scripts/security_scan.sh

echo "Weekly maintenance completed"
```

#### Monthly Maintenance (Manual)
```lua
-- Monthly maintenance procedures
RegisterCommand('monthlyMaintenance', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 4) then return end
    
    -- 1. Full database optimization
    MySQL.query('OPTIMIZE TABLE hacker_logs, hacker_skills, hacker_security_logs')
    
    -- 2. Rebuild indexes
    MySQL.query('ALTER TABLE hacker_logs DROP INDEX idx_timestamp, ADD INDEX idx_timestamp (timestamp)')
    
    -- 3. Clean inactive players
    CleanInactivePlayers(90) -- Remove players inactive for 90+ days
    
    -- 4. Performance metrics analysis
    AnalyzePerformanceMetrics()
    
    -- 5. Security audit
    RunSecurityAudit()
    
    TriggerClientEvent('QBCore:Notify', source, 'Monthly maintenance completed', 'success')
end, true)
```

### Configuration Management
```lua
-- Configuration backup and restore
RegisterCommand('backupConfig', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 3) then return end
    
    local configBackup = {
        timestamp = os.time(),
        config = Config,
        productionOverrides = Config.ProductionOverrides
    }
    
    SaveConfigBackup(configBackup)
    TriggerClientEvent('QBCore:Notify', source, 'Configuration backed up', 'success')
end, true)

RegisterCommand('restoreConfig', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 4) then return end
    
    local backupId = args[1]
    if not backupId then return end
    
    local backup = LoadConfigBackup(backupId)
    if backup then
        -- Validate backup before restoring
        if ValidateConfigBackup(backup) then
            RestoreConfig(backup)
            TriggerClientEvent('QBCore:Notify', source, 'Configuration restored successfully', 'success')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Invalid configuration backup', 'error')
        end
    end
end, true)
```

## Incident Response

### Incident Classification
```lua
local INCIDENT_TYPES = {
    SECURITY_BREACH = {
        priority = 'CRITICAL',
        response_time = 300, -- 5 minutes
        escalation_level = 4
    },
    PERFORMANCE_DEGRADATION = {
        priority = 'HIGH',
        response_time = 900, -- 15 minutes
        escalation_level = 3
    },
    USER_ABUSE = {
        priority = 'MEDIUM',
        response_time = 1800, -- 30 minutes
        escalation_level = 2
    },
    CONFIGURATION_ERROR = {
        priority = 'LOW',
        response_time = 3600, -- 1 hour
        escalation_level = 1
    }
}
```

### Incident Response Procedures
```lua
-- Incident response system
function HandleIncident(incidentType, details, source)
    local incident = {
        id = GenerateIncidentId(),
        type = incidentType,
        details = details,
        timestamp = os.time(),
        source = source,
        status = 'OPEN',
        assigned_admin = nil,
        resolution = nil
    }
    
    -- Log incident
    LogIncident(incident)
    
    -- Determine response level
    local responseLevel = INCIDENT_TYPES[incidentType]
    if not responseLevel then
        responseLevel = INCIDENT_TYPES.CONFIGURATION_ERROR
    end
    
    -- Notify appropriate admins
    NotifyAdminsByLevel(responseLevel.escalation_level, incident)
    
    -- Trigger automated responses if applicable
    TriggerAutomatedResponse(incidentType, incident)
    
    return incident.id
end
```

### Emergency Procedures
```lua
-- Emergency shutdown procedure
RegisterCommand('emergencyShutdown', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 4) then return end
    
    local reason = table.concat(args, ' ') or 'Emergency shutdown initiated'
    
    -- 1. Disable all hacking functionality
    Config.Production.enabled = false
    
    -- 2. Disconnect all active users
    DisconnectAllHackers()
    
    -- 3. Lock all database operations
    LockDatabaseOperations()
    
    -- 4. Notify all admins
    NotifyAllAdmins('EMERGENCY SHUTDOWN', reason)
    
    -- 5. Log emergency action
    LogEmergencyAction('SHUTDOWN', source, reason)
    
    print('^1[EMERGENCY] Hacker system shutdown initiated by admin ' .. GetPlayerName(source))
end, true)

-- Emergency recovery procedure
RegisterCommand('emergencyRecover', function(source, args, rawCommand)
    if not ValidateAdminAccess(source, 4) then return end
    
    -- 1. Run system diagnostics
    local diagnostics = RunFullDiagnostics()
    
    -- 2. Validate configuration
    local configValid = ValidateProductionConfig()
    
    -- 3. Test database connectivity
    local dbStatus = TestDatabaseConnection()
    
    -- 4. Check for security threats
    local securityStatus = CheckSecurityStatus()
    
    if diagnostics.healthy and #configValid == 0 and dbStatus and securityStatus.clean then
        -- System is ready for recovery
        Config.Production.enabled = true
        UnlockDatabaseOperations()
        NotifyAllAdmins('EMERGENCY RECOVERY', 'System recovered successfully')
        LogEmergencyAction('RECOVERY', source, 'System recovered')
    else
        -- System not ready
        TriggerClientEvent('QBCore:Notify', source, 'System not ready for recovery', 'error')
        LogEmergencyAction('RECOVERY_FAILED', source, 'System not ready')
    end
end, true)
```

## Best Practices

### Administrative Best Practices

#### Daily Operations
1. **Monitor System Health**: Check performance metrics daily
2. **Review Security Logs**: Look for suspicious activity patterns
3. **User Support**: Respond to player issues promptly
4. **Performance Optimization**: Clear cache if memory usage is high
5. **Backup Verification**: Ensure backups are completing successfully

#### Security Best Practices
1. **Principle of Least Privilege**: Give users minimum required access
2. **Regular Security Audits**: Conduct monthly security reviews
3. **Incident Documentation**: Document all security incidents
4. **Access Control**: Regularly review admin access lists
5. **Monitoring**: Monitor for unauthorized access attempts

#### Performance Best Practices
1. **Regular Maintenance**: Follow maintenance schedules
2. **Capacity Planning**: Monitor growth trends
3. **Database Optimization**: Keep databases optimized
4. **Cache Management**: Monitor cache hit ratios
5. **Resource Monitoring**: Track CPU, memory, and disk usage

### Configuration Management
```lua
-- Best practice configuration template
local PRODUCTION_BEST_PRACTICES = {
    -- Security (NEVER compromise on these)
    debugMode = false,
    testMode = false,
    adminBypass = false,
    
    -- Performance (Optimize for your server)
    cacheEnabled = true,
    cacheExpiry = 300000, -- 5 minutes
    maxConcurrentUsers = 50, -- Adjust based on server capacity
    
    -- Rate Limiting (Prevent abuse)
    rateLimits = {
        global = 2000,      -- 2 seconds minimum between actions
        plateLookup = 30000, -- 30 seconds between lookups
        phoneTracking = 45000, -- 45 seconds between phone tracks
    },
    
    -- Monitoring (Essential for production)
    monitoring = {
        enabled = true,
        performanceMetrics = true,
        errorTracking = true,
        auditLogging = true,
    }
}
```

### Troubleshooting Methodology
1. **Identify**: Clearly define the problem
2. **Gather Information**: Collect logs, error messages, user reports
3. **Analyze**: Determine root cause
4. **Test**: Verify solution in staging environment
5. **Implement**: Apply fix in production
6. **Verify**: Confirm issue is resolved
7. **Document**: Record solution for future reference

### Communication Protocols
```lua
-- Admin notification system
function NotifyAdmins(level, message, details)
    local admins = GetOnlineAdmins(level)
    
    for _, admin in ipairs(admins) do
        TriggerClientEvent('qb-hackerjob:admin:notification', admin.source, {
            level = level,
            message = message,
            details = details,
            timestamp = os.time()
        })
    end
    
    -- Send to Discord if configured
    if Config.Logging.discordWebhook.enabled then
        SendDiscordNotification(level, message, details)
    end
end
```

---

## Conclusion

This administrator guide provides comprehensive procedures for managing the QB-HackerJob system in a production environment. Regular monitoring, proactive maintenance, and adherence to security best practices ensure optimal system performance and user experience.

For technical implementation details, refer to the API Documentation. For security-specific procedures, consult the Security Documentation.

Remember: Always prioritize security and user experience in administrative decisions.