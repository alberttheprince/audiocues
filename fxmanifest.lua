fx_version 'cerulean'
game 'gta5'

name 'audiocues'
description 'Visual notifications for in-game audio events'
author 'Popcorn Roleplay: https://discord.gg/popcornroleplay'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
