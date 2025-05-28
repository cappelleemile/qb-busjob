-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local route = 1
local max = #Config.NPCLocations.Locations
local busBlip = nil
local onDuty = false

local playerPed = PlayerPedId()

local NpcData = {
    Active = false,
    CurrentNpc = nil,
    LastNpc = nil,
    CurrentDeliver = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local BusData = {
    Active = false,
}

-- Functions
function DrawText3D(xyz, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(xyz, 0)
    DrawText(0.0, 0.0)
    DrawRect(0.0, 0.0115, 0.057, 0.028, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function resetNpcTask()
    NpcData = {
        Active = false,
        CurrentNpc = nil,
        LastNpc = nil,
        CurrentDeliver = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false,
    }
end

local function updateBlip()
    busBlip = AddBlipForCoord(Config.Station)
    SetBlipSprite(busBlip, 513)
    SetBlipDisplay(busBlip, 4)
    SetBlipScale(busBlip, 0.6)
    SetBlipAsShortRange(busBlip, true)
    SetBlipColour(busBlip, 49)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName('Busstation')
    EndTextCommandSetBlipName(busBlip)
end

local function whitelistedVehicle()
    local ped = PlayerPedId()
    local veh = GetEntityModel(GetVehiclePedIsIn(ped))
    local retval = false

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == Config.AllowedVehicles[i].model then
            retval = true
        end
    end

    return retval
end

local function nextStop()
    if route <= (max - 1) then
        route = route + 1
    else
        route = nil
        TriggerEvent('qb-busjob:client:RouteCompleted')
    end
end

local function GetDeliveryLocation()
    nextStop()

    if NpcData.DeliveryBlip ~= nil then
        RemoveBlip(NpcData.DeliveryBlip)
    end

    NpcData.DeliveryBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)

    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)

    NpcData.LastDeliver = route

    local inRange = false
    local playerCoords = GetEntityCoords(playerPed)
    local PolyZone = CircleZone:Create(vector3(Config.NPCLocations.Locations[route].x,
        Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z), 5, {
        name = "busjobdeliver",
        useZ = true,
    })

    PolyZone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inRange = true

            DrawText3D(vector3(playerCoords.x, playerCoords.y, playerCoords.z + 2.5), "~p~[E]~s~ Ophalen")

            CreateThread(function()
                repeat
                    Wait(0)

                    if IsControlJustPressed(0, 38) then
                        local ped = PlayerPedId()
                        local veh = GetVehiclePedIsIn(ped, 0)

                        TaskLeaveVehicle(NpcData.Npc, veh, 0)
                        SetEntityAsMissionEntity(NpcData.Npc, false, true)
                        SetEntityAsNoLongerNeeded(NpcData.Npc)

                        local targetCoords = Config.NPCLocations.Locations[NpcData.LastNpc]

                        TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

                        QBCore.Functions.Notify('Persoon is afgezet', 'success')

                        if NpcData.DeliveryBlip ~= nil then
                            RemoveBlip(NpcData.DeliveryBlip)
                        end

                        local RemovePed = function(pped)
                            SetTimeout(60000, function()
                                DeletePed(pped)
                            end)
                        end

                        RemovePed(NpcData.Npc)
                        resetNpcTask()
                        nextStop()

                        TriggerEvent('qb-busjob:client:DoBusNpc')

                        exports["qb-core"]:HideText()
                        PolyZone:destroy()
                        break
                    end
                until not inRange
            end)
        else
            exports["qb-core"]:HideText()
            inRange = false
        end
    end)
end

local function closeMenuFull()
    exports['qb-menu']:closeMenu()
end

local function busGarage()
    local vehicleMenu = {
        {
            header = 'Busvoertuigen',
            isMenuHeader = true
        }
    }
    for _, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = v.label,
            params = {
                event = "qb-busjob:client:TakeVehicle",
                args = {
                    model = v.model
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu + 1] = {
        header = '⬅ Menu Sluiten',
        params = {
            event = "qb-menu:client:closeMenu"
        }
    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

RegisterNetEvent("qb-busjob:client:TakeVehicle", function(data)
    local coords = Config.SpawnBus
    if (BusData.Active) then
        QBCore.Functions.Notify('Je kunt maar één actieve bus tegelijk hebben', 'error')
        return
    else
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            SetVehicleNumberPlateText(veh, 'BUS' .. tostring(math.random(1000, 9999)))
            exports['LegacyFuel']:SetFuel(veh, 100.0)
            closeMenuFull()
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
            SetVehicleEngineOn(veh, true, true)
        end, data.model, coords, true)
        Wait(1000)
        TriggerEvent('qb-busjob:client:DoBusNpc')
    end
end)

-- Events
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        updateBlip()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    updateBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    updateBlip()

end)

