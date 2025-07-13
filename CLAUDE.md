# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QB-HackerJob is a comprehensive hacker job script for the QBCore FiveM framework. It provides a realistic hacking system with features like vehicle plate lookup, phone tracking, radio decryption, and a skill progression system.

## Key Commands

### Testing and Development
- **Start the resource**: `ensure qb-hackerjob` in server.cfg
- **Open hacker laptop**: `/hackerlaptop` (or use item from inventory)
- **Admin commands**:
  - `/givehackerlaptop [id]` - Give laptop to player
  - `/hackerlevel [id] [level]` - Set player's hacker level
  - `/hackerxp [id] [amount]` - Give XP to player
  - `/hackerlogs [count]` - View recent hacking logs

### Database Setup
The resource automatically creates required tables on first run:
- `hacker_skills` - Stores player XP and level progression
- `hacker_logs` - Stores activity logs

## Architecture

### Resource Structure
- **Client-Side** (`client/`):
  - `main.lua` - Core client initialization, handles player data and job updates
  - `laptop.lua` - Laptop UI management
  - `plate_lookup.lua` - Vehicle plate lookup functionality
  - `phone_tracker.lua` - Phone tracking system
  - `phone_hacking.lua` - Phone hacking implementation
  - `radio_decryption.lua` - Radio decryption mechanics
  - `vehicle_tracker.lua` - GPS tracking for vehicles
  - `vehicle_control.lua` - Remote vehicle control features

- **Server-Side** (`server/`):
  - `main.lua` - Core server logic, item management, database initialization
  - `plate_lookup.lua` - Vehicle ownership queries
  - `phone_tracker.lua` - Phone location retrieval
  - `phone_hacking.lua` - Phone data access
  - `radio_decryption.lua` - Radio frequency access
  - `vendor.lua` - NPC vendor for purchasing equipment
  - `vehicle_tracker.lua` - Vehicle tracking backend

- **UI** (`html/`):
  - NUI interface for the hacking laptop
  - Dark theme with multiple hacking tools

### Key Systems

1. **Skill Progression**:
   - 5 levels: Script Kiddie → Coder → Security Analyst → Elite Hacker → Mastermind
   - XP gained from successful hacking operations
   - Features unlock at higher levels

2. **Trace Buildup System**:
   - Actions increase trace level
   - Police alerted when threshold exceeded
   - Trace decays over time

3. **Battery Management**:
   - Laptop requires battery charge
   - Different operations consume different amounts
   - Chargeable with laptop charger item

4. **Anti-Spam Protection**:
   - Global and per-feature cooldowns
   - Prevents rapid repeated actions

### Configuration

Main configuration files:
- `config/config.lua` - General settings, cooldowns, XP rates, police alerts
- `config/vehicles.lua` - Vehicle categories and hacking difficulty

Key configuration areas:
- Job requirements (`Config.RequireJob`, `Config.HackerJobName`)
- Vendor settings and location
- Battery system parameters
- Cooldown timings
- XP progression rates
- Police alert chances
- Logging options (database, console, Discord webhook)

### Dependencies
- QBCore framework
- oxmysql
- qb-input
- qb-menu
- qb-phone (for phone features)
- PolyZone (for vendor zone)

### Localization
- Locale files in `locales/` directory
- Currently supports English (`en.lua`)
- All UI strings should use locale system

## Development Notes

1. **Adding New Features**: Follow existing pattern of separate client/server files for each feature
2. **Database Queries**: Use MySQL.Async functions with proper error handling
3. **Player Data**: Always check if player is loaded before accessing PlayerData
4. **Cooldowns**: Implement both client and server-side validation
5. **Police Alerts**: Use the trace buildup system for gradual detection
6. **UI Updates**: Send data via NUI callbacks, handle responses properly
7. **Item Checks**: Verify items exist in player inventory before allowing actions