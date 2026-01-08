# Testing Guide: okokvehicleshopv2 Integration

This guide provides step-by-step instructions for testing the integration between DW Garages and okokvehicleshopv2.

## Prerequisites

Before testing, ensure:
1. DW Garages is properly installed and working
2. okokvehicleshopv2 is installed (or use the example files to create a mock)
3. Both resources are started in server.cfg
4. Integration code has been added to okokvehicleshopv2 (see OKOKVEHICLESHOP_INTEGRATION.md)

## Test 1: Verify Export Function

### Test the getVehicleName Export

**Command:**
```
/testgarageintegration adder
```

**Expected Result:**
- Console should display vehicle information:
  ```
  ========================================
  [DW Garages] Integration Test
  ========================================
  Model: adder
  Name: Truffade Adder (or model name if not found)
  Category: Super (or Unknown if not found)
  Speed: 160 (or 0 if not found)
  ========================================
  ```
- In-game notification showing vehicle name and category

**What to Check:**
- ✅ Export is callable
- ✅ Vehicle name resolves correctly
- ✅ Category is identified
- ✅ No Lua errors in console

### Test Different Vehicles

Try various vehicle models:
```
/testgarageintegration zentorno
/testgarageintegration t20
/testgarageintegration police
/testgarageintegration invalid_model
```

**Expected Results:**
- Known vehicles show proper names
- Unknown vehicles show model name as fallback
- No crashes or errors

## Test 2: Vehicle Purchase Synchronization

### Setup Test Environment

1. Ensure you have access to okokvehicleshopv2
2. Have some money in-game
3. Know the location of a vehicle shop

### Purchase a Vehicle

1. Go to the vehicle shop
2. Browse available vehicles
3. Select a vehicle to purchase
4. Complete the purchase
5. Note the plate number

### Verify in Garage

1. Go to any DW Garage (e.g., Legion Square)
2. Open the garage menu
3. Look for your purchased vehicle

**Expected Result:**
- ✅ Vehicle appears in garage list
- ✅ Vehicle name displays correctly (not "CAR NOT FOUND")
- ✅ Category is shown
- ✅ Vehicle is marked as stored (state = 1)

### Check Database

Query the database:
```sql
SELECT plate, vehicle, garage, state, custom_name FROM owned_vehicles 
WHERE plate = 'YOUR_PLATE' LIMIT 1;
```

**Expected Result:**
- Record exists in database
- `garage` field matches the delivery garage
- `state` = 1 (stored)
- `vehicle` contains the model name

## Test 3: Vehicle Name Resolution

### Test Existing Vehicles

If you already have vehicles in garages:

1. Open any garage menu
2. Check vehicle names in the list

**Expected Result:**
- ✅ Vehicle names display properly
- ✅ No "CAR NOT FOUND" messages
- ✅ Categories show if available

### Test Custom Names

1. Select a vehicle in the garage
2. Rename it using the custom name feature
3. Refresh the garage menu

**Expected Result:**
- ✅ Custom name takes priority over shop name
- ✅ Original shop name stored as fallback
- ✅ Category still displayed

## Test 4: Different Garage Types

### Public Garages
1. Go to Legion Square Garage
2. Open garage menu
3. Verify vehicle names display

### Job Garages (if applicable)
1. Join a job (e.g., police)
2. Go to job garage
3. Check both:
   - Personal vehicles
   - Job vehicles

**Expected Result:**
- ✅ Personal vehicles show shop names
- ✅ Job vehicles show configured names

### Shared Garages (if enabled)
1. Create or join a shared garage
2. Store a vehicle in shared garage
3. Check vehicle name displays

## Test 5: Impound System

### Impound a Vehicle

1. As law enforcement, use `/impound` near a vehicle
2. Enter reason and confirm
3. Check impound lot

**Expected Result:**
- ✅ Vehicle name displays in impound list
- ✅ Category shows correctly
- ✅ Can release vehicle with payment

## Test 6: Error Handling

### Test Without okokvehicleshopv2

1. Stop okokvehicleshopv2: `stop okokvehicleshopv2`
2. Open a garage menu
3. Check vehicle names

**Expected Result:**
- ✅ Fallback names used (GTA display names)
- ✅ No errors or crashes
- ✅ System continues working

### Test With Invalid Export

1. If export not configured in okokvehicleshopv2
2. Try to purchase a vehicle
3. Check garage

**Expected Result:**
- ✅ Graceful fallback to model names
- ✅ No blocking errors
- ✅ Vehicle still stored correctly

## Test 7: Performance Check

### Test with Many Vehicles

1. Have 10+ vehicles in a garage
2. Open garage menu
3. Note loading time

**Expected Result:**
- ✅ No significant lag
- ✅ All vehicles load with names
- ✅ Scrolling works smoothly

### Console Check

Monitor server console for:
- No repeated export call errors
- No memory leaks
- Reasonable query times

## Test 8: Edge Cases

### Empty Vehicle Model

Test with vehicles that have unusual models:
- Custom addon vehicles
- DLC vehicles
- Modified vehicle names

**What to Check:**
- System handles unknown models gracefully
- Fallback names work
- No crashes

### Special Characters

Test with vehicles/garages containing:
- Numbers
- Spaces
- Special characters

## Troubleshooting Common Issues

### Issue: "CAR NOT FOUND" Still Appears

**Diagnosis:**
```
/testgarageintegration vehiclemodel
```

If test fails:
1. Check okokvehicleshopv2 is started
2. Verify export function exists
3. Check vehicle exists in Config.Vehicles
4. Restart both resources

### Issue: Vehicle Not Appearing After Purchase

**Diagnosis:**
```sql
SELECT * FROM owned_vehicles WHERE owner = 'your_identifier' ORDER BY id DESC LIMIT 5;
```

Check:
1. Vehicle inserted in database
2. `state` field is 1
3. `garage` field has valid garage ID
4. Owner identifier matches

### Issue: Export Errors in Console

**Example Error:**
```
Error: attempt to call a nil value (field 'getVehicleName')
```

**Solution:**
1. Verify fxmanifest.lua exports the function
2. Check function name spelling
3. Ensure okokvehicleshopv2 loads before dw-garages
4. Restart server

## Success Criteria

✅ All Tests Passed:
- [ ] Export function returns vehicle data
- [ ] Vehicle purchases sync to garage
- [ ] Vehicle names display correctly
- [ ] Categories and details shown
- [ ] No "CAR NOT FOUND" errors
- [ ] Custom names work
- [ ] Fallback works without okokvehicleshopv2
- [ ] Performance acceptable
- [ ] No console errors

## Reporting Issues

If tests fail:

1. Note which test failed
2. Capture console errors
3. Take screenshots of UI issues
4. Check server.log for details
5. Verify configuration matches docs

## Clean Up After Testing

If you created test data:

```sql
-- Remove test vehicles (optional)
DELETE FROM owned_vehicles WHERE plate LIKE 'TEST%';

-- Reset test garage
UPDATE owned_vehicles SET garage = 'legion', state = 1 WHERE owner = 'your_identifier';
```

## Next Steps

After successful testing:
1. Document any customizations made
2. Train staff on new features
3. Monitor server logs for issues
4. Update vehicle shop inventory as needed
5. Consider adding more vehicle categories

## Support

For issues during testing:
- Check OKOKVEHICLESHOP_INTEGRATION.md
- Review example files in examples/okokvehicleshopv2/
- Contact support channels
- Check GitHub issues
