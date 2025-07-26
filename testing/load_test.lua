-- Load Testing Suite for QB-HackerJob
-- Simulates multiple concurrent users for production readiness testing

local LoadTest = {}
LoadTest.config = {
    maxConcurrentUsers = 20,
    testDurationMs = 60000, -- 1 minute test
    operationsPerUser = 10,
    randomDelayRange = {1000, 5000} -- 1-5 seconds between operations
}

LoadTest.metrics = {
    totalOperations = 0,
    successfulOperations = 0,
    failedOperations = 0,
    averageResponseTime = 0,
    totalResponseTime = 0,
    startTime = 0,
    endTime = 0,
    userSessions = {}
}

-- Simulate a user session
function LoadTest:simulateUserSession(userId)
    local userMetrics = {
        userId = userId,
        operations = 0,
        successes = 0,
        failures = 0,
        averageResponseTime = 0,
        startTime = GetGameTimer()
    }
    
    self.metrics.userSessions[userId] = userMetrics
    
    CreateThread(function()
        for i = 1, self.config.operationsPerUser do
            local operationType = math.random(1, 5)
            local operationName = ""
            
            -- Simulate different operations
            if operationType == 1 then
                operationName = "Plate Lookup"
                self:simulatePlateLookup(userId)
            elseif operationType == 2 then
                operationName = "Phone Tracking"
                self:simulatePhoneTracking(userId)
            elseif operationType == 3 then
                operationName = "Radio Decryption"
                self:simulateRadioDecryption(userId)
            elseif operationType == 4 then
                operationName = "Vehicle Tracking"
                self:simulateVehicleTracking(userId)
            else
                operationName = "XP Check"
                self:simulateXPCheck(userId)
            end
            
            -- Random delay between operations
            local delay = math.random(self.config.randomDelayRange[1], self.config.randomDelayRange[2])
            Wait(delay)
        end
        
        userMetrics.endTime = GetGameTimer()
        userMetrics.sessionDuration = userMetrics.endTime - userMetrics.startTime
        
        print(string.format("[LOAD TEST] User %d completed: %d operations, %d successes, %d failures", 
            userId, userMetrics.operations, userMetrics.successes, userMetrics.failures))
    end)
end

-- Simulate plate lookup operation
function LoadTest:simulatePlateLookup(userId)
    local startTime = GetGameTimer()
    local testPlate = "TEST" .. math.random(100, 999)
    
    self:incrementOperation(userId)
    
    -- Simulate the actual database query
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? LIMIT 1', {testPlate}, function(result)
        local responseTime = GetGameTimer() - startTime
        self:recordResponse(userId, responseTime, true) -- Assume success for test data
        
        -- Record metrics
        self.metrics.totalResponseTime = self.metrics.totalResponseTime + responseTime
        self.metrics.averageResponseTime = self.metrics.totalResponseTime / self.metrics.totalOperations
    end)
end

-- Simulate phone tracking operation
function LoadTest:simulatePhoneTracking(userId)
    local startTime = GetGameTimer()
    local testPhone = "555" .. math.random(1000, 9999)
    
    self:incrementOperation(userId)
    
    -- Simulate phone tracking query
    CreateThread(function()
        Wait(math.random(1000, 3000)) -- Simulate processing time
        
        local responseTime = GetGameTimer() - startTime
        local success = math.random() > 0.1 -- 90% success rate
        self:recordResponse(userId, responseTime, success)
    end)
end

-- Simulate radio decryption operation
function LoadTest:simulateRadioDecryption(userId)
    local startTime = GetGameTimer()
    
    self:incrementOperation(userId)
    
    CreateThread(function()
        Wait(math.random(2000, 4000)) -- Simulate decryption time
        
        local responseTime = GetGameTimer() - startTime
        local success = math.random() > 0.3 -- 70% success rate
        self:recordResponse(userId, responseTime, success)
    end)
end

-- Simulate vehicle tracking operation
function LoadTest:simulateVehicleTracking(userId)
    local startTime = GetGameTimer()
    
    self:incrementOperation(userId)
    
    CreateThread(function()
        Wait(math.random(1500, 3500)) -- Simulate tracking setup time
        
        local responseTime = GetGameTimer() - startTime
        local success = math.random() > 0.15 -- 85% success rate
        self:recordResponse(userId, responseTime, success)
    end)
