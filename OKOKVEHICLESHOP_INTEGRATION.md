# okokvehicleshopv2 Integration Guide

This guide explains how to integrate `okokvehicleshopv2` with `DW Garages` to synchronize vehicle purchases and display proper vehicle names.

## Overview

The integration allows:
1. Automatic registration of purchased vehicles in DW Garages
2. Proper vehicle name display (no more "CAR NOT FOUND")
3. Vehicle category and speed information
4. Seamless synchronization between shop and garage systems

## Required Changes to okokvehicleshopv2

### 1. Add Export Function in fxmanifest.lua

Add the following to your `okokvehicleshopv2/fxmanifest.lua`:

```lua
-- Add to the exports section
exports {
    'getVehicleName'
}

-- If you don't have an exports section, add it:
server_exports {
    'getVehicleName'
}
```

### 2. Create Export Function in server.lua

Add this function to your `okokvehicleshopv2/server.lua` file:

```lua
-- Export function to get vehicle details by model
exports('getVehicleName', function(model)
    -- Check if model exists in your vehicle shop data
    -- This assumes you have a Config.Vehicles table similar to QB-Core/ESX shared vehicles
    local vehicleData = Config.Vehicles and Config.Vehicles[model]
    
    if vehicleData then
        return {
            name = vehicleData.name or vehicleData.label or model,
            category = vehicleData.category or vehicleData.class or "Unknown",
            speed = vehicleData.speed or vehicleData.topspeed or 0,
            model = model,
            brand = vehicleData.brand or "Unknown",
            price = vehicleData.price or 0
        }
    end
    
    -- Fallback if vehicle not found in shop data
    return {
        name = GetDisplayNameFromVehicleModel(GetHashKey(model)) or model,
        category = "Unknown",
        speed = 0,
        model = model,
        brand = "Unknown",
        price = 0
    }
end)
```

### 3. Trigger Vehicle Purchase Event

After a vehicle purchase is completed in `okokvehicleshopv2`, trigger the synchronization event:

```lua
-- In your vehicle purchase completion code
RegisterNetEvent('okokvehicleshop:buyVehicle', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    -- ... your existing purchase logic ...
    
    -- After successful purchase, trigger the sync event
    TriggerEvent('okokvehicleshop:vehiclePurchased', {
        source = src,
        plate = plate,
        model = vehicleModel,
        garage = selectedGarage or 'legion',  -- Default garage
        price = vehiclePrice
    })
end)
```

## Vehicle Data Structure

The `getVehicleName` export should return a table with the following structure:

```lua
{
    name = "Vehicle Display Name",  -- Human-readable name
    category = "Sports",            -- Vehicle category/class
    speed = 150,                    -- Top speed (optional)
    model = "adder",                -- Spawn model name
    brand = "Truffade",            -- Manufacturer (optional)
    price = 1000000                -- Vehicle price (optional)
}
```

## Example okokvehicleshopv2 Vehicle Configuration

If your shop uses a configuration similar to this:

```lua
Config.Vehicles = {
    ['adder'] = {
        name = 'Truffade Adder',
        brand = 'Truffade',
        category = 'Super',
        speed = 160,
        price = 1000000,
        class = 'super'
    },
    ['zentorno'] = {
        name = 'Pegassi Zentorno',
        brand = 'Pegassi',
        category = 'Super',
        speed = 155,
        price = 725000,
        class = 'super'
    }
}
```

The export function will automatically map these values correctly.

## Testing the Integration

### 1. Verify the Export Works

In game, run this command in F8 console:

```lua
/testexport okokvehicleshopv2 getVehicleName adder
```

You should see vehicle data returned.

### 2. Test Vehicle Purchase

1. Go to the vehicle shop
2. Purchase a vehicle
3. Go to any DW Garage
4. Your purchased vehicle should appear with the correct name

### 3. Check for "CAR NOT FOUND" Issues

If vehicle names still show as "CAR NOT FOUND":
1. Verify the export is properly registered in fxmanifest.lua
2. Check that `okokvehicleshopv2` is started before `dw-garages` in server.cfg
3. Ensure the vehicle model exists in your Config.Vehicles table

## Troubleshooting

### Vehicle Names Still Show as Model Names

**Problem**: Vehicles display as "adder" instead of "Truffade Adder"

**Solution**:
1. Ensure `okokvehicleshopv2` is running: `ensure okokvehicleshopv2`
2. Restart both resources: `restart okokvehicleshopv2` then `restart dw-garages`
3. Check server console for export errors

### Vehicles Not Appearing in Garage After Purchase

**Problem**: Purchased vehicles don't show up in the garage

**Solution**:
1. Check the database `owned_vehicles` table - the vehicle should be inserted there
2. Verify the `garage` field matches an existing garage ID in Config.Garages
3. Check server console for SQL errors

### Export Returns Nil or Errors

**Problem**: The `getVehicleName` export returns nil

**Solution**:
1. Verify the function is properly exported in fxmanifest.lua
2. Check that your Config.Vehicles table structure matches the expected format
3. Add debug prints to the export function to trace execution

## Advanced: Custom Vehicle Data Sources

If your shop uses a different data structure, modify the export function accordingly:

```lua
exports('getVehicleName', function(model)
    -- Example: Using a different data source
    local vehicleInfo = MySQL.Sync.fetchAll('SELECT * FROM vehicle_shop WHERE model = ?', {model})
    
    if vehicleInfo and vehicleInfo[1] then
        local data = vehicleInfo[1]
        return {
            name = data.display_name,
            category = data.vehicle_class,
            speed = data.max_speed,
            model = model,
            brand = data.manufacturer,
            price = data.cost
        }
    end
    
    -- Fallback
    return {
        name = model,
        category = "Unknown",
        speed = 0,
        model = model
    }
end)
```

## Support

For issues specific to:
- **DW Garages**: Check the main README.md and Discord support
- **okokvehicleshopv2**: Contact okokokvehicleshopv2 support
- **Integration Issues**: Ensure both resources are up to date and properly configured

## Summary

After completing these steps:
1. ✅ Vehicle purchases will automatically register in DW Garages
2. ✅ Vehicle names will display correctly (no "CAR NOT FOUND")
3. ✅ Additional vehicle information (category, speed) will be available
4. ✅ Seamless user experience between shop and garage systems
