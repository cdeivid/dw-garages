local ESX = exports['es_extended']:getSharedObject()
local impoundedVehicles = {}
local activeImpounds = {}
local OutsideVehicles = {}
local trackedJobVehicles = {}
local occupiedJobParkingSpots = {}
local trackedJobVehicles = {}
local jobVehicles = {}

-- okokvehicleshopv2 Integration Functions
-- Get vehicle details from okokvehicleshopv2 export
function GetVehicleDetailsFromShop(model)
    if GetResourceState('okokvehicleshopv2') == 'started' then
        -- Call okokvehicleshopv2 export to get vehicle details
        local success, vehicleData = pcall(function()
            return exports['okokvehicleshopv2']:getVehicleName(model)
        end)
        
        if success and vehicleData then
            return vehicleData
        end
    end
    
    -- Fallback to basic vehicle name if export not available
    return {
        name = GetDisplayNameFromVehicleModel(GetHashKey(model)) or model,
        category = "Unknown",
        speed = 0,
        model = model
    }
end

-- Enriches a single vehicle record with data from okokvehicleshopv2
-- Modifies the vehicle table in-place
function EnrichVehicleData(vehicle)
    if not vehicle then return end
    
    -- Skip if custom name is already set and use it instead
    if vehicle.custom_name and vehicle.custom_name ~= "" then
        vehicle.display_name = vehicle.custom_name
        return
    end
    
    -- Get vehicle details from shop
    local vehicleInfo = GetVehicleDetailsFromShop(vehicle.vehicle)
    vehicle.display_name = vehicleInfo.name
    vehicle.category = vehicleInfo.category
    vehicle.top_speed = vehicleInfo.speed
end

-- Event handler for vehicle purchases from okokvehicleshopv2
RegisterNetEvent('okokvehicleshop:vehiclePurchased', function(vehicleData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local plate = vehicleData.plate
    local model = vehicleData.model
    local garage = vehicleData.garage or 'legion' -- Default garage
    
    -- Get vehicle details from shop
    local vehicleInfo = GetVehicleDetailsFromShop(model)
    
    -- Verify vehicle in database and ensure it's correctly configured
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            -- Vehicle exists, ensure it's stored in correct garage
            local vehicle = result[1]
            if vehicle.state ~= 1 or vehicle.garage ~= garage then
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 1, garage = ? WHERE plate = ?', 
                    {garage, plate}, function(rowsChanged)
                        if rowsChanged > 0 then
                            print('[DW Garages] Vehicle purchase synchronized and corrected: ' .. plate .. ' (' .. vehicleInfo.name .. ') -> ' .. garage)
                        end
                    end
                )
            else
                print('[DW Garages] Vehicle purchase synchronized: ' .. plate .. ' (' .. vehicleInfo.name .. ')')
            end
        else
            -- Vehicle doesn't exist in database, log warning
            -- Note: okokvehicleshopv2 should handle insertion
            print('[DW Garages] WARNING: Vehicle purchase detected but not found in database: ' .. plate)
            print('[DW Garages] This may indicate okokvehicleshopv2 did not properly insert the vehicle.')
        end
    end)
end)

-- Export function to get enriched vehicle data
exports('getEnrichedVehicleData', function(model)
    return GetVehicleDetailsFromShop(model)
end)

ESX.RegisterServerCallback('dw-garages:server:GetPersonalVehicles', function(source, cb, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    
    local identifier = xPlayer.identifier
    
    local query = 'SELECT *, COALESCE(is_favorite, 0) as is_favorite FROM owned_vehicles WHERE owner = ?'
    local params = {identifier}
    
    if garageId then
        query = query .. ' AND garage = ?'
        table.insert(params, garageId)
    end
    
    MySQL.Async.fetchAll(query, params, function(result)
        if result[1] then
            for i, vehicle in ipairs(result) do
                EnrichVehicleData(vehicle)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetVehiclesByGarage', function(source, cb, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE garage = ?', {garageId}, function(result)
        if result and #result > 0 then
            for i, vehicle in ipairs(result) do
                EnrichVehicleData(vehicle)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetGangVehicles', function(source, cb, gang, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = ? AND garage = ?', {owner, garageId}, function(personalResult)
        MySQL.Async.fetchAll('SELECT pv.* FROM owned_vehicles pv JOIN gang_vehicles gv ON pv.plate = gv.plate WHERE gv.gang = ? AND pv.owner != ? AND gv.stored = 1 AND pv.garage = ?', 
        {gang, owner, garageId}, function(gangResult)
            local allVehicles = {}
            
            for _, vehicle in ipairs(personalResult) do
                EnrichVehicleData(vehicle)
                table.insert(allVehicles, vehicle)
            end
            
            for _, vehicle in ipairs(gangResult) do
                EnrichVehicleData(vehicle)
                table.insert(allVehicles, vehicle)
            end
            
            cb(allVehicles)
        end)
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:CheckOwnership', function(source, cb, plate, garageType)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    local owner = xPlayer.identifier
    local isOwner = false
    local isInGarage = false
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if result[1] then
            isOwner = true
        end
        
        if garageType == "gang" and not isOwner then
            local gang = xPlayer.gang.name
            if gang and gang ~= "none" then
                MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ?', {plate, gang}, function(gangResult)
                    if gangResult[1] then
                        isInGarage = true
                    end
                    cb(isOwner, isInGarage)
                end)
            else
                cb(isOwner, isInGarage)
            end
        else
            cb(isOwner, isInGarage)
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:CheckSharedAccess', function(source, cb, plate, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_owner = ?', 
    {garageId, owner}, function(memberResult)
        if memberResult and #memberResult > 0 then
            MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1', 
            {plate, garageId}, function(vehResult)
                if vehResult and #vehResult > 0 then
                    cb(true)
                else
                    cb(false)
                end
            end)
        else
            MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
            {garageId, owner}, function(ownerResult)
                if ownerResult and #ownerResult > 0 then
                    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1', 
                    {plate, garageId}, function(vehResult)
                        if vehResult and #vehResult > 0 then
                            cb(true)
                        else
                            cb(false)
                        end
                    end)
                else
                    cb(false)
                end
            end)
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetVehicleProperties', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT mods FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            cb(json.decode(result[1].mods))
        else
            cb(nil)
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetAllGarages', function(source, cb)
    local garages = {}
    
    for k, v in pairs(Config.Garages) do
        table.insert(garages, {id = k, name = v.label, type = "public"})
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if Player then
        if xPlayer.job then
            for k, v in pairs(Config.JobGarages) do
                if v.job == xPlayer.job.name then
                    table.insert(garages, {id = k, name = v.label, type = "job"})
                end
            end
        end
        
        if xPlayer.gang and xPlayer.gang.name ~= "none" then
            for k, v in pairs(Config.GangGarages) do
                if v.gang == xPlayer.gang.name then
                    table.insert(garages, {id = k, name = v.label, type = "gang"})
                end
            end
        end
    end
    
    cb(garages)