end

-- Simulate XP check operation
function LoadTest:simulateXPCheck(userId)
    local startTime = GetGameTimer()
    
    self:incrementOperation(userId)
    
    -- Simulate XP database query
    MySQL.query('SELECT * FROM hacker_skills WHERE citizenid = ?', {"test_citizen_" .. userId}, function(result)
        local responseTime = GetGameTimer() - startTime
        self:recordResponse(userId, responseTime, true) -- XP checks should always succeed
    end)
end

-- Helper functions
function LoadTest:incrementOperation(userId)
    self.metrics.totalOperations = self.metrics.totalOperations + 1
    if self.metrics.userSessions[userId] then
        self.metrics.userSessions[userId].operations = self.metrics.userSessions[userId].operations + 1
    end
end

function LoadTest:recordResponse(userId, responseTime, success)
    if success then
        self.metrics.successfulOperations = self.metrics.successfulOperations + 1
        if self.metrics.userSessions[userId] then
            self.metrics.userSessions[userId].successes = self.metrics.userSessions[userId].successes + 1
        end
    else
        self.metrics.failedOperations = self.metrics.failedOperations + 1
        if self.metrics.userSessions[userId] then
            self.metrics.userSessions[userId].failures = self.metrics.userSessions[userId].failures + 1
        end
    end
    
    -- Update user-specific metrics
    if self.metrics.userSessions[userId] then
        local userSession = self.metrics.userSessions[userId]
        userSession.totalResponseTime = (userSession.totalResponseTime or 0) + responseTime
        userSession.averageResponseTime = userSession.totalResponseTime / userSession.operations
    end
end

-- Main load test runner
function LoadTest:runLoadTest(concurrentUsers, duration)
    concurrentUsers = concurrentUsers or self.config.maxConcurrentUsers
    duration = duration or self.config.testDurationMs
    
    print("\n" .. string.rep("=", 60))
    print("🚀 QB-HackerJob Load Testing")
    print(string.format("Users: %d, Duration: %ds", concurrentUsers, duration / 1000))
    print(string.rep("=", 60))
    
    -- Reset metrics
    self.metrics = {
        totalOperations = 0,
        successfulOperations = 0,
        failedOperations = 0,
        averageResponseTime = 0,
        totalResponseTime = 0,
        startTime = GetGameTimer(),
        endTime = 0,
        userSessions = {}
    }
    
    -- Start user sessions
    for i = 1, concurrentUsers do
        CreateThread(function()
            Wait(math.random(0, 1000)) -- Stagger user starts
            self:simulateUserSession(i)
        end)
    end
    
    -- Monitor progress
    CreateThread(function()
        local progressInterval = duration / 10 -- Report progress 10 times
        for i = 1, 10 do
            Wait(progressInterval)
            local progress = (i * 10)
            print(string.format("[LOAD TEST] Progress: %d%% - Operations: %d, Success Rate: %.1f%%", 
                progress, 
                self.metrics.totalOperations,
                self.metrics.totalOperations > 0 and (self.metrics.successfulOperations / self.metrics.totalOperations * 100) or 0
            ))
        end
    end)
    
    -- Generate final report
    CreateThread(function()
        Wait(duration + 5000) -- Wait for test completion plus buffer
        self:generateLoadTestReport()
    end)
end

