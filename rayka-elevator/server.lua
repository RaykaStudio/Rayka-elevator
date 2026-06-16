local ESX = nil
if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
end

local function SendNotification(src, title, msg, msgType)
    local nType = Config.NotifyType
    if nType == 'ox' then
        TriggerClientEvent('ox_lib:notify', src, {title = title, description = msg, type = msgType})
    elseif nType == 'qb' then
        local qbType = msgType == 'error' and 'error' or (msgType == 'success' and 'success' or 'primary')
        TriggerClientEvent('QBCore:Notify', src, msg, qbType)
    elseif nType == 'esx' then
        local esxType = msgType == 'error' and 'error' or (msgType == 'success' and 'success' or 'info')
        TriggerClientEvent('esx:showNotification', src, msg, esxType)
    end
end

local function UpdateAllClients(src, action, msg, msgType)
    exports.oxmysql:query('SELECT * FROM rayka_elevators ORDER BY menu_order ASC', {}, function(results)
        if src and msg then 
            SendNotification(src, 'Rayka Studios', msg, msgType)
        end
        TriggerClientEvent('rayka-elevator:client:updateLocalData', -1, results or {})
        if action == 'open' and src then TriggerClientEvent('rayka-elevator:client:openMenu', src, results or {}) end
        if action == 'silent' and src then TriggerClientEvent('rayka-elevator:client:receiveListSilent', src, results or {}) end
    end)
end

RegisterNetEvent('rayka-elevator:server:requestListSilent', function() UpdateAllClients(source, 'silent') end)

RegisterNetEvent('rayka-elevator:server:requestList', function() 
    local src = source
    local isAdmin = false

    if IsPlayerAceAllowed(src, "command.elevator") or IsPlayerAceAllowed(src, "command") then
        isAdmin = true
    end

    if not isAdmin then
        if Config.Framework == 'qb' or Config.Framework == 'qbcore' then
            local QBCore = exports['qb-core']:GetCoreObject()
            if QBCore then
                isAdmin = QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
                if not isAdmin then
                    local Player = QBCore.Functions.GetPlayer(src)
                    if Player and (Player.PlayerData.job.name == 'admin' or Player.PlayerData.job.isboss) then
                        isAdmin = true
                    end
                end
            end
        elseif Config.Framework == 'esx' then
            local xPlayer = ESX and ESX.GetPlayerFromId(src) or exports['es_extended']:getSharedObject().GetPlayerFromId(src)
            if xPlayer then
                local playerGroup = xPlayer.getGroup()
                if playerGroup == 'admin' or playerGroup == 'superadmin' or playerGroup == '_dev' then 
                    isAdmin = true 
                end
            end
        end
    end

    if isAdmin then
        UpdateAllClients(src, 'open')
    else
        SendNotification(src, 'System', 'You do not have permission to use Creator Menu!', 'error')
    end
end)

RegisterNetEvent('rayka-elevator:server:denyNotice', function(elevatorName)
    local src = source
    SendNotification(src, elevatorName or 'Elevator', 'Access Denied: You do not have the required job!', 'error')
end)

RegisterNetEvent('rayka-elevator:server:updateOrder', function(orderList)
    if not orderList or #orderList == 0 then return end
    local queries = {}
    for _, v in ipairs(orderList) do
        table.insert(queries, {
            query = 'UPDATE rayka_elevators SET menu_order = ? WHERE id = ?',
            values = {v.order, v.id}
        })
    end

    exports.oxmysql:transaction(queries, function(success)
        if success then
            exports.oxmysql:query('SELECT * FROM rayka_elevators ORDER BY menu_order ASC', {}, function(results)
                TriggerClientEvent('rayka-elevator:client:updateLocalData', -1, results or {})
            end)
        end
    end)
end)

RegisterNetEvent('rayka-elevator:server:saveElevator', function(data)
    local src = source
    local floorsJson = json.encode(data.floors)
    local cleanJob = data.meta.job and data.meta.job:gsub("%s+", "") or "public"

    if data.id then
        exports.oxmysql:query('UPDATE rayka_elevators SET name = ?, job = ?, floors = ? WHERE id = ?', {data.meta.name, cleanJob, floorsJson, data.id}, function()
            UpdateAllClients(src, nil, 'Elevator modified successfully!', 'success')
        end)
    else
        exports.oxmysql:query('INSERT INTO rayka_elevators (name, job, floors, menu_order) VALUES (?, ?, ?, ?)', {data.meta.name, cleanJob, floorsJson, 0}, function()
            UpdateAllClients(src, nil, 'New elevator deployed!', 'success')
        end)
    end
end)

RegisterNetEvent('rayka-elevator:server:deleteElevator', function(id)
    local src = source
    if not id then return end
    exports.oxmysql:query('DELETE FROM rayka_elevators WHERE id = ?', {id}, function()
        UpdateAllClients(src, nil, 'Elevator successfully removed.', 'error')
    end)
end)

RegisterNetEvent('rayka-elevator:server:bridgeTeleport', function(elevatorId, floorKey)
    local src = source
    if type(elevatorId) == "table" then
        floorKey = elevatorId[2] or elevatorId.floor
        elevatorId = elevatorId[1] or elevatorId.id
    end

    exports.oxmysql:query('SELECT * FROM rayka_elevators WHERE id = ?', {elevatorId}, function(results)
        if not results or not results[1] then return end
        local elevator = results[1]
        local targetFloor = json.decode(elevator.floors)[floorKey]
        
        if targetFloor and targetFloor.coords then
            local canUse, reqJob = true, elevator.job
            
            if reqJob and reqJob ~= "public" and reqJob ~= "" then
                if Config.Framework == 'qb' or Config.Framework == 'qbcore' then
                    local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
                    if not Player or Player.PlayerData.job.name ~= reqJob then canUse = false end
                elseif Config.Framework == 'esx' then
                    local xPlayer = ESX and ESX.GetPlayerFromId(src) or exports['es_extended']:getSharedObject().GetPlayerFromId(src)
                    if not xPlayer or xPlayer.job.name ~= reqJob then canUse = false end
                end
            end

            if canUse then
                TriggerClientEvent('rayka-elevator:client:finalTeleportExec', src, targetFloor.coords, targetFloor.name)
            else
                SendNotification(src, elevator.name or 'Elevator', 'Access Denied: You do not have the required job!', 'error')
            end
        end
    end)
end)