end)

RegisterNetEvent('dw-garages:server:TransferVehicleToGarage', function(plate, newGarageId, cost)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, "You don't own this vehicle")
            return
        end
        local vehicle = result[1]
        if vehicle.state ~= 1 then
            TriggerClientEvent('esx:showNotification', src, "Vehicle must be stored to transfer it")
            return
        end
        local transferCost = cost or Config.TransferCost or 500
        if xPlayer.getMoney() < transferCost then
            TriggerClientEvent('esx:showNotification', src, "You need $" .. transferCost .. " to transfer this vehicle")
            return
        end
        xPlayer.removeMoney(transferCost, "vehicle-transfer-fee")
        MySQL.Async.execute('UPDATE owned_vehicles SET garage = ? WHERE plate = ?', {newGarageId, plate}, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('esx:showNotification', src, "Vehicle transferred to " .. newGarageId .. " garage for $" .. transferCost)
                TriggerClientEvent('dw-garages:client:TransferComplete', src, newGarageId, plate)
            else
                xPlayer.addMoney(transferCost, "vehicle-transfer-refund")
                TriggerClientEvent('esx:showNotification', src, "Transfer failed")
            end
        end)
    end)
end)

-- Improved version of CheckJobAccess that also returns the job name
ESX.RegisterServerCallback('dw-garages:server:CheckJobVehicleAccess', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false, nil) end
    
    local jobName = xPlayer.job.name
    if not jobName then return cb(false, nil) end
    
    if trackedJobVehicles[plate] then
        local vehicleJob = trackedJobVehicles[plate].job
        return cb(vehicleJob == jobName, vehicleJob)
    end
    
    return cb(false, nil)
end)

RegisterNetEvent('dw-garages:server:TrackJobVehicle', function(plate, jobName, props, spotIndex)
    local src = source
    
    if not plate or not jobName then return end
    
    jobVehicles[plate] = {
        job = jobName,
        props = props,
        spotIndex = spotIndex,
        lastUpdated = os.time()
    }
end)

RegisterNetEvent('dw-garages:server:FreeJobParkingSpot', function(jobName, spotIndex)
    if not jobName or not spotIndex then return end
    
    TriggerClientEvent('dw-garages:client:FreeJobParkingSpot', -1, jobName, spotIndex)
end)
-- Check if player has job access to a vehicle
ESX.RegisterServerCallback('dw-garages:server:CheckJobAccess', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    local playerJob = xPlayer.job.name
    
    if jobVehicles[plate] and jobVehicles[plate].job == playerJob then
        return cb(true)
    end
    
    return cb(false)
end)


-- Get job vehicle data
ESX.RegisterServerCallback('dw-garages:server:GetJobVehicleData', function(source, cb, plate)
    if trackedJobVehicles[plate] then
        cb(trackedJobVehicles[plate])
    else
        cb(nil)
    end
end)

function FindAvailableParkingSpot(jobName)
    local spots = GetJobParkingSpots(jobName)
    if #spots == 0 then return nil end
    
    -- Initialize job parking spots table if needed
    if not occupiedJobParkingSpots[jobName] then
        occupiedJobParkingSpots[jobName] = {}
        
        -- Check all existing vehicles to see if they're in parking spots
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehCoords = GetEntityCoords(veh)
                
                for spotIndex, spot in ipairs(spots) do
                    local spotCoords = vector3(spot.x, spot.y, spot.z)
                    if #(vehCoords - spotCoords) < 2.5 then
                        occupiedJobParkingSpots[jobName][spotIndex] = true
                        break
                    end
                end
            end
        end
    end
    
    -- Find the first available spot
    for spotIndex, spot in ipairs(spots) do
        if not occupiedJobParkingSpots[jobName][spotIndex] then
            return spotIndex, spot
        end
    end
    
    return nil
end

function ParkJobVehicle(vehicle, jobName)
    if not DoesEntityExist(vehicle) then return false end
    if not jobName then return false end
    
    -- Find an available parking spot
    local spotIndex, parkingSpot = FindAvailableParkingSpot(jobName)
    
    if not parkingSpot then
        -- Notify is client-side, this shouldn't be in server
        return false
    end
    
    -- Mark this spot as occupied
    SetSpotState(jobName, spotIndex, true)
    
    -- This entire function appears to be client-side code on server
    -- Commenting out as vehicle functions don't work server-side
    -- This functionality is already implemented in client.lua
    
    return true
end

function IsSpotAvailable(jobName, spotIndex)
    if not occupiedJobParkingSpots[jobName] then
        occupiedJobParkingSpots[jobName] = {}
    end
    
    return not occupiedJobParkingSpots[jobName][spotIndex]
end

-- Function to mark spot as occupied/available
function SetSpotState(jobName, spotIndex, isOccupied)
    if not occupiedJobParkingSpots[jobName] then
        occupiedJobParkingSpots[jobName] = {}
    end
    
    occupiedJobParkingSpots[jobName][spotIndex] = isOccupied
end

-- Function to get parking spots for a job
function GetJobParkingSpots(jobName)
    -- For police, use the specific spots provided
    if jobName == "police" then
        return {
            vector4(446.05395, -1025.607, 28.646846, 10.391553),
            vector4(442.25765, -1025.844, 28.717491, 37.374588),
            vector4(438.53656, -1026.5, 28.78754, 42.148361),
            vector4(434.99621, -1026.865, 28.851186, 26.760805),
            vector4(431.12667, -1027.418, 28.921892, 50.015827),
            vector4(427.40734, -1027.538, 28.987623, 0.8152692)
        }
    end
    
    -- For other jobs, use their spawn points
    for garageId, garage in pairs(Config.JobGarages) do
        if garage.job == jobName then
            if garage.spawnPoints then
                return garage.spawnPoints
            elseif garage.spawnPoint then
                return {garage.spawnPoint}
            end
        end
    end
    
    return {}
