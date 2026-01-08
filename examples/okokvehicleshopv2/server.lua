-- Example server.lua for okokvehicleshopv2
-- This shows how to implement the vehicle name export and purchase sync

local ESX = exports['es_extended']:getSharedObject()

-- Example vehicle configuration
-- Replace this with your actual vehicle data structure
Config = Config or {}
Config.Vehicles = {
    ['adder'] = {
        name = 'Truffade Adder',
        brand = 'Truffade',
        category = 'Super',
        class = 'super',
        speed = 160,
        topspeed = 160,
        price = 1000000
    },
    ['zentorno'] = {
        name = 'Pegassi Zentorno',
        brand = 'Pegassi',
        category = 'Super',
        class = 'super',
        speed = 155,
        topspeed = 155,
        price = 725000
    },
    ['t20'] = {
        name = 'Progen T20',
        brand = 'Progen',
        category = 'Super',
        class = 'super',
        speed = 155,
        topspeed = 155,
        price = 2200000
    },
    -- Add more vehicles here...
}

-- ============================================
-- DW GARAGES INTEGRATION - REQUIRED EXPORT
-- ============================================

-- Export function to get vehicle details by model
-- This is called by DW Garages to resolve vehicle names and details
exports('getVehicleName', function(model)
    if not model then
        return {
            name = "Unknown Vehicle",
            category = "Unknown",
            speed = 0,
            model = "unknown",
            brand = "Unknown",
            price = 0
        }
    end
    
    -- Convert model to lowercase for consistency
    local modelLower = string.lower(model)
    
    -- Check if vehicle exists in shop configuration
    local vehicleData = Config.Vehicles[modelLower]
    
    if vehicleData then
        return {
            name = vehicleData.name or vehicleData.label or model,
            category = vehicleData.category or vehicleData.class or "Unknown",
            speed = vehicleData.speed or vehicleData.topspeed or 0,
            model = modelLower,
            brand = vehicleData.brand or "Unknown",
            price = vehicleData.price or 0
        }
    end
    
    -- Fallback if vehicle not found in shop data
    -- This prevents "CAR NOT FOUND" errors
    print('[okokvehicleshopv2] Warning: Vehicle model "' .. model .. '" not found in Config.Vehicles')
    
    return {
        name = GetDisplayNameFromVehicleModel(GetHashKey(model)) or model,
        category = "Unknown",
        speed = 0,
        model = modelLower,
        brand = "Unknown",
        price = 0
    }
end)

-- ============================================
-- VEHICLE PURCHASE SYNCHRONIZATION
-- ============================================

-- Example vehicle purchase handler
-- Modify your existing purchase code to include the sync trigger
RegisterNetEvent('okokvehicleshop:buyVehicle', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    local vehicleModel = data.model
    local vehiclePrice = data.price
    local selectedGarage = data.garage or 'legion'  -- Default to Legion garage
    
    -- Check if vehicle exists in shop
    local vehicleData = Config.Vehicles[string.lower(vehicleModel)]
    if not vehicleData then
        TriggerClientEvent('esx:showNotification', src, 'Vehicle not available for purchase', 'error')
        return
    end
    
    -- Check if player has enough money
    if xPlayer.getMoney() < vehiclePrice then
        TriggerClientEvent('esx:showNotification', src, 'Insufficient funds', 'error')
        return
    end
    
    -- Deduct money
    xPlayer.removeMoney(vehiclePrice, "Vehicle Purchase")
    
    -- Generate plate
    local plate = GeneratePlate()
    
    -- Insert vehicle into database
    MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle, garage, state) VALUES (?, ?, ?, ?, ?)',
        {xPlayer.identifier, plate, vehicleModel, selectedGarage, 1},
        function(rowsChanged)
            if rowsChanged > 0 then
                -- Notify player
                TriggerClientEvent('esx:showNotification', src, 'Vehicle purchased successfully!', 'success')
                
                -- IMPORTANT: Trigger sync event for DW Garages
                TriggerEvent('okokvehicleshop:vehiclePurchased', {
                    source = src,
                    plate = plate,
                    model = vehicleModel,
                    garage = selectedGarage,
                    price = vehiclePrice
                })
                
                -- Spawn the vehicle for the player
                TriggerClientEvent('okokvehicleshop:spawnPurchasedVehicle', src, {
                    model = vehicleModel,
                    plate = plate,
                    garage = selectedGarage
                })
            else
                -- Refund if database insert failed
                xPlayer.addMoney(vehiclePrice)
                TriggerClientEvent('esx:showNotification', src, 'Purchase failed. Please try again.', 'error')
            end
        end
    )
end)

-- Helper function to generate unique plate
function GeneratePlate()
    local plate = nil
    local plateExists = true
    
    while plateExists do
        plate = string.upper(GetRandomLetter(3) .. GetRandomNumber(3))
        
        local result = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate})
        plateExists = result and #result > 0
    end
    
    return plate
end

function GetRandomLetter(length)
    local str = ''
    for i = 1, length do
        str = str .. string.char(math.random(65, 90))
    end
    return str
end

function GetRandomNumber(length)
    local str = ''
    for i = 1, length do
        str = str .. math.random(0, 9)
    end
    return str
end

-- ============================================
-- EXAMPLE: Test Command to Verify Integration
-- ============================================

RegisterCommand('testshopexport', function(source, args)
    local src = source
    local model = args[1] or 'adder'
    
    local vehicleInfo = exports['okokvehicleshopv2']:getVehicleName(model)
    
    if vehicleInfo then
        print('========== Vehicle Info ==========')
        print('Model: ' .. vehicleInfo.model)
        print('Name: ' .. vehicleInfo.name)
        print('Category: ' .. vehicleInfo.category)
        print('Speed: ' .. vehicleInfo.speed)
        print('Brand: ' .. vehicleInfo.brand)
        print('Price: $' .. vehicleInfo.price)
        print('==================================')
        
        TriggerClientEvent('esx:showNotification', src, 
            'Vehicle: ' .. vehicleInfo.name .. ' | Category: ' .. vehicleInfo.category, 
            'info'
        )
    else
        TriggerClientEvent('esx:showNotification', src, 'Vehicle data not found', 'error')
    end
end, false)

print('[okokvehicleshopv2] DW Garages integration loaded successfully')
