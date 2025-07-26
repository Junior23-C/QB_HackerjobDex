fx_version 'cerulean'
game 'gta5'

description 'QBCore Hacker Job with Advanced Vehicle Plate Lookup'
version '1.0.0'
author 'Your Name'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config/config.lua',
    'config/vehicles.lua',
    'config/production.lua'
}

client_scripts {
    'client/test.lua',
    'client/simple.lua'
}

server_scripts {
    'server/test.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/plate_lookup.lua',
    'server/phone_tracker.lua',
    'server/radio_decryption.lua',
    'server/vendor.lua',
    'server/vehicle_tracker.lua',
    'server/phone_hacking.lua',
    'testing/test_framework.lua',
    'testing/load_test.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
    'html/img/*.png',
    'html/img/*.jpg',
    'html/audio/*.mp3',
    'html/fonts/*.ttf'
}

lua54 'yes' 