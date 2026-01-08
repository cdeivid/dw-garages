-- Example fxmanifest.lua for okokvehicleshopv2
-- This shows the required exports for DW Garages integration

fx_version 'cerulean'
game 'gta5'

description 'okokokvehicleshop v2 - Example Integration'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

-- IMPORTANT: Add this export for DW Garages integration
server_exports {
    'getVehicleName'  -- Export function to retrieve vehicle details
}

lua54 'yes'
