# QB-HackerJob Extended Features Implementation Plan

This document outlines the implementation plan for the remaining extended features for qb-hackerjob. The following features have been implemented:

- Full Documentation (README.md and install.md)
- Skill Progression System
- Phone Hacking by Phone Number
- Anti-Spam / Cooldowns
- Admin Logging & Discord webhook
- Trace Buildup System for Police Alerts

The following features are planned for implementation:

## 1. Enhanced Police Integration & Dispatch

### Goals
- Create more realistic and informative police alerts
- Add contextual information to alerts
- Create temporary map blips for police when hacks are detected

### Implementation Steps
1. Modify the trace buildup system to provide more specific alerts
2. Create different types of blips depending on the hack type
3. Add additional police notification types with custom messages
4. Implement a cooldown system for police alerts to prevent spam

### Files to Modify
- `server/main.lua`: Update the trace buildup system
- `client/main.lua`: Enhance police alert handlers
- `config/config.lua`: Add additional police alert configuration options

## 2. UI Update for Modern Dark Theme

### Goals
- Update the laptop interface with a sleek, modern dark theme
- Add animations for a more polished feel
- Display hacker level and XP progress in the UI

### Implementation Steps
1. Redesign the NUI HTML/CSS for a modern look
2. Add JavaScript animations for transitions
3. Create a level/XP display component
4. Implement UI feedback for available/locked features based on player level

### Files to Modify
- `html/index.html`: Update layout and structure
- `html/style.css`: Create new modern dark theme
- `html/script.js`: Add animations and level display
- Add new image assets to `html/img/`

## 3. Easy Translation System Enhancement

### Goals
- Ensure all strings are properly localized
- Make it easier to add new languages
- Document translation process

### Implementation Steps
1. Review all hardcoded strings in the codebase
2. Move all strings to the locale files
3. Update documentation with translation instructions

### Files to Modify
- `locales/en.lua`: Ensure all strings are included
- All client and server files: Replace hardcoded strings with locale lookups
- Create example additional locale file (`locales/es.lua`)

## 4. Inventory Compatibility Extensions

### Goals
- Add support for ox_inventory
- Make the script adaptable to different inventory systems

### Implementation Steps
1. Add configuration options for different inventory systems
2. Implement conditional code for different inventory systems
3. Test with both qb-inventory and ox_inventory

### Files to Modify
- `config/config.lua`: Add inventory type configuration
- `server/main.lua`: Add conditional logic for different inventory systems
- `client/main.lua`: Update item usage logic

## 5. Final Testing and Bug Fixing

### Goals
- Ensure all features work correctly together
- Test on both local and live servers
- Fix any bugs or issues

### Implementation Steps
1. Create a comprehensive test plan covering all features
2. Test each feature individually
3. Test feature interactions
4. Address any bugs or performance issues

### Deliverables
- Updated documentation with troubleshooting section
- Final release version with all features working

## Timeline and Priorities

1. **High Priority**
   - Police Integration Enhancements
   - UI Update for Modern Dark Theme

2. **Medium Priority**
   - Easy Translation System Enhancement
   - Inventory Compatibility Extensions

3. **Low Priority**
   - Final Testing and Bug Fixing
   - Additional polish and optimizations

## Resources Required

- Access to a test server with QBCore framework
- Sample player data for testing phone hacking
- Basic UI/UX design skills for the modern dark theme
- Knowledge of different inventory systems for compatibility

## Additional Notes

- All new features should maintain backward compatibility
- Code should be well-commented for future maintenance
- Performance should be monitored, especially for server-intensive operations 