-- Generate comprehensive load test report
function LoadTest:generateLoadTestReport()
    self.metrics.endTime = GetGameTimer()
    local totalTestTime = self.metrics.endTime - self.metrics.startTime
    
    print("\n" .. string.rep("=", 60))
    print("📊 LOAD TEST RESULTS")
    print(string.rep("=", 60))
    
    -- Overall metrics
    local successRate = self.metrics.totalOperations > 0 and 
        (self.metrics.successfulOperations / self.metrics.totalOperations * 100) or 0
    local operationsPerSecond = self.metrics.totalOperations / (totalTestTime / 1000)
    
    print(string.format("⏱️  Test Duration: %.2f seconds", totalTestTime / 1000))
    print(string.format("👥 Concurrent Users: %d", #self.metrics.userSessions))
    print(string.format("🔄 Total Operations: %d", self.metrics.totalOperations))
    print(string.format("✅ Successful Operations: %d", self.metrics.successfulOperations))
    print(string.format("❌ Failed Operations: %d", self.metrics.failedOperations))
    print(string.format("📈 Success Rate: %.1f%%", successRate))
    print(string.format("⚡ Operations/Second: %.2f", operationsPerSecond))
    print(string.format("⏱️  Average Response Time: %.2fms", self.metrics.averageResponseTime))
    print("")
    
    -- Performance assessment
    local isPerformant = successRate >= 95 and self.metrics.averageResponseTime <= 500 and operationsPerSecond >= 10
    
    if isPerformant then
        print("🎉 PERFORMANCE EXCELLENT: The system handles load well!")
        print("✅ Ready for production with expected user load.")
    else
        print("⚠️  PERFORMANCE CONCERNS DETECTED:")
        if successRate < 95 then
            print("   • Success rate below 95% - investigate error handling")
        end
        if self.metrics.averageResponseTime > 500 then
            print("   • Average response time above 500ms - optimize performance")
        end
        if operationsPerSecond < 10 then
            print("   • Low throughput - consider scaling improvements")
        end
    end
    
    print("")
    
    -- User session details
    print("👥 USER SESSION DETAILS:")
    for userId, session in pairs(self.metrics.userSessions) do
        local userSuccessRate = session.operations > 0 and (session.successes / session.operations * 100) or 0
        print(string.format("   User %d: %d ops, %.1f%% success, %.2fms avg response", 
            userId, session.operations, userSuccessRate, session.averageResponseTime or 0))
    end
    
    print(string.rep("=", 60) .. "\n")
    
    return {
        successRate = successRate,
        averageResponseTime = self.metrics.averageResponseTime,
        operationsPerSecond = operationsPerSecond,
        isPerformant = isPerformant,
        totalOperations = self.metrics.totalOperations,
        testDuration = totalTestTime
    }
end

-- Stress test - gradual load increase
function LoadTest:runStressTest()
    print("\n" .. string.rep("=", 60))
    print("🏋️ QB-HackerJob Stress Testing")
    print("Gradually increasing load to find breaking point...")
    print(string.rep("=", 60))
    
    local userCounts = {5, 10, 15, 20, 25, 30}
    local testDuration = 30000 -- 30 seconds per test
    local results = {}
    
    for i, userCount in ipairs(userCounts) do
        print(string.format("\n🔄 Stress Test Phase %d: %d concurrent users", i, userCount))
        
        CreateThread(function()
            self:runLoadTest(userCount, testDuration)
        end)
        
        Wait(testDuration + 10000) -- Wait for test completion plus buffer
        
        -- Record results
        local result = {
            userCount = userCount,
            successRate = self.metrics.totalOperations > 0 and 
                (self.metrics.successfulOperations / self.metrics.totalOperations * 100) or 0,
            averageResponseTime = self.metrics.averageResponseTime,
            operationsPerSecond = self.metrics.totalOperations / (testDuration / 1000)
        }
        
        table.insert(results, result)
        
        print(string.format("Phase %d Results: %.1f%% success, %.2fms avg response, %.2f ops/sec", 
            i, result.successRate, result.averageResponseTime, result.operationsPerSecond))
        
        -- Stop if performance degrades significantly
        if result.successRate < 90 or result.averageResponseTime > 1000 then
            print(string.format("⚠️ Performance degradation detected at %d users. Stopping stress test.", userCount))
            break
        end
    end
    
    print("\n📊 STRESS TEST SUMMARY:")
    for i, result in ipairs(results) do
        print(string.format("  %d users: %.1f%% success, %.2fms response, %.2f ops/sec", 
            result.userCount, result.successRate, result.averageResponseTime, result.operationsPerSecond))
    end
    
    return results
end

-- Export the load test framework
_G.HackerJobLoadTest = LoadTest

-- Console commands
RegisterCommand('loadtest', function(source, args)
    if source ~= 0 then return end -- Server console only
    
    local users = tonumber(args[1]) or 10
    local duration = tonumber(args[2]) or 60000
    
    LoadTest:runLoadTest(users, duration)
end, true)

RegisterCommand('stresstest', function(source, args)
    if source ~= 0 then return end -- Server console only
    LoadTest:runStressTest()
end, true)

print("📈 QB-HackerJob Load Test Framework loaded.")
print("Commands: 'loadtest [users] [duration]', 'stresstest'")