local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local hackingPhone = false
local currentPhoneNumber = nil
local hackState = {
    inProgress = false,
    captchaComplete = false,
    passwordComplete = false,
    success = false
}

-- NUI Callbacks
RegisterNUICallback('startPhoneHack', function(data, cb)
    local phoneNumber = data.phoneNumber
    
    -- Validate phone number
    if not phoneNumber or phoneNumber == '' then
        cb({success = false, message = 'Invalid phone number'})
        return
    end
    
    -- Check if player has the required level
    CanUseFeature('phoneHack', function(canUse)
        if not canUse then
            cb({success = false, message = 'Your hacking level is too low for this feature'})
            return
        end
        
        -- Check cooldown
        CheckCooldown('phoneHack', function(canContinue)
            if not canContinue then
                cb({success = false, message = 'This feature is on cooldown'})
                return
            end
            
            -- Start hacking process
            currentPhoneNumber = phoneNumber
            hackState = {
                inProgress = true,
                captchaComplete = false,
                passwordComplete = false,
                success = false
            }
            
            -- Initialize the captcha mini-game
            local gridSize = Config.PhoneHacking.captchaGridSize
            local captchaData = GenerateCaptchaGrid(gridSize)
            
            -- Send captcha data to NUI
            cb({
                success = true,
                captcha = captchaData,
                message = 'Starting phone hack...'
            })
            
            -- Start trace buildup
            TriggerServerEvent('qb-hackerjob:server:increaseTraceLevel', 'phoneHack')
            
            -- Log activity
            TriggerServerEvent('qb-hackerjob:server:logActivity', 'phoneHack', phoneNumber, false, 'Started hack attempt')
        end)
    end)
end)

-- Callback for when captcha is completed
RegisterNUICallback('phoneHackCaptchaComplete', function(data, cb)
    local success = data.success
    
    if not hackState.inProgress then
        cb({success = false, message = 'No hack in progress'})
        return
    end
    
    if success then
        hackState.captchaComplete = true
        
        -- Generate password cracking challenge
        local passwordData = GeneratePasswordCrackingChallenge()
        
        cb({
            success = true,
            passwordData = passwordData,
            message = 'Captcha bypassed. Starting password cracking...'
        })
    else
        -- Failed captcha
        hackState.inProgress = false
        
        cb({
            success = false,
            message = 'Captcha challenge failed. Security system locked you out.'
        })
        
        -- Handle failure
        HandleHackFailure('phoneHack', currentPhoneNumber, 'Failed at captcha stage')
        
        -- Alert user
        QBCore.Functions.Notify('Security system detected your intrusion attempt!', 'error')
    end
end)

-- Callback for when password cracking is completed
RegisterNUICallback('phoneHackPasswordComplete', function(data, cb)
    local success = data.success
    
    if not hackState.inProgress or not hackState.captchaComplete then
        cb({success = false, message = 'Invalid hack state'})
        return
    end
    
    if success then
        hackState.passwordComplete = true
        hackState.success = true
        
        -- Get phone data from server
        QBCore.Functions.TriggerCallback('qb-hackerjob:server:getPhoneData', function(phoneData)
            if phoneData then
                cb({
                    success = true,
                    phoneData = phoneData,
                    message = 'Password cracked! Access granted to phone data.'
                })
                
                -- Handle success
                HandleHackSuccess('phoneHack', currentPhoneNumber, 'Successfully hacked phone')
                
                -- Notify the player
                QBCore.Functions.Notify('Phone hack successful! Accessing call and message logs...', 'success')
            else
                cb({
                    success = false,
                    message = 'Failed to retrieve phone data. The number may be invalid.'
                })
                
                -- Handle partial failure
                HandleHackFailure('phoneHack', currentPhoneNumber, 'Failed to retrieve phone data')
            end
        end, currentPhoneNumber)
    else
        -- Failed password cracking
        hackState.inProgress = false
        
        cb({
            success = false,
            message = 'Password cracking failed. Security system locked you out.'
        })
        
        -- Handle failure
        HandleHackFailure('phoneHack', currentPhoneNumber, 'Failed at password cracking stage')
        
        -- Alert user
        QBCore.Functions.Notify('Failed to crack the password! Too many incorrect attempts.', 'error')
    end
end)

