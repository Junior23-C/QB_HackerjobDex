local QBCore = exports['qb-core']:GetCoreObject()

-- Callback for getting phone data
QBCore.Functions.CreateCallback('qb-hackerjob:server:getPhoneData', function(source, cb, phoneNumber)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb(nil)
        return
    end
    
    -- Server-side job authorization check
    if Config.RequireJob then
        if Player.PlayerData.job.name ~= Config.HackerJobName then
            cb(nil)
            return
        end
        
        if Config.JobRank > 0 and Player.PlayerData.job.grade.level < Config.JobRank then
            cb(nil)
            return
        end
    end
    
    -- Enhanced phone number validation
    if not phoneNumber or type(phoneNumber) ~= 'string' then
        cb(nil)
        return
    end
    
    -- Remove non-digit characters and validate format
    local cleanNumber = phoneNumber:gsub("%D", "")
    
    -- Validate phone number format (7-15 digits)
    if not cleanNumber:match("^%d+$") or string.len(cleanNumber) < 7 or string.len(cleanNumber) > 15 then
        cb(nil)
        return
    end
    
    phoneNumber = cleanNumber
    
    -- Check if player has the required level
    local citizenid = Player.PlayerData.citizenid
    local hasRequiredLevel = false
    
    if not Config.XPEnabled then
        hasRequiredLevel = true
    else
        MySQL.query('SELECT level FROM hacker_skills WHERE citizenid = ?', {citizenid}, function(result)
            if result and #result > 0 then
                hasRequiredLevel = tonumber(result[1].level) >= Config.PhoneHacking.minLevel
            end
        end)
        
        -- Wait for async query to complete
        Wait(100)
        
        if not hasRequiredLevel then
            cb(nil)
            return
        end
    end
    
    -- Phone number already validated and formatted above
    
    -- Check if this is a player's phone number
    MySQL.query('SELECT id, charinfo FROM players WHERE phone = ?', {phoneNumber}, function(players)
        local phoneData = {
            owner = "Unknown",
            calls = {},
            messages = {}
        }
        
        if players and #players > 0 then
            -- Found a player with this phone number
            local charInfo = json.decode(players[1].charinfo)
            if charInfo then
                phoneData.owner = charInfo.firstname .. " " .. charInfo.lastname
            end
            
            -- Query call history - check if qb-phone exists and get its table schema
            local callsQuery = [[
                SELECT * FROM phone_calls 
                WHERE caller = ? OR receiver = ? 
                ORDER BY created_at DESC LIMIT 20
            ]]
            
            MySQL.query(callsQuery, {phoneNumber, phoneNumber}, function(calls)
                if calls and #calls > 0 then
                    phoneData.calls = calls
                else
                    -- Generate fake calls
                    phoneData.calls = GenerateFakeCalls(phoneNumber, 5, 10)
                end
                
                -- Query SMS history
                local messagesQuery = [[
                    SELECT * FROM phone_messages 
                    WHERE sender = ? OR receiver = ? 
                    ORDER BY created_at DESC LIMIT 30
                ]]
                
                MySQL.query(messagesQuery, {phoneNumber, phoneNumber}, function(messages)
                    if messages and #messages > 0 then
                        phoneData.messages = messages
                    else
                        -- Generate fake messages
                        phoneData.messages = GenerateFakeMessages(phoneNumber, 8, 15)
                    end
                    
                    -- Award XP for successful phone hacking
                    if Config.XPEnabled and Config.XPSettings and Config.XPSettings.phoneHack then
                        TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'phoneHack', phoneNumber, 'Phone hacking successful')
                    end
                    
                    -- Return the data
                    cb(phoneData)
                end)
            end)
        else
            -- No player found with this number, generate fake data
            phoneData.calls = GenerateFakeCalls(phoneNumber, 3, 8)
            phoneData.messages = GenerateFakeMessages(phoneNumber, 5, 12)
            
            -- Award XP for successful phone hacking
            if Config.XPEnabled and Config.XPSettings and Config.XPSettings.phoneHack then
                TriggerClientEvent('qb-hackerjob:client:handleHackSuccess', src, 'phoneHack', phoneNumber, 'Phone hacking successful')
            end
            
            -- Return the data
            cb(phoneData)
        end
    end)
end)

-- Generate fake call history
function GenerateFakeCalls(phoneNumber, min, max)
    local calls = {}
    local count = math.random(min, max)
    
    for i = 1, count do
        local isOutgoing = (math.random(1, 2) == 1)
        local otherNumber = GenerateRandomPhoneNumber()
        local callTime = os.time() - math.random(0, 604800) -- Within the last week
        
        table.insert(calls, {
            id = i,
            caller = isOutgoing and phoneNumber or otherNumber,
            receiver = isOutgoing and otherNumber or phoneNumber,
            created_at = os.date("%Y-%m-%d %H:%M:%S", callTime),
            duration = math.random(5, 300),
            call_type = "call", -- or "missed"
            anonymous = (math.random(1, 10) == 1) -- 10% chance of anonymous call
        })
    end
    
    return calls
end

-- Generate fake message history
function GenerateFakeMessages(phoneNumber, min, max)
    local messages = {}
    local count = math.random(min, max)
    
    for i = 1, count do
        local isOutgoing = (math.random(1, 2) == 1)
        local otherNumber = GenerateRandomPhoneNumber()
        local messageTime = os.time() - math.random(0, 604800) -- Within the last week
        
        table.insert(messages, {
            id = i,
            sender = isOutgoing and phoneNumber or otherNumber,
            receiver = isOutgoing and otherNumber or phoneNumber,
            message = GenerateRandomMessage(),
            created_at = os.date("%Y-%m-%d %H:%M:%S", messageTime),
            read = 1
        })
    end
    
    return messages
end

-- Generate random phone number
function GenerateRandomPhoneNumber()
    return string.format("%d%d%d-%d%d%d%d", 
        math.random(1, 9), math.random(0, 9), math.random(0, 9),
        math.random(0, 9), math.random(0, 9), math.random(0, 9), math.random(0, 9))
end

-- Generate random message
function GenerateRandomMessage()
    local messages = {
        "Hey, what's up?",
        "Call me when you get a chance.",
        "Did you get the package?",
        "Meeting at 3pm tomorrow.",
        "Don't forget to bring the documents.",
        "Where are you?",
        "I'll be there in 10 minutes.",
        "Thanks for the help!",
        "I need a favor...",
        "Let's catch up soon.",
        "The job is done.",
        "The target has been eliminated.",
        "Package delivered at the drop point.",
        "Did you get the money?",
        "Police are on high alert, stay low.",
        "New shipment coming in tonight.",
        "Meet me at the usual spot.",
        "We need to talk. It's urgent.",
        "Code red. Abort mission.",
        "All clear. Proceed as planned."
    }
    
    return messages[math.random(1, #messages)]
end

-- Handle updating last use time for cooldowns
RegisterServerEvent('qb-hackerjob:server:updateLastUseTime')
AddEventHandler('qb-hackerjob:server:updateLastUseTime', function(activity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Update player metadata with last use time
    Player.Functions.SetMetaData("lastHack" .. activity, GetGameTimer())
end) 