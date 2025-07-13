local QBCore = exports['qb-core']:GetCoreObject()
local isDecrypting = false
local lastDecryptTime = 0

-- Register NUI Callback for radio decryption
RegisterNUICallback('decryptRadio', function(data, cb)
    local frequency = data.frequency
    
    if not frequency then
        cb({success = false, message = "Invalid frequency"})
        return
    end
    
    local success = DecryptRadioFrequency(frequency, false)
    cb({success = success})
end)

-- Main function to decrypt a radio frequency
function DecryptRadioFrequency(frequency, isCommand)
    local currentTime = GetGameTimer()
    
    -- Check for cooldown
    if (currentTime - lastDecryptTime) < Config.RadioDecryptionCooldown and not isCommand then
        local remainingTime = math.ceil((Config.RadioDecryptionCooldown - (currentTime - lastDecryptTime)) / 1000)
        QBCore.Functions.Notify(Lang:t('error.cooldown', {time = remainingTime}), "error")
        return false
    end
    
    -- Check if already decrypting
    if isDecrypting then
        QBCore.Functions.Notify(Lang:t('info.processing_data'), "primary")
        return false
    end
    
    -- Make sure radio decryption is enabled
    if not Config.RadioDecryptionEnabled then
        QBCore.Functions.Notify(Lang:t('error.no_access'), "error")
        return false
    end
    
    isDecrypting = true
    lastDecryptTime = currentTime
    
    -- Start decryption animation and UI feedback
    QBCore.Functions.Notify(Lang:t('info.decrypting_signal'), "primary")
    
    -- Progress bar for decryption animation
    QBCore.Functions.Progressbar("radio_decryption", Lang:t('info.decrypting_signal'), Config.RadioDecryptionDuration, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@heists@prison_heiststation@cop_reactions",
        anim = "cop_b_idle",
        flags = 49,
    }, {}, {}, function() -- Done
        -- Note: This is a placeholder for the actual radio decryption functionality
        -- In a full implementation, this would interact with the voice system to intercept comms
        
        -- For now, just simulate a random success rate
        local success = math.random(100) <= Config.RadioDecryptionChance
        
        if success then
            -- Generate fake radio messages
            local messages = {
                "Unit 1, proceeding to checkpoint Alpha.",
                "Dispatch, we've got a 10-31 at Vinewood Blvd.",
                "All units, be advised of a 10-45 at Sandy Shores.",
                "Backup requested near Paleto Bay Bank.",
                "Suspect in custody, returning to station.",
                "Shots fired, need assistance at Legion Square.",
            }
            
            local radioData = {
                frequency = frequency,
                channel = math.random(1, 5),
                message = messages[math.random(#messages)],
                signalQuality = math.random(70, 95),
                decryptionLevel = "Full"
            }
            
            -- Check for police notification chance
            if Config.AlertPolice.enabled and math.random(100) <= Config.AlertPolice.radioDecryptChance then
                TriggerServerEvent('police:server:policeAlert', 'Radio Frequency Intrusion')
            end
            
            -- Send data to NUI
            SendNUIMessage({
                action = "radioDecryptResult",
                success = true,
                data = radioData
            })
            
            QBCore.Functions.Notify(Lang:t('success.radio_decrypted'), "success")
            
            -- Award XP and log success
            HandleHackSuccess('radioDecrypt', frequency, 'Successfully decrypted radio signal')
            
            -- Return data for external use
            isDecrypting = false
            return true, radioData
        else
            -- Generate partial/corrupt data for failure case
            local partialData = {
                frequency = frequency,
                channel = "Unknown",
                message = "---signal corrupted---",
                signalQuality = math.random(10, 40),
                decryptionLevel = "Failed"
            }
            
            -- Send data to NUI
            SendNUIMessage({
                action = "radioDecryptResult",
                success = false,
                data = partialData
            })
            
            QBCore.Functions.Notify(Lang:t('error.radio_signal_not_found'), "error")
            
            -- Log failure
            HandleHackFailure('radioDecrypt', frequency, 'Failed to decrypt radio signal')
            
            isDecrypting = false
            return false
        end
    end, function() -- Cancel
        isDecrypting = false
        QBCore.Functions.Notify(Lang:t('error.operation_failed'), "error")
        return false
    end)
    
    return true
end

-- Export function
exports('DecryptRadioFrequency', DecryptRadioFrequency)
