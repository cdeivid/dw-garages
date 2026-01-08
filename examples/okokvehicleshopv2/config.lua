-- Example config.lua for okokvehicleshopv2
-- This shows the vehicle configuration structure

Config = {}

-- Vehicle shop locations (example)
Config.Shops = {
    {
        name = 'PDM',
        coords = vector3(-56.79, -1096.87, 26.42),
        heading = 315.0,
        blip = {
            sprite = 326,
            color = 3,
            scale = 0.8
        }
    }
}

-- Vehicle Categories
Config.Categories = {
    ['compacts'] = 'Compacts',
    ['sedans'] = 'Sedans',
    ['suvs'] = 'SUVs',
    ['coupes'] = 'Coupes',
    ['muscle'] = 'Muscle',
    ['sports'] = 'Sports',
    ['super'] = 'Super',
    ['motorcycles'] = 'Motorcycles',
    ['offroad'] = 'Off-Road',
    ['vans'] = 'Vans'
}

-- Vehicle Database
-- THIS IS THE CRITICAL PART FOR DW GARAGES INTEGRATION
-- Each vehicle MUST have: name, category, and optionally brand, speed, price
Config.Vehicles = {
    -- Compacts
    ['blista'] = {
        name = 'Blista',
        brand = 'Dinka',
        category = 'Compacts',
        class = 'compacts',
        speed = 120,
        topspeed = 120,
        price = 15000,
        stock = 50
    },
    ['brioso'] = {
        name = 'Brioso R/A',
        brand = 'Grotti',
        category = 'Compacts',
        class = 'compacts',
        speed = 110,
        topspeed = 110,
        price = 18000,
        stock = 50
    },
    
    -- Sedans
    ['asea'] = {
        name = 'Asea',
        brand = 'Declasse',
        category = 'Sedans',
        class = 'sedans',
        speed = 115,
        topspeed = 115,
        price = 12000,
        stock = 50
    },
    ['asterope'] = {
        name = 'Asterope',
        brand = 'Karin',
        category = 'Sedans',
        class = 'sedans',
        speed = 120,
        topspeed = 120,
        price = 26000,
        stock = 50
    },
    
    -- Sports
    ['banshee'] = {
        name = 'Banshee',
        brand = 'Bravado',
        category = 'Sports',
        class = 'sports',
        speed = 155,
        topspeed = 155,
        price = 105000,
        stock = 50
    },
    ['bestiagts'] = {
        name = 'Bestia GTS',
        brand = 'Grotti',
        category = 'Sports',
        class = 'sports',
        speed = 152,
        topspeed = 152,
        price = 610000,
        stock = 50
    },
    
    -- Super Cars
    ['adder'] = {
        name = 'Truffade Adder',
        brand = 'Truffade',
        category = 'Super',
        class = 'super',
        speed = 160,
        topspeed = 160,
        price = 1000000,
        stock = 50
    },
    ['zentorno'] = {
        name = 'Pegassi Zentorno',
        brand = 'Pegassi',
        category = 'Super',
        class = 'super',
        speed = 155,
        topspeed = 155,
        price = 725000,
        stock = 50
    },
    ['t20'] = {
        name = 'Progen T20',
        brand = 'Progen',
        category = 'Super',
        class = 'super',
        speed = 155,
        topspeed = 155,
        price = 2200000,
        stock = 50
    },
    ['osiris'] = {
        name = 'Pegassi Osiris',
        brand = 'Pegassi',
        category = 'Super',
        class = 'super',
        speed = 155,
        topspeed = 155,
        price = 1950000,
        stock = 50
    },
    
    -- Motorcycles
    ['akuma'] = {
        name = 'Akuma',
        brand = 'Dinka',
        category = 'Motorcycles',
        class = 'motorcycles',
        speed = 140,
        topspeed = 140,
        price = 9000,
        stock = 50
    },
    ['bati'] = {
        name = 'Bati 801',
        brand = 'Pegassi',
        category = 'Motorcycles',
        class = 'motorcycles',
        speed = 145,
        topspeed = 145,
        price = 15000,
        stock = 50
    },
    
    -- SUVs
    ['baller'] = {
        name = 'Baller',
        brand = 'Gallivanter',
        category = 'SUVs',
        class = 'suvs',
        speed = 130,
        topspeed = 130,
        price = 90000,
        stock = 50
    },
    ['cavalcade'] = {
        name = 'Cavalcade',
        brand = 'Albany',
        category = 'SUVs',
        class = 'suvs',
        speed = 125,
        topspeed = 125,
        price = 60000,
        stock = 50
    },
    
    -- Muscle Cars
    ['blade'] = {
        name = 'Blade',
        brand = 'Vapid',
        category = 'Muscle',
        class = 'muscle',
        speed = 135,
        topspeed = 135,
        price = 160000,
        stock = 50
    },
    ['dominator'] = {
        name = 'Dominator',
        brand = 'Vapid',
        category = 'Muscle',
        class = 'muscle',
        speed = 140,
        topspeed = 140,
        price = 35000,
        stock = 50
    },
    
    -- Vans
    ['burrito'] = {
        name = 'Burrito',
        brand = 'Declasse',
        category = 'Vans',
        class = 'vans',
        speed = 100,
        topspeed = 100,
        price = 13000,
        stock = 50
    },
    ['minivan'] = {
        name = 'Minivan',
        brand = 'Vapid',
        category = 'Vans',
        class = 'vans',
        speed = 95,
        topspeed = 95,
        price = 30000,
        stock = 50
    }
}

-- Default garage for purchased vehicles
Config.DefaultGarage = 'legion'

-- Available garages for delivery
Config.DeliveryGarages = {
    {id = 'legion', label = 'Legion Square Garage'},
    {id = 'pinkcage', label = 'Pink Cage Garage'},
    {id = 'pillbox', label = 'Pillbox Garage'},
    {id = 'moviestar', label = 'Movie Star Garage'},
    {id = 'paleto', label = 'Paleto Garage'},
    {id = 'sandy', label = 'Sandy Shores Garage'}
}
