# okokvehicleshopv2 Integration Examples

This directory contains example files showing how to structure `okokvehicleshopv2` for integration with DW Garages.

## Files

1. **fxmanifest.lua** - Shows the required export declarations
2. **server.lua** - Complete server-side implementation with:
   - `getVehicleName` export function
   - Vehicle purchase synchronization
   - Example vehicle database structure
3. **config.lua** - Example vehicle configuration with all required fields

## Usage

### For okokvehicleshopv2 Owners

If you own or have access to modify `okokvehicleshopv2`:

1. Copy the relevant sections from these examples into your actual `okokvehicleshopv2` resource
2. Ensure your vehicle configuration includes all required fields (name, category, speed)
3. Add the export function to your server.lua
4. Update your fxmanifest.lua to export the function
5. Trigger the sync event after vehicle purchases

### For DW Garages Users

If you're using DW Garages and want to integrate with okokvehicleshopv2:

1. Share these examples with the okokvehicleshopv2 developer
2. Request they implement the `getVehicleName` export
3. Request they trigger the `okokvehicleshop:vehiclePurchased` event after purchases
4. Ensure `okokvehicleshopv2` starts before `dw-garages` in your server.cfg

## Important Notes

- These are **example files** - they show the structure, not a complete working resource
- Adapt the code to match your actual okokvehicleshopv2 implementation
- The vehicle database structure may differ in your version
- Test thoroughly after implementing changes

## Minimum Required Changes

At minimum, okokvehicleshopv2 needs:

1. **Export Function** (`getVehicleName`) - Returns vehicle name, category, and speed
2. **Sync Event** - Triggers after vehicle purchase to notify DW Garages
3. **Vehicle Data** - Config with name, category, and optionally speed for each vehicle

## Testing

After implementation, test with:

```lua
-- Test the export
/testshopexport adder

-- Check console output for vehicle info
```

Purchase a vehicle and verify:
1. It appears in DW Garages
2. Name displays correctly (not "CAR NOT FOUND")
3. Category and speed info available

## Support

For help with integration:
- Check the main OKOKVEHICLESHOP_INTEGRATION.md guide
- Consult okokvehicleshopv2 documentation
- Contact DW Garages support for garage-specific issues
