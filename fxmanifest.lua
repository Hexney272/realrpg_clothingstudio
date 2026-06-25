fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealRPG'
description 'RealRPG Clothing Studio - Ingame clothing designer with DUI runtime texture projection for ESX/QBCore/Qbox + ox_inventory'
version '0.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/dui_render.html',
    'web/assets/*.png',
    'web/assets/*.svg',
    'stream/**/*'
}

shared_scripts {
    '@ox_lib/init.lua', -- optional, script has fallback; remove if you do not use ox_lib
    'config.lua',
    'shared/garments.lua',
    'shared/templates.lua',
    'shared/framework.lua'
}

client_scripts {
    'client/dui.lua',
    'client/runtime_texture.lua',
    'client/main.lua',
    'client/studio.lua',
    'client/wearables.lua',
    'client/preview.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/upload.lua',
    'server/inventory.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}
