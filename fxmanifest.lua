fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to work as a bus driver and pickup npcs around the map'
version '1.2.0'

shared_script 'config.lua'

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client.lua'
}

server_script 'server.lua'