-- ULTRA SIMPLE CLIENT TEST
print("SIMPLE CLIENT SCRIPT LOADED")

-- Basic event without any dependencies
RegisterNetEvent('qb-hackerjob:client:openLaptop', function()
    print("LAPTOP EVENT RECEIVED IN SIMPLE.LUA")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openLaptop'
    })
end)

-- Test keybind
RegisterKeyMapping('testlaptop2', 'Test Laptop Open', 'keyboard', 'F9')
RegisterCommand('testlaptop2', function()
    print("F9 KEY PRESSED - OPENING LAPTOP")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openLaptop'
    })
end, false)