-- Generate captcha grid for the UI
function GenerateCaptchaGrid(size)
    -- Create a square grid of the specified size
    local grid = {}
    local targetPattern = {}
    
    -- Generate random cells for the grid
    for i = 1, size do
        grid[i] = {}
        for j = 1, size do
            grid[i][j] = {
                type = math.random(1, 6), -- Different types of "nodes"
                selected = false
            }
        end
    end
    
    -- Create a random pattern to find (e.g., a path through the grid)
    local startX, startY = math.random(1, size), math.random(1, size)
    local currentX, currentY = startX, startY
    
    -- Mark the start cell as special
    grid[startX][startY].type = 7 -- Special "start node" type
    grid[startX][startY].isStart = true
    
    table.insert(targetPattern, {x = startX, y = startY})
    
    -- Create a path of 3-5 cells
    local pathLength = math.random(3, 5)
    local directions = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}} -- Right, Down, Left, Up
    
    for i = 1, pathLength do
        -- Try to find a valid next cell
        local validMove = false
        local attempts = 0
        local nextX, nextY
        
        while not validMove and attempts < 10 do
            local dir = directions[math.random(1, 4)]
            nextX, nextY = currentX + dir[1], currentY + dir[2]
            
            -- Check if the cell is within bounds and not already in the path
            if nextX >= 1 and nextX <= size and nextY >= 1 and nextY <= size then
                local alreadyInPath = false
                for _, cell in ipairs(targetPattern) do
                    if cell.x == nextX and cell.y == nextY then
                        alreadyInPath = true
                        break
                    end
                end
                
                if not alreadyInPath then
                    validMove = true
                end
            end
            
            attempts = attempts + 1
        end
        
        -- If we found a valid move, add it to the path
        if validMove then
            currentX, currentY = nextX, nextY
            grid[currentX][currentY].type = 8 -- Special "path node" type
            table.insert(targetPattern, {x = currentX, y = currentY})
        else
            -- If we couldn't find a valid move, break out of the loop
            break
        end
    end
    
    -- Mark the end cell as special
    grid[currentX][currentY].type = 9 -- Special "end node" type
    grid[currentX][currentY].isEnd = true
    
    return {
        grid = grid,
        targetPattern = targetPattern,
        message = "Trace the path from the source node to the destination node"
    }
end

-- Generate password cracking challenge
function GeneratePasswordCrackingChallenge()
    -- Create a password cracking simulation
    local passwordLength = Config.PhoneHacking.passwordLength
    local maxAttempts = Config.PhoneHacking.maxAttempts
    
    -- Generate a random password (for visual purposes - actual success is determined by the mini-game)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    local password = ""
    for i = 1, passwordLength do
        local randomIndex = math.random(1, #chars)
        password = password .. string.sub(chars, randomIndex, randomIndex)
    end
    
    -- Create hints (partially revealed password with some correct characters)
    local hints = {}
    local hintCount = math.random(2, 3)
    
    for i = 1, hintCount do
        local hintChars = {}
        for j = 1, passwordLength do
            if math.random(1, 3) == 1 then
                -- Show correct character
                hintChars[j] = string.sub(password, j, j)
            else
                -- Show placeholder
                hintChars[j] = "*"
            end
        end
        
        table.insert(hints, table.concat(hintChars))
    end
    
    return {
        passwordLength = passwordLength,
        maxAttempts = maxAttempts,
        hints = hints,
        message = "Crack the phone password using the provided hints"
    }
end

-- Register the server callback for phone data retrieval
QBCore.Functions.CreateCallback('qb-hackerjob:server:getPhoneData', function(source, cb, phoneNumber)
    -- The server will check if the phone number exists and return calls/messages
    if not phoneNumber then 
        cb(nil)
        return
    end
    
    -- In a real implementation, this would query the phone database
    -- For now, we'll generate some fake data
    local fakeData = {
        owner = "Unknown",
        calls = {},
        messages = {}
    }
    
    -- Generate some fake calls
    for i = 1, math.random(3, 8) do
        table.insert(fakeData.calls, {
            number = GenerateRandomPhoneNumber(),
            name = GenerateRandomName(),
            time = os.date("%Y-%m-%d %H:%M:%S", os.time() - math.random(0, 86400 * 7)),
            type = math.random(1, 2) == 1 and "incoming" or "outgoing",
            duration = math.random(10, 300)
        })
    end
    
    -- Generate some fake messages
    for i = 1, math.random(5, 15) do
        table.insert(fakeData.messages, {
            number = GenerateRandomPhoneNumber(),
            name = GenerateRandomName(),
            time = os.date("%Y-%m-%d %H:%M:%S", os.time() - math.random(0, 86400 * 7)),
            type = math.random(1, 2) == 1 and "incoming" or "outgoing",
            message = GenerateRandomMessage()
        })
    end
    
    cb(fakeData)
end)

-- Helper function to generate a random phone number
function GenerateRandomPhoneNumber()
    local prefix = {"555", "444", "333", "222"}
    return prefix[math.random(1, #prefix)] .. "-" .. math.random(1000, 9999)
end

-- Helper function to generate a random name
function GenerateRandomName()
    local firstNames = {"John", "Jane", "Mike", "Sarah", "David", "Lisa", "Tom", "Emma", "Bob", "Alice"}
    local lastNames = {"Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor"}
    
    return firstNames[math.random(1, #firstNames)] .. " " .. lastNames[math.random(1, #lastNames)]
end

-- Helper function to generate a random message
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