end


RegisterNetEvent('dw-garages:server:StoreVehicle', function(plate, garageId, props, fuel, engineHealth, bodyHealth, garageType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local owner = xPlayer.identifier    
    
    MySQL.Async.fetchAll('SHOW COLUMNS FROM owned_vehicles LIKE "stored"', {}, function(storedColumn)
        local hasStoredColumn = #storedColumn > 0
        MySQL.Async.fetchAll('SHOW COLUMNS FROM owned_vehicles LIKE "state"', {}, function(stateColumn)
            local hasStateColumn = #stateColumn > 0
            
            -- FIXED QUERY: Don't clear shared_garage_id automatically
            local query = 'UPDATE owned_vehicles SET garage = ?, mods = ?, fuel = ?, engine = ?, body = ?'
            local params = {garageId, json.encode(props), fuel, engineHealth, bodyHealth}
            if hasStoredColumn then
                query = query .. ', stored = 1'
            end
            if hasStateColumn then
                query = query .. ', state = 1'
            end
            query = query .. ' WHERE plate = ?'
            table.insert(params, plate)
            
            MySQL.Async.execute(query, params, function(rowsChanged)
                if rowsChanged > 0 then
                    OutsideVehicles[plate] = nil
                    
                    if garageType == "gang" then
                        local gang = xPlayer.gang.name
                        if gang and gang ~= "none" then
                            MySQL.Async.execute('UPDATE gang_vehicles SET stored = 1 WHERE plate = ? AND gang = ?', {plate, gang})
                        end
                    end
                    
                    -- Trigger refresh events
                    TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                else
                    TriggerClientEvent('esx:showNotification', src, "Failed to store vehicle")
                end
            end)
        end)
    end)
end)


RegisterNetEvent('dw-garages:server:UpdateGangVehicleState', function(plate, state)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local gang = xPlayer.gang.name
    if gang and gang ~= "none" then
        MySQL.Async.execute('UPDATE gang_vehicles SET stored = ? WHERE plate = ? AND gang = ?', {state, plate, gang})
    end
end)

RegisterNetEvent('dw-garages:server:UpdateVehicleName', function(plate, newName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if result[1] then
            MySQL.Async.execute('UPDATE owned_vehicles SET custom_name = ? WHERE plate = ? AND owner = ?', {newName, plate, owner}, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('esx:showNotification', src, 'Vehicle name updated', 'success')
                else
                    TriggerClientEvent('esx:showNotification', src, 'Failed to update vehicle name', 'error')
                end
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'You do not own this vehicle', 'error')
        end
    end)
end)

RegisterNetEvent('dw-garages:server:ToggleFavorite', function(plate, isFavorite)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    local favoriteValue = isFavorite and 1 or 0
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if result[1] then
            -- Update favorite status
            MySQL.Async.execute('UPDATE owned_vehicles SET is_favorite = ? WHERE plate = ? AND owner = ?', {favoriteValue, plate, owner}, function(rowsChanged)
                if rowsChanged > 0 then
                    if isFavorite then
                        TriggerClientEvent('esx:showNotification', src, 'Added to favorites', 'success')
                    else
                        TriggerClientEvent('esx:showNotification', src, 'Removed from favorites', 'error')
                    end
                else
                    TriggerClientEvent('esx:showNotification', src, 'Failed to update favorite status', 'error')
                end
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'You do not own this vehicle', 'error')
        end
    end)
end)

RegisterNetEvent('qb-garage:server:ToggleFavorite', function(plate, isFavorite)
    TriggerEvent('dw-garages:server:ToggleFavorite', plate, isFavorite)
end)

RegisterNetEvent('dw-garages:server:StoreVehicleInGang', function(plate, gangName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    -- Verify ownership first
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if result[1] then
            MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ? AND owner = ?', {plate, gangName, owner}, function(gangResult)
                if gangResult[1] then
                    TriggerClientEvent('esx:showNotification', src, 'Vehicle is already shared with your gang', 'error')
                else
                    MySQL.Async.execute('INSERT INTO gang_vehicles (plate, gang, owner, vehicle, stored) VALUES (?, ?, ?, ?, 1)', 
                        {plate, gangName, owner, result[1].vehicle}, 
                        function(rowsChanged)
                            if rowsChanged > 0 then
                                MySQL.Async.execute('UPDATE owned_vehicles SET stored_in_gang = ? WHERE plate = ? AND owner = ?', 
                                    {gangName, plate, owner})
                                
                                TriggerClientEvent('esx:showNotification', src, 'Vehicle shared with your gang', 'success')
                                TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                            else
                                TriggerClientEvent('esx:showNotification', src, 'Failed to share vehicle with gang', 'error')
                            end
                        end
                    )
                end
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'You do not own this vehicle', 'error')
        end
    end)
end)

RegisterNetEvent('qb-garage:server:StoreVehicleInGang', function(plate, gangName)
    TriggerEvent('dw-garages:server:StoreVehicleInGang', plate, gangName)
end)

RegisterNetEvent('qb-garage:server:UpdateVehicleState', function(plate, state)
    MySQL.Async.execute('UPDATE owned_vehicles SET state = ?, stored = ? WHERE plate = ?', {state, state, plate})
end)

RegisterNetEvent('qb-garage:server:UpdateGangVehicleState', function(plate, state)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local gang = xPlayer.gang.name
    if gang and gang ~= "none" then
        MySQL.Async.execute('UPDATE gang_vehicles SET stored = ? WHERE plate = ? AND gang = ?', {state, plate, gang})
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    MySQL.Async.fetchAll('SHOW COLUMNS FROM owned_vehicles LIKE "impoundedtime"', {}, function(result)
        if result and #result > 0 then
        else
            Wait (100)
        end
    end)
    
    -- Initialize the OutsideVehicles table when server starts
    MySQL.Async.fetchAll('SELECT plate FROM owned_vehicles WHERE state = 0', {}, function(result)
        if result and #result > 0 then
            for _, v in ipairs(result) do
                OutsideVehicles[v.plate] = true
            end
        else
            Wait(100)
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:IsVehicleOut', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT state FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            cb(result[1].state == 0)
        else
            cb(false)
        end
    end)
end)


