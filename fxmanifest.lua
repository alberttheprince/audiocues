fx_version 'cerulean'
game 'gta5'

name 'audiocues'
description 'Visual notifications for in-game audio events'
author 'PopcornRP'
version '1.2.0'

lua54 'yes'

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
