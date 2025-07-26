-- SERVER DIAGNOSTIC TEST
print("^1[QB-HACKERJOB TEST] ^7SERVER SCRIPT TEST.LUA IS LOADING!")

-- Test server command
RegisterCommand('testserver', function(source)
    print("^1[QB-HACKERJOB TEST] ^7SERVER TEST COMMAND FROM PLAYER " .. tostring(source))
    if source > 0 then
        TriggerClientEvent('test:event', source)
    end
end, false)

-- Show resource info
Citizen.CreateThread(function()
    print("^1[QB-HACKERJOB TEST] ^7Resource Name: " .. GetCurrentResourceName())
    print("^1[QB-HACKERJOB TEST] ^7Resource State: " .. GetResourceState(GetCurrentResourceName()))
end)