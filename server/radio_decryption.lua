local QBCore = exports['qb-core']:GetCoreObject()

-- Radio messages that can be intercepted (for the stub implementation)
local policeRadioMessages = {
    "Dispatch to all units, we have a 10-11 at Pillbox Hill.",
    "Unit 3 responding to the 10-57 at Vinewood Blvd.",
    "Officer down at Legion Square, requesting immediate backup.",
    "Suspect in custody, returning to Mission Row PD.",
    "Be advised, shots fired at Paleto Bay Bank.",
    "Pursuit in progress, heading southbound on the freeway.",
    "All units, we have a 10-90 at the Maze Bank Tower.",
    "Dispatch, need forensics at this crime scene ASAP.",
    "Vehicle reported stolen found at Sandy Shores.",
    "Need additional units for roadblock at North Rockford."
}

-- Callback for intercepting radio communications at a given frequency
QBCore.Functions.CreateCallback('qb-hackerjob:server:interceptRadio', function(source, cb, frequency)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb({ success = false, message = "Player not found" })
        return
    end
    
    -- Check for hacker job if required
    if Config.RequireJob and Player.PlayerData.job.name ~= Config.HackerJobName then
        cb({ success = false, message = "Unauthorized access" })
        return
    end
    
    -- In a real implementation, this would integrate with the voice system
    -- to intercept actual player radio communications
    
    -- For now, this is a stub that returns simulated data
    
    -- Determine if decryption is successful based on config chance
    local success = math.random(100) <= Config.RadioDecryptionChance
    
    if success then
        -- Get a random message from the police radio messages
        local message = policeRadioMessages[math.random(#policeRadioMessages)]
        
        local radioData = {
            frequency = frequency,
            channel = math.random(1, 10),
            message = message,
            source = "unknown",
            signalQuality = math.random(70, 95),
            timestamp = os.time()
        }
        
        -- Log the successful interception
        print(string.format("[qb-hackerjob] Player %s (%s) successfully intercepted radio frequency %s", 
            GetPlayerName(src), Player.PlayerData.citizenid, frequency))
        
        cb({ success = true, data = radioData })
        
        -- Award XP for successful radio decryption
        if Config.XPEnabled and Config.XPSettings and Config.XPSettings.radioDecrypt then
            TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'radioDecrypt', frequency, 'Radio decryption successful')
        end
    else
        -- Failed to decrypt
        local failData = {
            frequency = frequency,
            error = "Could not decrypt signal",
            signalQuality = math.random(10, 40),
            timestamp = os.time()
        }
        
        cb({ success = false, data = failData })
    end
end)

-- Event for logging radio interception attempts
RegisterNetEvent('qb-hackerjob:server:logRadioAttempt')
AddEventHandler('qb-hackerjob:server:logRadioAttempt', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Log the radio interception attempt
    print(string.format("[qb-hackerjob] Player %s (%s) attempted to intercept radio frequency %s", 
        GetPlayerName(src), Player.PlayerData.citizenid, data.frequency))
end)

-- Event for alerting police about radio interception (if configured)
RegisterNetEvent('qb-hackerjob:server:alertRadioInterception')
AddEventHandler('qb-hackerjob:server:alertRadioInterception', function()
    -- This would send an alert to police officers
    -- For now, this is just a stub
    
    -- In a real implementation, this might look like:
    -- TriggerClientEvent('police:client:radioInterceptionAlert', -1, {
    --     coordinates = GetEntityCoords(GetPlayerPed(source))
    -- })
end) 