# QB-HackerJob Production Deployment Guide

## Table of Contents
1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [System Requirements](#system-requirements)
3. [Installation Procedures](#installation-procedures)
4. [Production Configuration](#production-configuration)
5. [Security Hardening](#security-hardening)
6. [Performance Optimization](#performance-optimization)
7. [Database Setup](#database-setup)
8. [Testing and Validation](#testing-and-validation)
9. [Go-Live Checklist](#go-live-checklist)
10. [Rollback Procedures](#rollback-procedures)

## Pre-Deployment Requirements

### Framework Dependencies
Ensure the following resources are installed and running:
- **qb-core**: Latest stable version (v1.1.0+)
- **oxmysql**: Latest version for database operations
- **qb-input**: For user input dialogs
- **qb-menu**: For interactive menus
- **qb-phone**: Required for phone tracking features

### Server Requirements
- **CPU**: Minimum 4 cores, recommended 8+ cores
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: SSD recommended for database performance
- **Network**: Stable connection with low latency
- **MySQL**: Version 8.0+ or MariaDB 10.5+

### Administrative Access
- Server console access
- Database administrative privileges
- FTP/SSH access to server files
- Discord webhook setup (optional)

## System Requirements

### Minimum System Specifications
```
OS: Windows Server 2019+ / Linux Ubuntu 20.04+
CPU: 4 cores @ 2.4GHz
RAM: 8GB
Storage: 100GB SSD
Network: 100Mbps uplink
Database: MySQL 8.0+
```

### Recommended Production Specifications
```
OS: Linux Ubuntu 22.04 LTS
CPU: 8+ cores @ 3.0GHz+
RAM: 32GB+
Storage: 500GB NVMe SSD
Network: 1Gbps uplink
Database: MySQL 8.0+ with dedicated server
Load Balancer: Nginx/Apache for multiple instances
```

## Installation Procedures

### Step 1: Pre-Installation Validation
```bash
# Verify server resources
free -h
df -h
top

# Check MySQL connectivity
mysql -u username -p -e "SELECT VERSION();"

# Verify FiveM server status
# Check server console for errors
```

### Step 2: Resource Deployment
```bash
# 1. Stop the FiveM server
# 2. Backup existing resources
cp -r resources/qb-hackerjob resources/qb-hackerjob.backup.$(date +%Y%m%d)

# 3. Deploy new resource files
# Upload QB_HackerjobDex to resources/qb-hackerjob/

# 4. Set proper permissions
chmod -R 755 resources/qb-hackerjob/
chown -R fivem:fivem resources/qb-hackerjob/
```

### Step 3: Database Configuration
```sql
-- Create hacker_logs table for audit trail
CREATE TABLE IF NOT EXISTS `hacker_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `action` varchar(100) NOT NULL,
  `target` varchar(100) DEFAULT NULL,
  `success` tinyint(1) DEFAULT 0,
  `timestamp` timestamp DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(45) DEFAULT NULL,
  `trace_level` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create hacker_skills table for progression
CREATE TABLE IF NOT EXISTS `hacker_skills` (
  `citizenid` varchar(50) NOT NULL,
  `xp` int(11) DEFAULT 0,
  `level` int(11) DEFAULT 1,
  `last_updated` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add indexes for performance
ALTER TABLE `player_vehicles` ADD INDEX `idx_plate` (`plate`);
ALTER TABLE `players` ADD INDEX `idx_citizenid` (`citizenid`);
```

### Step 4: Configuration Files Setup
```lua
-- config/production.lua should be configured with:
Config.ProductionOverrides = {
    debugMode = false,              -- CRITICAL: Never enable in production
    testMode = false,               -- Disable all test features
    adminBypass = false,            -- Disable admin bypass
    
    -- Production rate limits
    rateLimits = {
        global = 2000,              -- 2 second global cooldown
        plateLookup = 30000,        -- 30 seconds
        phoneTracking = 45000,      -- 45 seconds
        radioDecryption = 90000,    -- 1.5 minutes
        phoneHacking = 300000,      -- 5 minutes
        vehicleControl = 600000,    -- 10 minutes
    },
    
    -- Error handling
    errorLogging = true,
    maxRetries = 3,
    
    -- Resource limits
    maxConcurrentUsers = 50,
    maxCacheSize = 1000,
    
    -- Security
    security = {
        inputValidation = true,
        sqlInjectionPrevention = true,
        xssProtection = true,
        rateLimitingStrict = true,
        authorizationChecks = true,
    }
}
```

## Production Configuration

### Core Settings Validation
```lua
-- Critical production settings that MUST be configured:

-- Security Settings (NEVER change in production)
Config.Production.debugMode = false
Config.Production.performanceMonitoring = true
Config.Production.rateLimiting = true

-- Database Settings
Config.DatabaseMaxRetries = 3
Config.PlateQueryTimeout = 10000

-- UI Optimizations
Config.UISettings.showAnimations = false
Config.UISettings.soundEffects = false
```

### Environment-Specific Configuration
```bash
# Production environment variables
export MYSQL_HOST="your_db_server"
export MYSQL_USER="hackerjob_user"
export MYSQL_PASS="secure_password_here"
export MYSQL_DB="fivem_production"

# Security environment variables
export DISCORD_WEBHOOK_URL="your_webhook_url"
export ADMIN_WHITELIST="admin1,admin2,admin3"
```

### Server.cfg Configuration
```bash
# Add to server.cfg
ensure oxmysql
ensure qb-core
ensure qb-input
ensure qb-menu
ensure qb-phone
ensure qb-hackerjob

# Performance settings
set mysql_connection_string "mysql://user:password@host/database?charset=utf8mb4"
set sv_maxClients 128
set sv_enforceGameBuild 2944
```

## Security Hardening

### Access Control Implementation
```lua
-- Implement role-based access control
local ADMIN_ROLES = {
    'god',
    'admin',
    'superadmin'
}

local function ValidateAdminAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local group = QBCore.Functions.GetPermission(source)
    return table.contains(ADMIN_ROLES, group)
end
```

### Input Validation
All user inputs are validated using:
```lua
-- Phone number validation
local function ValidatePhoneNumber(phone)
    if not phone or type(phone) ~= 'string' then return false end
    if #phone < 7 or #phone > 15 then return false end
    if not phone:match('^[0-9]+$') then return false end
    return true
end

-- Plate validation
local function ValidatePlate(plate)
    if not plate or type(plate) ~= 'string' then return false end
    if #plate < 2 or #plate > 8 then return false end
    if not plate:match('^[A-Z0-9]+$') then return false end
    return true
end
```

### SQL Injection Prevention
All database queries use parameterized statements:
```lua
-- Safe database query example
MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? LIMIT 1', {
    plate:upper()
}, function(result)
    -- Handle result
end)
```

### Rate Limiting Implementation
```lua
-- Global rate limiting with trace buildup
local rateLimitCache = {}
local traceBuildup = {}

local function CheckRateLimit(source, action)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local citizenid = Player.PlayerData.citizenid
    local currentTime = os.time()
    
    -- Check rate limit
    if rateLimitCache[citizenid] and 
       rateLimitCache[citizenid][action] and
       rateLimitCache[citizenid][action] > currentTime then
        return false
    end
    
    -- Update rate limit
    if not rateLimitCache[citizenid] then
        rateLimitCache[citizenid] = {}
    end
    rateLimitCache[citizenid][action] = currentTime + Config.Cooldowns[action]
    
    return true
end
```

## Performance Optimization

### Database Optimizations
```sql
-- Production database optimizations
-- 1. Enable query cache
SET GLOBAL query_cache_type = ON;
SET GLOBAL query_cache_size = 256M;

-- 2. Optimize InnoDB settings
SET GLOBAL innodb_buffer_pool_size = 2G;
SET GLOBAL innodb_log_file_size = 256M;
SET GLOBAL innodb_flush_log_at_trx_commit = 2;

-- 3. Add essential indexes
CREATE INDEX idx_hacker_logs_timestamp ON hacker_logs(timestamp);
CREATE INDEX idx_hacker_logs_citizenid_action ON hacker_logs(citizenid, action);
CREATE INDEX idx_player_vehicles_plate_owner ON player_vehicles(plate, citizenid);
```

### Memory Management
```lua
-- Automatic memory cleanup
CreateThread(function()
    while true do
        Wait(Config.ProductionOverrides.memoryCleanupInterval)
        
        -- Clean old cache entries
        local currentTime = GetGameTimer()
        for key, entry in pairs(plateCache) do
            if currentTime - entry.timestamp > Config.CacheExpiry then
                plateCache[key] = nil
            end
        end
        
        -- Force garbage collection
        collectgarbage('collect')
        
        LogInfo("Memory cleanup completed")
    end
end)
```

### UI Performance Optimization
```lua
-- Batch UI updates for better performance
local uiUpdateQueue = {}
local lastUIUpdate = 0

CreateThread(function()
    while true do
        Wait(Config.UISettings.updateInterval)
        
        if #uiUpdateQueue > 0 then
            -- Process all queued updates at once
            SendNUIMessage({
                action = 'batchUpdate',
                updates = uiUpdateQueue
            })
            uiUpdateQueue = {}
        end
    end
end)
```

## Database Setup

### Production Database Configuration
```sql
-- Create dedicated database user
CREATE USER 'hackerjob_prod'@'%' IDENTIFIED BY 'STRONG_PASSWORD_HERE';
GRANT SELECT, INSERT, UPDATE ON fivem_production.player_vehicles TO 'hackerjob_prod'@'%';
GRANT SELECT, INSERT, UPDATE ON fivem_production.players TO 'hackerjob_prod'@'%';
GRANT ALL PRIVILEGES ON fivem_production.hacker_logs TO 'hackerjob_prod'@'%';
GRANT ALL PRIVILEGES ON fivem_production.hacker_skills TO 'hackerjob_prod'@'%';
FLUSH PRIVILEGES;

-- Configure connection limits
ALTER USER 'hackerjob_prod'@'%' WITH MAX_CONNECTIONS_PER_HOUR 1000;
ALTER USER 'hackerjob_prod'@'%' WITH MAX_QUERIES_PER_HOUR 5000;
```

### Backup Strategy
```bash
#!/bin/bash
# Daily backup script
BACKUP_DIR="/backups/hackerjob"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup hacker-specific tables
mysqldump -u backup_user -p$BACKUP_PASS fivem_production \
  hacker_logs hacker_skills > $BACKUP_DIR/hackerjob_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/hackerjob_$DATE.sql

# Remove backups older than 30 days
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
```

## Testing and Validation

### Pre-Production Testing Checklist
```bash
# 1. Database connectivity test
mysql -u hackerjob_prod -p -e "SELECT COUNT(*) FROM player_vehicles;"

# 2. Resource loading test
# Start server and check console for errors

# 3. Basic functionality test
# Test each hacking feature with test account

# 4. Performance test
# Run load test with multiple concurrent users

# 5. Security test
# Attempt SQL injection and XSS attacks

# 6. Error handling test
# Simulate database failures and network issues
```

### Automated Testing Script
```lua
-- testing/production_validation.lua
local ValidationTests = {
    {
        name = "Database Connection",
        test = function()
            local success = false
            MySQL.query('SELECT 1 as test', {}, function(result)
                success = result and #result > 0
            end)
            Wait(1000)
            return success
        end
    },
    {
        name = "Configuration Validation",
        test = function()
            return Config.Production.debugMode == false and
                   Config.Production.rateLimiting == true
        end
    },
    {
        name = "Security Settings",
        test = function()
            return Config.ProductionOverrides.security.inputValidation == true and
                   Config.ProductionOverrides.security.authorizationChecks == true
        end
    }
}

function RunProductionValidation()
    local results = {}
    for _, test in ipairs(ValidationTests) do
        local success, result = pcall(test.test)
        results[test.name] = success and result
        print(string.format("[VALIDATION] %s: %s", test.name, success and result and "PASS" or "FAIL"))
    end
    return results
end
```

## Go-Live Checklist

### Critical Pre-Launch Verification
- [ ] All debug modes disabled (`Config.Production.debugMode = false`)
- [ ] Rate limiting enabled and configured for production values
- [ ] Database connection tested and stable
- [ ] All dependencies installed and running
- [ ] Security settings validated
- [ ] Performance monitoring enabled
- [ ] Backup system configured and tested
- [ ] Admin access controls implemented
- [ ] Error logging configured
- [ ] Discord webhooks tested (if enabled)

### Configuration Validation
```lua
-- Run this validation before going live
local function ValidateProductionReadiness()
    local issues = {}
    
    -- Critical security checks
    if Config.Production.debugMode then
        table.insert(issues, "CRITICAL: Debug mode is enabled!")
    end
    
    if not Config.Production.rateLimiting then
        table.insert(issues, "CRITICAL: Rate limiting is disabled!")
    end
    
    -- Performance checks
    if Config.PlateQueryTimeout > 10000 then
        table.insert(issues, "WARNING: Database timeout too high")
    end
    
    -- Dependency checks
    local dependencies = {'qb-core', 'oxmysql', 'qb-input', 'qb-menu'}
    for _, dep in ipairs(dependencies) do
        if GetResourceState(dep) ~= 'started' then
            table.insert(issues, "ERROR: Dependency not running: " .. dep)
        end
    end
    
    return issues
end
```

### Launch Sequence
1. **Stop all related resources**
2. **Deploy updated files**
3. **Run database migrations**
4. **Start dependencies in order**:
   - oxmysql
   - qb-core
   - qb-input, qb-menu, qb-phone
   - qb-hackerjob
5. **Run validation tests**
6. **Monitor for 30 minutes**
7. **Announce to users if stable**

## Rollback Procedures

### Emergency Rollback Steps
```bash
# 1. Immediate rollback procedure
# Stop the server
stop qb-hackerjob

# 2. Restore previous version
rm -rf resources/qb-hackerjob
mv resources/qb-hackerjob.backup.YYYYMMDD resources/qb-hackerjob

# 3. Restore database if needed
mysql -u root -p fivem_production < backups/pre_deployment_backup.sql

# 4. Restart resources
ensure qb-hackerjob

# 5. Validate rollback success
```

### Rollback Decision Matrix
| Issue Severity | Action | Timeline |
|----------------|--------|----------|
| Critical Security Flaw | Immediate rollback | < 5 minutes |
| Database Corruption | Stop service, restore DB | < 15 minutes |
| Performance Degradation | Monitor, rollback if needed | < 30 minutes |
| Minor Issues | Log and patch | Next maintenance window |

### Post-Rollback Procedures
1. **Investigate root cause**
2. **Document the incident**
3. **Update testing procedures**
4. **Plan remediation**
5. **Schedule re-deployment**

## Monitoring and Alerting

### Key Performance Indicators
- Database query response time (< 100ms average)
- Memory usage (< 80% of available)
- Active user count
- Error rate (< 1% of operations)
- Cache hit ratio (> 90%)

### Alert Thresholds
```lua
-- Configure monitoring thresholds
local MonitoringThresholds = {
    database_timeout = 5000,      -- Alert if queries take > 5s
    memory_usage = 0.8,           -- Alert if memory > 80%
    error_rate = 0.05,            -- Alert if error rate > 5%
    concurrent_users = 45,        -- Alert if users > 45
    trace_buildup = 85            -- Alert if trace > 85%
}
```

### Health Check Endpoint
```lua
-- Health check for monitoring systems
RegisterServerEvent('qb-hackerjob:healthCheck')
AddEventHandler('qb-hackerjob:healthCheck', function()
    local source = source
    
    local health = {
        status = 'healthy',
        timestamp = os.time(),
        database = TestDatabaseConnection(),
        memory = GetMemoryUsage(),
        active_users = GetActiveUsers(),
        uptime = GetServerUptime()
    }
    
    TriggerClientEvent('qb-hackerjob:healthResponse', source, health)
end)
```

## Support and Maintenance

### Log File Locations
- **Server Logs**: `/server-data/logs/`
- **Database Logs**: `/var/log/mysql/`
- **Application Logs**: Check server console output

### Maintenance Schedule
- **Daily**: Check error logs and performance metrics
- **Weekly**: Review security logs and user activity
- **Monthly**: Database optimization and cleanup
- **Quarterly**: Full security audit and penetration testing

### Emergency Contacts
- **Lead Developer**: [Contact Information]
- **Database Administrator**: [Contact Information]
- **Security Team**: [Contact Information]
- **Operations Team**: [Contact Information]

---

## Conclusion

This production deployment guide provides comprehensive procedures for safely deploying the QB-HackerJob script in a production environment. Following these procedures ensures optimal security, performance, and reliability.

For additional support, refer to the Administrator Guide and Security Documentation.

**Remember**: Always test in a staging environment before deploying to production.