ESX.RegisterServerCallback('dw-garages:server:CreateSharedGarage', function(source, cb, garageName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb(false, "Player not found") end
    
    local owner = xPlayer.identifier
    
    local code = tostring(math.random(1000, 9999))
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE owner_owner = ?', {owner}, function(result)
        if result and #result > 0 then
            cb(false, "You already own a shared garage")
            return
        end
        
        MySQL.Async.insert('INSERT INTO shared_garages (name, owner_owner, access_code) VALUES (?, ?, ?)', 
            {garageName, owner, code}, 
            function(garageId)
                if garageId > 0 then
                    MySQL.Async.insert('INSERT INTO shared_garage_members (garage_id, member_owner) VALUES (?, ?)', 
                        {garageId, owner})
                    
                    cb(true, {id = garageId, code = code, name = garageName})
                else
                    cb(false, "Failed to create shared garage")
                end
            end
        )
    end)
end)

RegisterNetEvent('dw-garages:server:RequestJoinSharedGarage', function(accessCode)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE access_code = ?', {accessCode}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, "Invalid access code")
            return
        end
        
        local garageData = result[1]
        
        MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_owner = ?', 
            {garageData.id, owner}, function(memberResult)
                if memberResult and #memberResult > 0 then
                    TriggerClientEvent('esx:showNotification', src, "You are already a member of this garage")
                    return
                end
                
                MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM shared_garage_members WHERE garage_id = ?', 
                    {garageData.id}, function(countResult)
                        if countResult[1].count >= Config.MaxSharedGarageMembers then
                            TriggerClientEvent('esx:showNotification', src, "This garage has reached its member limit")
                            return
                        end
                        
                        local ownerPlayer = ESX.GetPlayerFromIdentifier(garageData.owner_owner)
                        if not ownerPlayer then
                            TriggerClientEvent('esx:showNotification', src, "Garage owner is not online")
                            return
                        end
                        
                        TriggerClientEvent('dw-garages:client:ReceiveJoinRequest', ownerPlayer.source, {
                            requesterId = owner,
                            requesterName = xPlayer.get("firstName") .. ' ' .. xPlayer.get("lastName"),
                            garageId = garageData.id,
                            garageName = garageData.name
                        })
                        
                        TriggerClientEvent('esx:showNotification', src, "Join request sent to garage owner")
                    end
                )
            end
        )
    end)
end)

RegisterNetEvent('dw-garages:server:ApproveJoinRequest', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local ownerCitizenid = xPlayer.identifier
    local requesterId = data.requesterId
    local garageId = data.garageId
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
        {garageId, ownerCitizenid}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "You don't own this garage")
                return
            end
            
            MySQL.Async.insert('INSERT INTO shared_garage_members (garage_id, member_owner) VALUES (?, ?)', 
                {garageId, requesterId}, function(memberId)
                    if memberId > 0 then
                        local requesterPlayer = ESX.GetPlayerFromIdentifier(requesterId)
                        if requesterPlayer then
                            TriggerClientEvent('esx:showNotification', requesterPlayer.source, 
                                "Your request to join " .. result[1].name .. " garage has been approved", "success")
                        end
                        
                        TriggerClientEvent('esx:showNotification', src, "Approved garage membership request")
                    else
                        TriggerClientEvent('esx:showNotification', src, "Failed to add member")
                    end
                end
            )
        end
    )
end)

RegisterNetEvent('dw-garages:server:DenyJoinRequest', function(data)
    local src = source
    local requesterId = data.requesterId
    
    local requesterPlayer = ESX.GetPlayerFromIdentifier(requesterId)
    if requesterPlayer then
        TriggerClientEvent('esx:showNotification', requesterPlayer.source, 
            "Your request to join the shared garage has been denied", "error")
    end
    
    TriggerClientEvent('esx:showNotification', src, "Denied garage membership request")
end)

ESX.RegisterServerCallback('dw-garages:server:GetSharedGarages', function(source, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        return cb({}) 
    end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll("SHOW TABLES LIKE 'shared_garages'", {}, function(tableExists)
        if not tableExists or #tableExists == 0 then
            CreateSharedGaragesTables(src, function()
                cb({})
            end)
            return
        end
        
        MySQL.Async.fetchAll('SELECT DISTINCT sg.* FROM shared_garages sg LEFT JOIN shared_garage_members sgm ON sg.id = sgm.garage_id WHERE sgm.member_owner = ? OR sg.owner_owner = ?', 
            {owner, owner}, function(result)
                if result and #result > 0 then
                    for i, garage in ipairs(result) do
                        result[i].isOwner = (garage.owner_owner == owner)
                    end
                    cb(result)
                else
                    cb({})
                end
            end
        )
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetSharedGarageVehicles', function(source, cb, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    
    MySQL.Async.fetchAll('SELECT pv.*, u.firstname, u.lastname FROM owned_vehicles pv LEFT JOIN users u ON pv.owner = u.identifier WHERE pv.shared_garage_id = ? AND pv.state = 1', 
        {garageId}, function(vehicles)
            if vehicles and #vehicles > 0 then
                for i, vehicle in ipairs(vehicles) do
                    if vehicle.firstname and vehicle.lastname then
                        vehicles[i].owner_name = vehicle.firstname .. ' ' .. vehicle.lastname
                    else
                        vehicles[i].owner_name = "Unknown"
                    end
                    
                    -- Enrich vehicle data with details from okokvehicleshopv2
                    EnrichVehicleData(vehicles[i])
                end
                cb(vehicles)
            else
                cb({})
            end
        end
    )
end)

function getSharedGarageVehicles(garageId, owner, cb)
    MySQL.Async.fetchAll('SELECT pv.*, u.firstname, u.lastname FROM owned_vehicles pv LEFT JOIN users u ON pv.owner = u.identifier WHERE pv.shared_garage_id = ?', 
        {garageId}, function(vehicles)
            if vehicles and #vehicles > 0 then
                for i, vehicle in ipairs(vehicles) do
                    if vehicle.firstname and vehicle.lastname then
                        vehicles[i].owner_name = vehicle.firstname .. ' ' .. vehicle.lastname
                    else
                        vehicles[i].owner_name = "Unknown"
                    end
                    
                    -- Enrich vehicle data with details from okokvehicleshopv2
                    EnrichVehicleData(vehicles[i])
                end
                cb(vehicles)
            else
                cb({})
            end
        end
    ) 
end


RegisterNetEvent('dw-garages:server:StoreVehicleInSharedGarage', function(plate, garageId, props, fuel, engineHealth, bodyHealth)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_owner = ?', 
        {garageId, owner}, function(memberResult)
            if not memberResult or #memberResult == 0 then
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
                    {garageId, owner}, function(ownerResult)
                        if not ownerResult or #ownerResult == 0 then
                            TriggerClientEvent('esx:showNotification', src, "You don't have access to this shared garage")
                            return
                        end
                        
                        storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
                    end
                )
            else
                storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
            end
        end
    )
end)

