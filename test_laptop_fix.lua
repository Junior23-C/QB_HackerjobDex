-- Test script to verify laptop opening functionality
-- This script can be used to manually trigger the laptop open event for testing

print("^2[qb-hackerjob:test] ^7Testing laptop fix...")

-- Wait a bit for everything to initialize
Citizen.Wait(5000)

-- Test the event trigger
print("^2[qb-hackerjob:test] ^7Attempting to trigger laptop open event...")
TriggerEvent('qb-hackerjob:client:openLaptop')

print("^2[qb-hackerjob:test] ^7Event triggered - check console for laptop debug output")