RegisterNetEvent('qb-busjob:client:DoBusNpc', function()
    if whitelistedVehicle() then
        if not NpcData.Active then
            local Gender = math.random(1, #Config.NpcSkins)
            local PedSkin = math.random(1, #Config.NpcSkins[Gender])
            local model = Config.NpcSkins[Gender][PedSkin]
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(0)
            end
            NpcData.Npc = CreatePed(3, model, Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z - 0.98, Config.NPCLocations.Locations[route].w, false, true)
            PlaceObjectOnGroundProperly(NpcData.Npc)
            FreezeEntityPosition(NpcData.Npc, true)
            if NpcData.NpcBlip ~= nil then
                RemoveBlip(NpcData.NpcBlip)
            end
            QBCore.Functions.Notify('Ga naar de opgegeven bushalte', 'primary')
            NpcData.NpcBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
            SetBlipColour(NpcData.NpcBlip, 3)
            SetBlipRoute(NpcData.NpcBlip, true)
            SetBlipRouteColour(NpcData.NpcBlip, 3)
            NpcData.LastNpc = route
            NpcData.Active = true
            local inRange = false
            local playerCoords = GetEntityCoords(playerPed)
            local PolyZone = CircleZone:Create(vector3(Config.NPCLocations.Locations[route].x,
                Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z), 5, {
                name = "busjobdeliver",
                useZ = true,
                -- debugPoly=true
            })
            PolyZone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    inRange = true
                    exports["qb-core"]:DrawText('[E] Bushalte', 'rgb(220, 20, 60)')
                    CreateThread(function()
                        repeat
                            Wait(5)
                            if IsControlJustPressed(0, 38) then
                                local ped = PlayerPedId()
                                local veh = GetVehiclePedIsIn(ped, 0)
                                local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(veh)

                                for i = maxSeats - 1, 0, -1 do
                                    if IsVehicleSeatFree(veh, i) then
                                        freeSeat = i
                                        break
                                    end
                                end

                                ClearPedTasksImmediately(NpcData.Npc)
                                FreezeEntityPosition(NpcData.Npc, false)
                                TaskEnterVehicle(NpcData.Npc, veh, -1, freeSeat, 1.0, 0)
                                QBCore.Functions.Notify('Ga naar de opgegeven bushalte', 'primary')
                                if NpcData.NpcBlip ~= nil then
                                    RemoveBlip(NpcData.NpcBlip)
                                end
                                GetDeliveryLocation()
                                NpcData.NpcTaken = true
                                TriggerServerEvent('qb-busjob:server:NpcPay')
                                exports["qb-core"]:HideText()
                                PolyZone:destroy()
                                break
                            end
                        until not inRange
                    end)
                else
                    exports["qb-core"]:HideText()
                    inRange = false
                end
            end)
        else
            QBCore.Functions.Notify('Je rijdt al in een bus', 'error')
        end
    else
        QBCore.Functions.Notify('Je zit niet in een bus', 'error')
    end
end)

RegisterNetEvent('qb-busjob:client:RouteCompleted', function()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle and whitelistedVehicle() then
        local vehicleCoords = GetEntityCoords(vehicle)
        local depotCoords = Config.Station

        local blip = AddBlipForCoord(depotCoords.x, depotCoords.y, depotCoords.z)
        SetBlipColour(blip, 2)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, 2)

        QBCore.Functions.Notify("Ga terug naar het busstation.", 'info')

        Citizen.CreateThread(function()
            while true do
                Wait(500)
                local vehicleCoords = GetEntityCoords(vehicle)
                if Vdist(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, depotCoords.x, depotCoords.y, depotCoords.z) < 10.0 then
                    RemoveBlip(blip)
                    DrawText3D(vector3(playerCoords.x, playerCoords.y, playerCoords.z + 2.5), "~p~[E]~s~ Stal bus")
                        if IsControlJustReleased(0, 38) then
                            if (not NpcData.Active or NpcData.Active and NpcData.NpcTaken == false) then
                                if IsPedInAnyVehicle(PlayerPedId(), false) then
                                    BusData.Active = false;
                                    DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                                    RemoveBlip(NpcData.NpcBlip)
                                    exports["qb-core"]:HideText()
                                    resetNpcTask()
                                    break
                                end
                            else
                                QBCore.Functions.Notify('Zet de passagiers af voordat je stopt met werken', 'error')
                            end
                        end
                    break
                end
            end
        end)
    else
        QBCore.Functions.Notify('Je zit niet in een bus', 'error')
    end
end)

-- Threads
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local type = Config.OnDuty.type
        local pos = Config.OnDuty.coords
        local color = Config.OnDuty.color
        local size = Config.OnDuty.size

        DrawMarker(
            type,
            pos.x, pos.y, pos.z,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            size.x, size.y, size.z,
            color.r, color.g, color.b,
            150,
            false, true, 2, false, nil, nil, false
        )

        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - pos)
        local text = "~p~[E]~s~ On Duty"

        if distance <= 1.0 then
            if onDuty then text = "~p~[E]~s~ Off Duty" end

            DrawText3D(vector3(pos.x, pos.y, pos.z + size.z + .05), text)

            if IsControlJustReleased(0, 38) then
                if onDuty then
                    onDuty = false
                    QBCore.Functions.Notify("Je bent uitgeklokt!", 'success')
                else
                    onDuty = true
                    QBCore.Functions.Notify("Je bent ingeklokt!", 'success')
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local type = Config.Bus.type
        local pos = Config.Bus.coords
        local color = Config.Bus.color
        local size = Config.Bus.size

        if onDuty then
            DrawMarker(
                type,
                pos.x, pos.y, pos.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                size.x, size.y, size.z,
                color.r, color.g, color.b,
                150,
                false, true, 2, false, nil, nil, false
            )

            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - pos)
            local inVeh = whitelistedVehicle()

            if distance <= 1.0 then
                if inVeh then
                    DrawText3D(vector3(playerCoords.x, playerCoords.y, playerCoords.z + 2.5), "~p~[E]~s~ Stal bus")

                    if IsControlJustReleased(0, 38) then
                        BusData.Active = false;
                        DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                        RemoveBlip(NpcData.NpcBlip)
                        exports["qb-core"]:HideText()
                        resetNpcTask()
                        break
                    end
                else
                    DrawText3D(vector3(pos.x, pos.y, pos.z + size.z + .05), "~p~[E]~s~ Neem bus")

                    if IsControlJustReleased(0, 38) then
                        busGarage()
                    end
                end
            end
        end
    end
end)