function storeVehicleInSharedGarage(src, plate, garageId, props, fuel, engineHealth, bodyHealth)
    local xPlayer = ESX.GetPlayerFromId(src)
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, "You don't own this vehicle")
            return
        end
        
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM owned_vehicles WHERE shared_garage_id = ?', 
            {garageId}, function(countResult)
                if countResult[1].count >= Config.MaxSharedVehicles then
                    TriggerClientEvent('esx:showNotification', src, "Shared garage is full")
                    return
                end
                
                MySQL.Async.execute('UPDATE owned_vehicles SET shared_garage_id = ?, mods = ?, fuel = ?, engine = ?, body = ?, state = 1, stored = 1 WHERE plate = ?', 
                    {garageId, json.encode(props), fuel, engineHealth, bodyHealth, plate}, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('esx:showNotification', src, "Vehicle stored in shared garage")
                            
                            TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                        else
                            TriggerClientEvent('esx:showNotification', src, "Failed to store vehicle")
                        end
                    end
                )
            end
        )
    end)
end

RegisterNetEvent('dw-garages:server:UpdateVehicleState', function(plate, state)
    -- Remove the 'stored' column reference
    MySQL.Async.execute('UPDATE owned_vehicles SET state = ?, last_update = ? WHERE plate = ?', 
        {state, os.time(), plate}, 
        function(rowsChanged)
            if rowsChanged > 0 then
                
                -- Update OutsideVehicles tracking table
                if state == 0 then
                    OutsideVehicles[plate] = true
                else
                    OutsideVehicles[plate] = nil
                end
            else
                Wait (100)
            end
        end
    )
end)

RegisterNetEvent('dw-garages:server:RemoveVehicleFromSharedGarage', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', 
        {plate, owner}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "You don't own this vehicle")
                TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end
            
            -- Remove from shared garage
            MySQL.Async.execute('UPDATE owned_vehicles SET shared_garage_id = NULL WHERE plate = ?', 
                {plate}, function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('esx:showNotification', src, "Vehicle removed from shared garage")
                        
                        TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, true, plate)
                        
                        TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                    else
                        TriggerClientEvent('esx:showNotification', src, "Failed to remove vehicle")
                        TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                    end
                end
            )
        end
    )
end)

RegisterNetEvent('dw-garages:server:TakeOutSharedVehicle', function(plate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_owner = ?', 
        {garageId, owner}, function(memberResult)
            if not memberResult or #memberResult == 0 then
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
                    {garageId, owner}, function(ownerResult)
                        if not ownerResult or #ownerResult == 0 then
                            TriggerClientEvent('esx:showNotification', src, "You don't have access to this shared garage")
                            return
                        end
                        
                        takeOutSharedVehicle(src, plate, garageId)
                    end
                )
            else
                takeOutSharedVehicle(src, plate, garageId)
            end
        end
    )
end)

-- Modify in server.lua
function CheckForLostVehicles()
    local currentTime = os.time()
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE state = 0', {}, function(vehicles)
        if not vehicles or #vehicles == 0 then return end
        
        for _, vehicle in ipairs(vehicles) do
            local lastUpdate = vehicle.last_update or 0
            
            -- If vehicle has been out for more than the configured timeout
            if (currentTime - lastUpdate) > Config.LostVehicleTimeout then
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
                    {
                        currentTime, 
                        "Vehicle abandoned or lost", 
                        "Automated System", 
                        "police", 
                        Config.ImpoundFee, 
                        vehicle.plate
                    }
                )
                if OutsideVehicles[vehicle.plate] then
                    OutsideVehicles[vehicle.plate] = nil
                end
            end
        end
    end)
end

RegisterNetEvent('vehiclemod:server:syncDeletion', function(netId, plate)
    if plate then
        -- Clean the plate (remove spaces)
        plate = plate:gsub("%s+", "")
        
        -- Check if this is a player-owned vehicle
        MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()
                
                -- Update vehicle to impound state
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
                    {
                        currentTime, 
                        "Vehicle was towed", 
                        "City Towing", 
                        "police", 
                        Config.ImpoundFee, 
                        plate
                    }
                )
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)


CreateThread(function()
    Wait(60000) -- Wait 1 minute after resource start
    
    while true do
        CheckForLostVehicles()
        Wait(300000) -- Check every 5 minutes
    end
end)


CreateThread(function()
    while true do
        Wait(3600000)
        CheckForLostVehicles()
    end
end)

function takeOutSharedVehicle(src, plate, garageId)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND shared_garage_id = ? AND state = 1', 
        {plate, garageId}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "Vehicle not found or already taken out")
                return
            end
            
            -- Just update state without removing shared_garage_id association
            MySQL.Async.execute('UPDATE owned_vehicles SET state = 0, stored = 0 WHERE plate = ?', 
                {plate}, function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('esx:showNotification', src, "Vehicle taken out from shared garage")
                        TriggerClientEvent('dw-garages:client:TakeOutSharedVehicle', src, plate, result[1])
                    else
                        TriggerClientEvent('esx:showNotification', src, "Failed to take out vehicle")
                    end
                end
            )
        end
    )
end


