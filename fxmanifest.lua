fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealRPG / ChatGPT'
description 'RealRPG Clothing Studio - ingame clothing designer with runtime texture, sync, upload bridge, layer assets, AI, marketplace, admin, healthcheck and maintenance tools'
version '1.3.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/dui_texture.html',
    'web/assets/*.png',
    'web/assets/*.svg',
    'stream/**/*',
    'docs/*.md',
    'INSTALL.md',
    'TROUBLESHOOTING.md',
    'RELEASE_NOTES.md'
}

shared_scripts {
    'config.lua',
    'shared/templates.lua',
    'shared/framework.lua'
}

client_scripts {
    'client/main.lua',
    'client/studio.lua',
    'client/wearables.lua',
    'client/preview.lua',
    'client/texture_runtime.lua'
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
    'server/main.lua'
}

dependencies {
    'oxmysql'
}
