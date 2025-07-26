# QB-HackerJob Production Deployment Checklist

## 🚀 Pre-Deployment Validation

### ✅ Security Verification
- [ ] No debug statements in production code
- [ ] Config.Production.debugMode = false
- [ ] All user inputs properly validated
- [ ] Server-side authorization implemented
- [ ] SQL injection protections active
- [ ] Rate limiting configured and enabled

### ✅ Performance Optimization
- [ ] Database queries optimized (async operations)
- [ ] Cache system properly configured
- [ ] UI performance optimizations applied
- [ ] Memory management systems active
- [ ] Error handling comprehensive

### ✅ Configuration Review
- [ ] Production.lua settings applied
- [ ] Cooldowns set to production values
- [ ] Rate limits configured appropriately
- [ ] Battery system optimized
- [ ] Police alert chances balanced

### ✅ Dependencies Check
- [ ] qb-core installed and running
- [ ] oxmysql installed and configured
- [ ] qb-input available
- [ ] qb-menu available
- [ ] qb-phone installed (for phone features)
- [ ] PolyZone installed

## 🛠️ Installation Steps

### 1. File Placement
```bash
# Place the QB_HackerjobDex folder in your resources directory
ensure qb-hackerjob
```

### 2. Database Setup
The script will automatically create required tables:
- `hacker_skills` - Player progression data
- `hacker_logs` - Activity logging

### 3. Items Configuration
Add these items to your QBCore shared/items.lua:
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
    ['description'] = 'A charger for your hacking laptop'
},
```

### 4. Job Configuration
Add to qb-core/shared/jobs.lua:
```lua
['hacker'] = {
    label = 'Hacker',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Script Kiddie', payment = 50 },
        ['1'] = { name = 'Coder', payment = 75 },
        ['2'] = { name = 'Security Analyst', payment = 100 },
        ['3'] = { name = 'Elite Hacker', payment = 125 },
        ['4'] = { name = 'Boss', isboss = true, payment = 150 },
    },
},
```

### 5. Image Assets
Copy these images to your inventory images folder:
- hacker_laptop.png
- gps_tracker.png
- laptop_battery.png
- laptop_charger.png

## 🔧 Production Configuration

### Essential Settings to Review

1. **config/config.lua**:
   - Set `Config.Production.enabled = true`
   - Verify `Config.Production.debugMode = false`
   - Adjust cooldowns for your server population
   - Configure police alert chances appropriately

2. **config/production.lua**:
   - Review rate limits for your server size
   - Adjust performance settings based on hardware
   - Configure monitoring options

3. **Vendor Location**:
   - Default: Near LifeInvader building (-1054.49, -230.57)
   - Adjust pricing based on your economy
   - Configure vendor availability

## 📊 Monitoring & Maintenance

### Admin Commands for Monitoring
```
/hackerstatus     - System health and performance
/hackerperf       - Performance metrics and statistics
/hackerlogs [n]   - View recent activity logs
/givehackerlaptop [id] - Give laptop to player
/hackerlevel [id] [level] - Set player level
/hackerxp [id] [amount] - Give XP to player
```

### Performance Monitoring
- Check performance metrics regularly via `/hackerperf`
- Monitor database query times (should be <50ms)
- Watch memory usage and cache efficiency
- Review error logs for issues

### Regular Maintenance
- Monitor cache hit ratios (target >80%)
- Clean old log entries periodically
- Update production settings based on usage patterns
- Review security logs for suspicious activity

## 🚨 Troubleshooting

### Common Issues
1. **Laptop Won't Open**:
   - Check job requirements (Config.RequireJob)
   - Verify item configuration
   - Check for script errors in console

2. **Database Errors**:
   - Verify oxmysql is running
   - Check database connection settings
   - Review query timeout values

3. **Performance Issues**:
   - Check current user count vs limits
   - Monitor database query times
   - Review cache efficiency

4. **Permission Errors**:
   - Verify job configuration
   - Check admin permissions
   - Review server-side authorization

## 🎯 Success Metrics

Your deployment is successful when:
- ✅ No errors in server console
- ✅ All features working as expected
- ✅ Performance metrics within acceptable ranges
- ✅ Security measures active and effective
- ✅ Players can successfully use all features
- ✅ Database operations performing well

## 📞 Post-Deployment

### First 24 Hours
- Monitor performance metrics closely
- Watch for any error patterns
- Gather user feedback
- Check database performance
- Verify security measures are working

### Ongoing
- Regular performance reviews
- Security audit schedule
- Feature usage analytics
- User feedback incorporation
- Optimization opportunities

## 🔒 Security Notes

**CRITICAL**: Never enable debug mode in production
**IMPORTANT**: Regularly review access logs
**RECOMMENDED**: Set up automated monitoring alerts
**SUGGESTED**: Periodic security audits

---

*This checklist ensures your QB-HackerJob script is deployed safely and efficiently in a production environment.*