ESX.RegisterServerCallback('dw-garages:server:CheckVehicleStatus', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT state FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            -- Return true if state is 1 (in garage), false otherwise
            cb(result[1].state == 1)
        else
            cb(false)
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetSharedGarageMembers', function(source, cb, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb({}) end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
        {garageId, owner}, function(result)
            if not result or #result == 0 then
                cb({})
                return
            end
            
            -- Get members
            MySQL.Async.fetchAll('SELECT sgm.*, p.charinfo FROM shared_garage_members sgm LEFT JOIN players p ON sgm.member_owner = p.owner WHERE sgm.garage_id = ?', 
                {garageId}, function(members)
                    if members and #members > 0 then
                        local formattedMembers = {}
                        for i, member in ipairs(members) do
                            local charinfo = json.decode(member.charinfo)
                            local memberData = {
                                id = member.id,
                                owner = member.member_owner,
                                name = "Unknown"
                            }
                            
                            if charinfo then
                                memberData.name = charinfo.firstname .. ' ' .. charinfo.lastname
                            end
                            
                            if member.member_owner ~= owner then
                                table.insert(formattedMembers, memberData)
                            end
                        end
                        cb(formattedMembers)
                    else
                        cb({})
                    end
                end
            )
        end
    )
end)

RegisterNetEvent('dw-garages:server:HandleDeletedVehicle', function(plate)
    if not plate then return end
    
    plate = plate:gsub("%s+", "")
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ? WHERE plate = ? AND state = 0', 
                {os.time(), plate}, 
                function(rowsChanged)
                    if rowsChanged > 0 then
                    end
                end
            )
        end
    end)
end)

RegisterNetEvent('esx:deleteServerVehicle', function(netId)
    -- This event is triggered from the client when a vehicle is deleted
    if netId then
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) then
            local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
            if plate then
                -- Update the database to set the vehicle to impound
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ? WHERE plate = ? AND state = 0', 
                    {os.time(), plate},
                    function(rowsChanged)
                        if rowsChanged > 0 then
                        end
                    end
                )
            end
        end
    end
end)

RegisterNetEvent('esx:onVehicleDelete', function(plate)
    if not plate then return end
    
    -- Clean the plate (remove spaces)
    plate = plate:gsub("%s+", "")
    
    -- Check if this is a player-owned vehicle
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            local currentTime = os.time()
            
            -- Update vehicle to impound state
            MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
                {
                    currentTime, 
                    "Vehicle was towed", 
                    "City Towing", 
                    "police", 
                    Config.ImpoundFee, 
                    plate
                }
            )
            if OutsideVehicles[plate] then
                OutsideVehicles[plate] = nil
            end
        end
    end)
end)


RegisterNetEvent('vehiclemod:server:syncDeletion', function(netId, plate)
    if plate then
        -- Clean the plate (remove spaces)
        plate = plate:gsub("%s+", "")
        
        -- Check if this is a player-owned vehicle
        MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()
                
                -- Update vehicle to impound state
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
                    {
                        currentTime, 
                        "Vehicle was towed", 
                        "City Towing", 
                        "police", 
                        Config.ImpoundFee, 
                        plate
                    }
                )
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)

RegisterNetEvent('qb-garage:server:UpdateOutsideVehicles', function(plate, state)
    if plate and state == 2 then
        -- Vehicle was deleted/impounded by some external script
        MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
            if result and #result > 0 then
                local currentTime = os.time()
                
                -- Update vehicle to impound state
                MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
                    {
                        currentTime, 
                        "Vehicle was towed", 
                        "City Towing", 
                        "police", 
                        Config.ImpoundFee, 
                        plate
                    }
                )
                if OutsideVehicles[plate] then
                    OutsideVehicles[plate] = nil
                end
            end
        end)
    end
end)

RegisterNetEvent('dw-garages:server:RemoveMemberFromSharedGarage', function(memberId, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
        {garageId, owner}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "You don't own this garage")
                return
            end
            
            MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE id = ? AND garage_id = ?', 
                {memberId, garageId}, function(memberResult)
                    if not memberResult or #memberResult == 0 then
                        TriggerClientEvent('esx:showNotification', src, "Member not found")
                        return
                    end
                    
                    MySQL.Async.execute('DELETE FROM shared_garage_members WHERE id = ?', 
                        {memberId}, function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('esx:showNotification', src, "Member removed from shared garage")
                                
                                local memberCitizenid = memberResult[1].member_owner
                                local memberPlayer = ESX.GetPlayerFromIdentifier(memberCitizenid)
                                if memberPlayer then
                                    TriggerClientEvent('esx:showNotification', memberPlayer.source, 
                                        "You have been removed from " .. result[1].name .. " shared garage", "error")
                                end
                            else
                                TriggerClientEvent('esx:showNotification', src, "Failed to remove member")
                            end
                        end
                    )
                end
            )
        end
    )
end)

RegisterNetEvent('dw-garages:server:DeleteSharedGarage', function(garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier
    MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
        {garageId, owner}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "You don't own this garage")
                return
            end
            
            MySQL.Async.execute('UPDATE owned_vehicles SET shared_garage_id = NULL WHERE shared_garage_id = ?', 
                {garageId}, function()
                    MySQL.Async.execute('DELETE FROM shared_garage_members WHERE garage_id = ?', {garageId})
                    
                    MySQL.Async.execute('DELETE FROM shared_garages WHERE id = ?', {garageId}, function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('esx:showNotification', src, "Shared garage deleted")
                        else
                            TriggerClientEvent('esx:showNotification', src, "Failed to delete shared garage")
                        end
                    end)
                end
            )
        end
    )
end)

ESX.RegisterServerCallback('dw-garages:server:StoreInSelectedSharedGarage', function(source, cb, plate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return cb({status = "error", message = "Player not found"}) end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, "You don't own this vehicle")
            return cb({status = "error", message = "Vehicle ownership verification failed"})
        end
        
        if result[1].state ~= 1 then
            TriggerClientEvent('esx:showNotification', src, "Vehicle must be stored to share it")
            return cb({status = "error", message = "Vehicle must be stored"})
        end
        
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM owned_vehicles WHERE shared_garage_id = ?', {garageId}, function(countResult)
            if countResult[1].count >= Config.MaxSharedVehicles then
                TriggerClientEvent('esx:showNotification', src, "Shared garage is full")
                return cb({status = "error", message = "Shared garage is full"})
            end
            
            MySQL.Async.execute('UPDATE owned_vehicles SET shared_garage_id = ? WHERE plate = ?', {garageId, plate}, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('esx:showNotification', src, "Vehicle stored in shared garage")
                    TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                    return cb({status = "success"})
                else
                    TriggerClientEvent('esx:showNotification', src, "Failed to store vehicle in shared garage")
                    return cb({status = "error", message = "Database update failed"})
                end
            end)
        end)
    end)
end)

