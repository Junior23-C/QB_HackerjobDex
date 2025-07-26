-- BASIC DIAGNOSTIC TEST
print("^1[QB-HACKERJOB TEST] ^7CLIENT SCRIPT TEST.LUA IS LOADING!")

-- Test basic command
RegisterCommand('testlaptop', function()
    print("^1[QB-HACKERJOB TEST] ^7TEST COMMAND EXECUTED!")
end, false)

-- Test basic event
RegisterNetEvent('test:event')
AddEventHandler('test:event', function()
    print("^1[QB-HACKERJOB TEST] ^7TEST EVENT RECEIVED!")
end)

-- Immediate output
Citizen.CreateThread(function()
    print("^1[QB-HACKERJOB TEST] ^7CLIENT THREAD IS RUNNING!")
    Citizen.Wait(1000)
    print("^1[QB-HACKERJOB TEST] ^7CLIENT STILL RUNNING AFTER 1 SECOND!")
end)