fx_version 'cerulean'
game 'gta5'

author 'Asccochi'
description 'Rayka elevator | https://discord.gg/7K7G5vswuF'

provides {
    'mysql-async'
}

shared_script 'config.lua'
server_script '@oxmysql/lib/MySQL.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/sound.mp3'
}