RegisterNetEvent('dw-garages:server:TransferVehicleToSharedGarage', function(plate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local owner = xPlayer.identifier    
    MySQL.Async.fetchAll('SELECT * FROM shared_garage_members WHERE garage_id = ? AND member_owner = ?', 
        {garageId, owner}, function(memberResult)
            local hasAccess = false
            
            if memberResult and #memberResult > 0 then
                hasAccess = true
            else
                MySQL.Async.fetchAll('SELECT * FROM shared_garages WHERE id = ? AND owner_owner = ?', 
                    {garageId, owner}, function(ownerResult)
                        if ownerResult and #ownerResult > 0 then
                            hasAccess = true
                        end
                        
                        if hasAccess then
                            TransferVehicleToSharedGarage(src, plate, garageId, owner)
                        else
                            TriggerClientEvent('esx:showNotification', src, "You don't have access to this shared garage")
                            TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                        end
                    end
                )
                return 
            end
            
            if hasAccess then
                TransferVehicleToSharedGarage(src, plate, garageId, owner)
            end
        end
    )
end)

function TransferVehicleToSharedGarage(src, plate, garageId, owner)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', 
        {plate, owner}, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('esx:showNotification', src, "You don't own this vehicle")
                TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end
            
            if result[1].state ~= 1 then
                TriggerClientEvent('esx:showNotification', src, "Vehicle must be stored in a garage to transfer it")
                -- Notify client that transfer failed
                TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                return
            end
            
            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM owned_vehicles WHERE shared_garage_id = ?', 
                {garageId}, function(countResult)
                    if countResult[1].count >= Config.MaxSharedVehicles then
                        TriggerClientEvent('esx:showNotification', src, "Shared garage is full")
                        TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                        return
                    end
                    
                    MySQL.Async.execute('UPDATE owned_vehicles SET shared_garage_id = ? WHERE plate = ?', 
                        {garageId, plate}, function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('esx:showNotification', src, "Vehicle transferred to shared garage")
                                
                                TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, true, plate)
                                
                                TriggerClientEvent('dw-garages:client:RefreshVehicleList', src)
                            else
                                TriggerClientEvent('esx:showNotification', src, "Failed to transfer vehicle")
                                TriggerClientEvent('dw-garages:client:VehicleTransferCompleted', src, false, plate)
                            end
                        end
                    )
                end
            )
        end
    )
end

ESX.RegisterServerCallback('dw-garages:server:CheckIfVehicleOwned', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    local owner = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, owner}, function(result)
        if result and #result > 0 then
            cb(true)
        else
            if xPlayer.gang and xPlayer.gang.name ~= "none" then
                MySQL.Async.fetchAll('SELECT * FROM gang_vehicles WHERE plate = ? AND gang = ?', {plate, xPlayer.gang.name}, function(gangResult)
                    cb(gangResult and #gangResult > 0)
                end)
            else
                cb(false)
            end
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetVehicleInfo', function(source, cb, plate)
    if not plate then return cb(nil) end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    
    MySQL.Async.fetchAll('SELECT pv.*, u.firstname, u.lastname FROM owned_vehicles pv LEFT JOIN users u ON pv.owner = u.identifier WHERE pv.plate = ?', {plate}, function(result)
        if result and #result > 0 then
            local vehicleInfo = result[1]
            local ownerName = "Unknown"
            
            if vehicleInfo.firstname and vehicleInfo.lastname then
                ownerName = vehicleInfo.firstname .. ' ' .. vehicleInfo.lastname
            end
            
            if vehicleInfo.owner == xPlayer.identifier then
                ownerName = "You"
            end
            
            local formattedInfo = {
                name = vehicleInfo.custom_name or nil,
                ownerName = ownerName,
                garage = vehicleInfo.garage or "Unknown",
                state = vehicleInfo.state or 1,
                storedInGang = vehicleInfo.stored_in_gang ~= nil,
                storedInShared = vehicleInfo.shared_garage_id ~= nil,
                isOwner = vehicleInfo.owner == xPlayer.identifier
            }
            
            cb(formattedInfo)
        else
            cb(nil)
        end
    end)
end)

RegisterNetEvent('dw-garages:server:CreateSharedGaragesTables')
AddEventHandler('dw-garages:server:CreateSharedGaragesTables', function()
    local src = source
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS shared_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            owner_owner VARCHAR(50) NOT NULL,
            access_code VARCHAR(10) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS shared_garage_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                garage_id INT NOT NULL,
                member_owner VARCHAR(50) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (garage_id) REFERENCES shared_garages(id) ON DELETE CASCADE
            )
        ]], {}, function()
            MySQL.Async.execute([[
                ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS shared_garage_id INT NULL;
                ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS is_favorite INT DEFAULT 0;
            ]], {}, function()
                TriggerClientEvent('esx:showNotification', src, "Shared garages feature initialized")
            end)
        end)
    end)
end)

function CreateSharedGaragesTables(src, callback)    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS shared_garages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) NOT NULL,
            owner_owner VARCHAR(50) NOT NULL,
            access_code VARCHAR(10) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS shared_garage_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                garage_id INT NOT NULL,
                member_owner VARCHAR(50) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (garage_id) REFERENCES shared_garages(id) ON DELETE CASCADE
            )
        ]], {}, function()
            MySQL.Async.execute([[
                ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS shared_garage_id INT NULL
            ]], {}, function()
                TriggerClientEvent('esx:showNotification', src, "Shared garages feature initialized")
                callback()
            end)
        end)
    end)
end

