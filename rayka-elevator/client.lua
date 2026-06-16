local menuOpen, currentElevators, insideZone, activeElevator = false, {}, false, nil
local Framework = "standalone"
local PlayerJob = "public"

CreateThread(function()
    Wait(500)
    if GetResourceState('es_extended') == 'started' then
        local ESX = nil
        pcall(function() ESX = exports['es_extended']:getSharedObject() end)
        if not ESX then
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        end
        
        if ESX then
            Framework = "esx"
            if ESX.IsPlayerLoaded and ESX.IsPlayerLoaded() then
                local playerData = ESX.GetPlayerData()
                if playerData and playerData.job then PlayerJob = playerData.job.name end
            end
            RegisterNetEvent('esx:setJob', function(job)
                if job and job.name then PlayerJob = job.name end
            end)
        end
    elseif GetResourceState('qbox') == 'started' then
        Framework = "qbox"
        local playerState = exports.qbox:GetPlayerState()
        if playerState and playerState.job then PlayerJob = playerState.job.name end
        
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
            if JobInfo and JobInfo.name then PlayerJob = JobInfo.name end
        end)
    elseif GetResourceState('qb-core') == 'started' then
        Framework = "qbcore"
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions.GetPlayerData() then
            local playerData = QBCore.Functions.GetPlayerData()
            if playerData and playerData.job then PlayerJob = playerData.job.name end
        end
        
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
            if JobInfo and JobInfo.name then PlayerJob = JobInfo.name end
        end)
    else
        Framework = "standalone"
        PlayerJob = "public"
    end
end)

local function PlayerHasJob(jobName)
    if not jobName or jobName == "public" or jobName == "" then return true end
    if Framework == "standalone" then return true end
    return PlayerJob == jobName
end

RegisterCommand(Config.Settings.CommandName, function() 
    TriggerServerEvent('rayka-elevator:server:requestList') 
end, false)

RegisterNetEvent('rayka-elevator:client:openMenu', function(sqlData)
    currentElevators = sqlData or {}
    menuOpen = true
    SendNUIMessage({ action = "openElevatorMenu", sqlList = currentElevators })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('rayka-elevator:client:updateLocalData', function(sqlData) currentElevators = sqlData or {} end)
RegisterNetEvent('rayka-elevator:client:receiveListSilent', function(sqlData) currentElevators = sqlData or {} end)

RegisterNUICallback('closeMenu', function(d, cb) menuOpen = false; SetNuiFocus(false, false); cb('ok') end)
RegisterNUICallback('toggleMouse', function(d, cb) SetNuiFocus(d.enable, d.enable); cb('ok') end)

RegisterNUICallback('updateElevatorsOrder', function(data, cb)
    if data and data.orderList then
        local tempMap = {}
        for _, v in ipairs(data.orderList) do tempMap[v.id] = v.order end
        
        table.sort(currentElevators, function(a, b)
            local orderA = tempMap[a.id] or 999
            local orderB = tempMap[b.id] or 999
            return orderA < orderB
        end)
        TriggerServerEvent('rayka-elevator:server:updateOrder', data.orderList)
    end
    cb('ok')
end)

local function TogglePrompt(show)
    if show then 
        SendNUIMessage({ action = "showPrompt" })
    else 
        SendNUIMessage({ action = "hidePrompt" })
    end
end

local function OpenFloorsMenu(elevator, currentFloorKey)
    SendNUIMessage({ action = "openSelector", elevatorData = elevator, currentFloor = currentFloorKey })
    SetNuiFocus(true, true)
end

RegisterNUICallback('startSelectingLocation', function(data, cb)
    SetNuiFocus(false, false)
    local locId = data.locationIdentifier
    CreateThread(function()
        local selecting = true
        if GetResourceState('ox_lib') == 'started' then
            exports.ox_lib:showTextUI('Press [ENTER] to Save Position', {position = 'top-center'})
        end
        while selecting do
            Wait(0)
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            DrawMarker(Config.Marker.Type, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Marker.Size.x, Config.Marker.Size.y, Config.Marker.Size.z, Config.Marker.Color.r, Config.Marker.Color.g, Config.Marker.Color.b, Config.Marker.Color.a, false, false, 2, false, nil, nil, false)
            if IsControlJustPressed(0, 18) then
                selecting = false
                if GetResourceState('ox_lib') == 'started' then exports.ox_lib:hideTextUI() end
                SendNUIMessage({ action = "showMenuAgain", locationSavedId = locId, clientCoords = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) } })
                SetNuiFocus(true, true)
            end
        end
    end)
    cb('ok')
end)

RegisterNUICallback('buildElevator', function(d, cb) menuOpen = false; SetNuiFocus(false, false); TriggerServerEvent('rayka-elevator:server:saveElevator', d); cb('ok') end)
RegisterNUICallback('deleteElevator', function(d, cb) menuOpen = false; SetNuiFocus(false, false); TriggerServerEvent('rayka-elevator:server:deleteElevator', d.id); cb('ok') end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('rayka-elevator:server:requestListSilent')
    while true do
        local sleep, ped, found = 500, PlayerPedId(), false
        local coords = GetEntityCoords(ped)

        for _, elevator in ipairs(currentElevators) do
            local floors = json.decode(elevator.floors)
            if floors then
                for floorKey, status in pairs(floors) do
                    if type(status) == "table" and status.coords then
                        local target = vector3(status.coords.x, status.coords.y, status.coords.z)
                        local dist = #(coords - target)
                        
                        if dist < 1.5 then
                            sleep = 0
                            if not insideZone and not IsPedInAnyVehicle(ped, true) then
                                insideZone, activeElevator = true, {data = elevator, currentFloor = floorKey}
                                TogglePrompt(true)
                            end
                            if IsControlJustPressed(0, 38) and not IsPedInAnyVehicle(ped, true) then
                                TogglePrompt(false)
                                if PlayerHasJob(elevator.job) then
                                    OpenFloorsMenu(elevator, floorKey)
                                else
                                    TriggerServerEvent('rayka-elevator:server:denyNotice', elevator.name)
                                end
                            end
                            found = true
                        end
                    end
                end
            end
        end
        if insideZone and not found then insideZone, activeElevator = false, nil; TogglePrompt(false) end
        Wait(sleep)
    end
end)

RegisterNetEvent('rayka-elevator:client:finalTeleportExec', function(targetCoords, targetName)
    local ped = PlayerPedId()
    insideZone = false
    SetNuiFocus(false, false)
    TogglePrompt(false)
    
    SendNUIMessage({ action = "playSoundSilent" }) 
    DoScreenFadeOut(250)
    Wait(300) 
    
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, false)
    if targetCoords.h then SetEntityHeading(ped, targetCoords.h) end
    
    Wait(800)
    
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(300)
end)

RegisterNUICallback('executeTeleport', function(data, cb)
    insideZone = false
    SetNuiFocus(false, false)
    TriggerServerEvent('rayka-elevator:server:bridgeTeleport', data.id, data.floor)
    cb('ok')
end)