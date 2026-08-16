fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author       'Props Placer'
description  'Spawn, déplacement, rotation et persistance de props — optimisé multijoueur'
version      '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/streaming.lua',
    'client/placement.lua',
    'client/commands.lua',
}

server_scripts {
    'server/storage.lua',
    'server/main.lua',
}
