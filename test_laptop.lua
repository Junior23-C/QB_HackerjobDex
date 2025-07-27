-- Test script to verify laptop functionality
-- Run this on the server console to test

RegisterCommand('testlaptopserver', function(source, args, rawCommand)
    local src = source
    if src == 0 then
        print("^1[Test] This command must be run by a player, not the server console")
        return
    end
    
    print("^2[Test] Triggering laptop open event for player " .. src)
    TriggerClientEvent('qb-hackerjob:client:openLaptop', src)
end, false)

print("^2[Test] Test command registered: /testlaptopserver")
print("^2[Test] Have a player run this command to test the laptop")