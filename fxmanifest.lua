fx_version 'cerulean'
game 'gta5'

name 'guildbase'
description 'Guildbase Application NPC Integration'
author 'Guildbase'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/config.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    '/server:5181'
}
