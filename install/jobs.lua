-- Add this to your qb-core/shared/jobs.lua
['hacker'] = {
    label = 'Hacker',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'Script Kiddie',
            payment = 50
        },
        ['1'] = {
            name = 'Coder',
            payment = 75
        },
        ['2'] = {
            name = 'Security Analyst',
            payment = 100
        },
        ['3'] = {
            name = 'Elite Hacker',
            payment = 125
        },
        ['4'] = {
            name = 'Boss',
            isboss = true,
            payment = 150
        },
    },
}, 