ESX.RegisterServerCallback('dw-garages:server:CheckSharedGaragesTables', function(source, cb)
    MySQL.Async.fetchAll("SHOW TABLES LIKE 'shared_garages'", {}, function(result)
        cb(result and #result > 0)
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:CanPayImpoundFee', function(source, cb, fee)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    
    if xPlayer.getMoney() >= fee then
        cb(true)
    elseif xPlayer.getAccount('bank').money >= fee then
        cb(true)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback('dw-garages:server:GetVehicleByPlate', function(source, cb, plate)
    if OutsideVehicles[plate] then
        cb(nil, true) -- Vehicle is already outside
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result and #result > 0 then
            if result[1].state == 0 then
                cb(nil, true) -- Vehicle is already out according to DB
            else
                cb(result[1], false) -- Vehicle is available
            end
        else
            cb(nil, false) -- Vehicle not found
        end
    end)
end)
-- Pay impound fee and release vehicle
RegisterNetEvent('dw-garages:server:PayImpoundFee', function(plate, fee)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE plate = ? AND state = 2', {plate}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, "Vehicle not found or already released")
            return
        end
        local vehicle = result[1]
        local actualFee = Config.ImpoundFee  -- Default fee
        if vehicle.impoundfee ~= nil then
            local customFee = tonumber(vehicle.impoundfee)
            if customFee and customFee > 0 then
                actualFee = customFee
            end
        end
        
        
        if xPlayer.getMoney() >= actualFee then
            xPlayer.removeMoney(actualFee, "impound-fee")
        else
            xPlayer.removeAccountMoney('bank', actualFee, "impound-fee")
        end
        MySQL.Async.execute('UPDATE owned_vehicles SET state = 0, garage = NULL, impoundedtime = NULL, impoundreason = NULL, impoundedby = NULL, impoundtype = NULL, impoundfee = NULL, impoundtime = NULL WHERE plate = ?', {plate}, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('esx:showNotification', src, "You paid $" .. actualFee .. " to release your vehicle")
            end
        end)
    end)
end)

RegisterNetEvent('dw-garages:server:ImpoundVehicle', function(plate, props, reason, impoundType, jobName, officerName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    if not Config.ImpoundJobs[xPlayer.job.name] then
        TriggerClientEvent('esx:showNotification', src, "You are not authorized to impound vehicles")
        return
    end
    MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ? WHERE plate = ?', 
        {os.time(), reason, officerName, impoundType, plate}, 
        function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('esx:showNotification', src, "Vehicle impounded successfully")
                
                local logData = {
                    plate = plate,
                    impoundedBy = officerName,
                    job = jobName,
                    reason = reason,
                    type = impoundType,
                    timestamp = os.time()
                }
                                
                MySQL.Async.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
                    if result and #result > 0 then
                        local ownerCitizenId = result[1].owner
                        local ownerPlayer = ESX.GetPlayerFromIdentifier(ownerCitizenId)
                        
                        if ownerPlayer then
                            TriggerClientEvent('esx:showNotification', ownerPlayer.source, "Your vehicle with plate " .. plate .. " has been impounded", "error")
                        end
                    end
                end)
            else
                TriggerClientEvent('esx:showNotification', src, "Failed to impound vehicle - Vehicle not found in database")
            end
        end
    )
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    MySQL.Async.fetchAll('SHOW COLUMNS FROM owned_vehicles LIKE "impoundedtime"', {}, function(result)
        if result and #result > 0 then
        else
            Wait (100)
        end
    end)
end)

RegisterNetEvent('dw-garages:server:ImpoundVehicleWithParams', function(plate, props, reason, impoundType, jobName, officerName, impoundFee)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    if not Config.ImpoundJobs[xPlayer.job.name] then
        TriggerClientEvent('esx:showNotification', src, "You are not authorized to impound vehicles")
        return
    end
    local fee = tonumber(impoundFee)
    MySQL.Async.execute('UPDATE owned_vehicles SET state = 2, garage = "impound", impoundedtime = ?, impoundreason = ?, impoundedby = ?, impoundtype = ?, impoundfee = ? WHERE plate = ?', 
        {os.time(), reason, officerName, impoundType, fee, plate}, 
        function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('esx:showNotification', src, "Vehicle impounded with $" .. fee .. " fine")
                
                local logData = {
                    plate = plate,
                    impoundedBy = officerName,
                    job = jobName,
                    reason = reason,
                    type = impoundType,
                    fee = fee,
                    timestamp = os.time()
                }
                            
                MySQL.Async.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
                    if result and #result > 0 then
                        local ownerCitizenId = result[1].owner
                        local ownerPlayer = ESX.GetPlayerFromIdentifier(ownerCitizenId)
                        
                        if ownerPlayer then
                            TriggerClientEvent('esx:showNotification', ownerPlayer.source, 
                                "Your vehicle with plate " .. plate .. " has been impounded", "error")
                        end
                    end
                end)
            else
                TriggerClientEvent('esx:showNotification', src, "Failed to impound vehicle - Vehicle not found in database")
            end
        end
    )
end)


MySQL.Async.execute([[
    SHOW COLUMNS FROM owned_vehicles LIKE 'impoundedtime';
]], {}, function(result)
    if result and #result == 0 then
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundedtime INT NULL;", {})
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundreason VARCHAR(255) NULL;", {})
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundedby VARCHAR(255) NULL;", {})
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundtype VARCHAR(50) NULL;", {})
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundfee INT NULL;", {})
        MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN impoundtime INT NULL;", {})
    else
        Wait (100)
    end
end)

ESX.RegisterServerCallback('dw-garages:server:GetImpoundedVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    
    local owner = xPlayer.identifier
    
    -- Make sure we're properly selecting impounded vehicles (state = 2)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = ? AND state = 2', {owner}, function(result)
        if result and #result > 0 then
            -- Enrich vehicle data with details from okokvehicleshopv2
            for i, vehicle in ipairs(result) do
                EnrichVehicleData(vehicle)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

ESX.RegisterServerCallback('dw-garages:server:GetJobGarageVehicles', function(source, cb, garageId)
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE garage = ? AND state = 1', {garageId}, function(result)
        if result and #result > 0 then
            for i, vehicle in ipairs(result) do
                EnrichVehicleData(vehicle)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

-- Test command to verify okokvehicleshopv2 integration (only if debug enabled)
if Config.EnableDebugCommands then
    RegisterCommand('testgarageintegration', function(source, args)
        local src = source
        local model = args[1] or 'adder'
        
        -- Test the vehicle details retrieval
        local vehicleInfo = GetVehicleDetailsFromShop(model)
        
        print('========================================')
        print('[DW Garages] Integration Test')
        print('========================================')
        print('Model: ' .. model)
        print('Name: ' .. vehicleInfo.name)
        print('Category: ' .. vehicleInfo.category)
        print('Speed: ' .. vehicleInfo.speed)
        print('========================================')
        
        if src > 0 then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                TriggerClientEvent('esx:showNotification', src, 
                    'Vehicle Test: ' .. vehicleInfo.name .. ' | Category: ' .. vehicleInfo.category,
                    'info'
                )
            end
        end
    end, false)
    
    print('[DW Garages] Debug commands enabled')
end

print('[DW Garages] okokvehicleshopv2 integration loaded successfully')
