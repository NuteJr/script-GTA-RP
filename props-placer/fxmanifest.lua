fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author       'Props Placer'
description  'Spawn, déplacement, rotation et persistance de props — optimisé multijoueur'
version      '1.1.0'

shared_scripts {
    'config.lua',
    'catalog.lua',
}

client_scripts {
    'client/streaming.lua',
    'client/placement.lua',
    'client/menu.lua',
    'client/commands.lua',
}

server_scripts {
    'server/storage.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.webp',
}
