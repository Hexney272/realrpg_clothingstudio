fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealRPG'
description 'RealRPG Clothing Studio - Ingame clothing designer with runtime/hybrid texture rendering for ESX/QBCore/Qbox'
version '1.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/dui_texture.html',
    'web/assets/*.png',
    'web/assets/*.svg',
    'stream/**/*'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/templates.lua',
    'shared/framework.lua'
}

client_scripts {
    'client/main.lua',
    'client/studio.lua',
    'client/preview3d.lua',
    'client/wearables.lua',
    'client/preview.lua',
    'client/texture_runtime.lua',
    'client/pack_export.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/boot.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/inventory.lua',
    'server/upload_bridge.lua',
    'server/admin.lua',
    'server/healthcheck.lua',
    'server/maintenance.lua',
    'server/render_engine.lua',
    'server/pack_export.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}

provides {
    'realrpg_clothingstudio'
}

exports {
    'UseClothingItem'
}
