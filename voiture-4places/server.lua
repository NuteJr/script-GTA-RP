--[[
    carData[carNetId] = {
        [1] = { src = playerSrc, pedNetId = netId },  -- slot arrière gauche
        [2] = { src = playerSrc, pedNetId = netId },  -- slot arrière droit
    }
]]
local carData = {}

-- ─────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────

-- Retourne l'entité véhicule si le netId est valide, sinon nil.
local function GetVehicleFromNetId(carNetId)
    if type(carNetId) ~= 'number' then return nil end

    local car = NetworkGetEntityFromNetworkId(carNetId)
    if not car or car == 0 or not DoesEntityExist(car) then return nil end
    if GetEntityType(car) ~= 2 then return nil end   -- 2 = véhicule

    return car
end

-- Le conducteur réel du véhicule (et non son simple propriétaire réseau,
-- qui peut être n'importe quel joueur à proximité).
local function GetDriverSrc(car)
    local ok, driverPed = pcall(GetPedInVehicleSeat, car, -1)
    if not ok then driverPed = nil end
    if driverPed == 0 then driverPed = nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)

        if ped and ped ~= 0 then
            if driverPed then
                if ped == driverPed then return src end
            -- Repli si GetPedInVehicleSeat n'est pas disponible côté serveur :
            -- les passagers arrière sont attachés (pas "dans" le véhicule),
            -- donc le seul occupant réel est le conducteur.
            elseif GetVehiclePedIsIn(ped) == car then
                return src
            end
        end
    end

    return nil
end

local function IsPlayerNearVehicle(src, car)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local pedPos = GetEntityCoords(ped)
    local carPos = GetEntityCoords(car)

    return #(pedPos - carPos) <= (Config.Distance + Config.DistanceTolerance)
end

-- Retrouve le siège occupé par un joueur : carNetId, slot
local function FindPlayerSeat(src)
    for carNetId, slots in pairs(carData) do
        for slot, data in pairs(slots) do
            if data.src == src then return carNetId, slot end
        end
    end
    return nil, nil
end

-- Libère un siège et prévient tout le monde.
local function ReleaseSeat(carNetId, slot, notifyDriver)
    local slots = carData[carNetId]
    if not slots then return end

    local data = slots[slot]
    if not data then return end

    TriggerClientEvent('car4p:doDismount', -1, data.pedNetId)

    if notifyDriver then
        local car = GetVehicleFromNetId(carNetId)
        if car then
            local driverSrc = GetDriverSrc(car)
            if driverSrc and driverSrc ~= data.src then
                TriggerClientEvent('car4p:passengerUpdate', driverSrc, false)
            end
        end
    end

    slots[slot] = nil
    if not next(slots) then carData[carNetId] = nil end
end

-- ─────────────────────────────────────────────────────────────
-- Monter
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('car4p:requestMount')
AddEventHandler('car4p:requestMount', function(carNetId)
    local passSrc = source

    local car = GetVehicleFromNetId(carNetId)
    if not car then return end

    -- Le joueur doit être réellement à proximité du véhicule
    if not IsPlayerNearVehicle(passSrc, car) then return end

    -- Le véhicule doit être conduit, et pas par le demandeur lui-même
    local driverSrc = GetDriverSrc(car)
    if not driverSrc or driverSrc == passSrc then return end

    -- Un joueur ne peut occuper qu'un seul siège : on libère l'ancien
    local oldCarNetId, oldSlot = FindPlayerSeat(passSrc)
    if oldCarNetId then ReleaseSeat(oldCarNetId, oldSlot, true) end

    if not carData[carNetId] then carData[carNetId] = {} end
    local slots = carData[carNetId]

    -- Chercher un slot libre (1 ou 2)
    local freeSlot = nil
    for i = 1, 2 do
        if not slots[i] then freeSlot = i break end
    end

    if not freeSlot then
        if not next(slots) then carData[carNetId] = nil end
        TriggerClientEvent('car4p:mountFailed', passSrc)
        return
    end

    local passPed   = GetPlayerPed(passSrc)
    local passNetId = NetworkGetNetworkIdFromEntity(passPed)

    slots[freeSlot] = { src = passSrc, pedNetId = passNetId }

    -- Synchroniser l'attachement chez tous les clients
    TriggerClientEvent('car4p:doMount', -1, carNetId, passNetId, freeSlot)

    -- Notifier le conducteur
    TriggerClientEvent('car4p:passengerUpdate', driverSrc, true)
end)

-- ─────────────────────────────────────────────────────────────
-- Descendre
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('car4p:requestDismount')
AddEventHandler('car4p:requestDismount', function()
    local passSrc = source

    local carNetId, slot = FindPlayerSeat(passSrc)
    if not carNetId then return end

    ReleaseSeat(carNetId, slot, true)
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage à la déconnexion
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source

    local carNetId, slot = FindPlayerSeat(src)
    while carNetId do
        ReleaseSeat(carNetId, slot, true)
        carNetId, slot = FindPlayerSeat(src)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage périodique : véhicules détruits / despawn, joueurs partis.
-- Sans cela les netIds recyclés hériteraient de sièges fantômes.
-- ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)

        for carNetId, slots in pairs(carData) do
            local car = GetVehicleFromNetId(carNetId)

            if not car then
                for slot in pairs(slots) do
                    ReleaseSeat(carNetId, slot, false)
                end
            else
                for slot, data in pairs(slots) do
                    if not GetPlayerName(data.src) then
                        ReleaseSeat(carNetId, slot, false)
                    end
                end
            end
        end
    end
end)
