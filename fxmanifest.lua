fx_version 'cerulean'
game 'gta5'

description 'Modern DW Garages System'
version '2.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
}

escrow_ignore {
    'config.lua'
}

dependency 'es_extended'

lua54 'yes'