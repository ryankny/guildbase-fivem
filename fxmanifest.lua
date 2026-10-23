fx_version 'cerulean'
game 'gta5'

name 'guildbase'
description 'Guildbase application NPCs and in-game staff review panel'
author 'Guildbase'
version '1.1.0'

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
    'html/staff.css',
    'html/script.js',
    'html/staff.js',
}

dependencies {
    '/server:5181'
}
