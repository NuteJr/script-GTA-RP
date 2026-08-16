-- [bikeNetId] = { passenger = src, passNetId = netId }
local bikeData = {}

-- ─────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────

-- Retourne l'entité si le netId correspond bien à un BMX existant.
local function GetBikeFromNetId(bikeNetId)
    if type(bikeNetId) ~= 'number' then return nil end

    local bike = NetworkGetEntityFromNetworkId(bikeNetId)
    if not bike or bike == 0 or not DoesEntityExist(bike) then return nil end
    if GetEntityType(bike) ~= 2 then return nil end                    -- 2 = véhicule
    if GetEntityModel(bike) ~= GetHashKey(Config.BMXModel) then return nil end

    return bike
end

-- Le conducteur réel du véhicule (et non son simple propriétaire réseau,
-- qui peut être n'importe quel joueur à proximité).
local function GetDriverSrc(bike)
    local ok, driverPed = pcall(GetPedInVehicleSeat, bike, -1)
    if not ok then driverPed = nil end
    if driverPed == 0 then driverPed = nil end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)

        if ped and ped ~= 0 then
            if driverPed then
                if ped == driverPed then return src end
            -- Repli si GetPedInVehicleSeat n'est pas disponible côté serveur :
            -- le passager est attaché (pas "dans" le véhicule), donc le seul
            -- occupant réel est le conducteur.
            elseif GetVehiclePedIsIn(ped) == bike then
                return src
            end
        end
    end

    return nil
end

local function IsPlayerNearBike(src, bike)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local pedPos  = GetEntityCoords(ped)
    local bikePos = GetEntityCoords(bike)

    return #(pedPos - bikePos) <= (Config.Distance + Config.DistanceTolerance)
end

local function FindPlayerBike(src)
    for bikeNetId, data in pairs(bikeData) do
        if data.passenger == src then return bikeNetId end
    end
    return nil
end

-- Libère la place et prévient tout le monde.
local function ReleaseSeat(bikeNetId, notifyDriver)
    local data = bikeData[bikeNetId]
    if not data then return end

    TriggerClientEvent('bmx:doDismount', -1, data.passNetId)

    if notifyDriver then
        local bike = GetBikeFromNetId(bikeNetId)
        if bike then
            local driverSrc = GetDriverSrc(bike)
            if driverSrc and driverSrc ~= data.passenger then
                TriggerClientEvent('bmx:passengerUpdate', driverSrc, false)
            end
        end
    end

    bikeData[bikeNetId] = nil
end

-- ─────────────────────────────────────────────────────────────
-- Item ox_inventory : utiliser le BMX depuis l'inventaire
-- ─────────────────────────────────────────────────────────────

exports.ox_inventory:registerHook('useItem', function(payload)
    if payload.item.name ~= Config.ItemName then return end

    -- Vérifier que le joueur a bien l'item avant de le consommer
    local count = exports.ox_inventory:GetItem(payload.source, Config.ItemName, nil, true)
    if not count or count < 1 then return false end

    exports.ox_inventory:RemoveItem(payload.source, Config.ItemName, 1)
    TriggerClientEvent('bmx:spawnFromItem', payload.source)

    return false  -- empêche le comportement par défaut d'ox_inventory
end, {
    itemFilter = { [Config.ItemName] = true }
})

-- ─────────────────────────────────────────────────────────────
-- Monter
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('bmx:requestMount')
AddEventHandler('bmx:requestMount', function(bikeNetId)
    local passSrc = source

    local bike = GetBikeFromNetId(bikeNetId)
    if not bike then return end

    -- Le joueur doit être réellement à proximité du BMX
    if not IsPlayerNearBike(passSrc, bike) then return end

    -- Le BMX doit être conduit, et pas par le demandeur lui-même
    local driverSrc = GetDriverSrc(bike)
    if not driverSrc or driverSrc == passSrc then return end

    -- Place déjà prise (par quelqu'un d'autre encore connecté)
    local occupant = bikeData[bikeNetId]
    if occupant then
        if occupant.passenger == passSrc then return end
        if GetPlayerName(occupant.passenger) then
            TriggerClientEvent('bmx:mountFailed', passSrc)
            return
        end
        ReleaseSeat(bikeNetId, false)   -- occupant fantôme, on nettoie
    end

    -- Un joueur ne peut occuper qu'une seule place : on libère l'ancienne
    local oldBikeNetId = FindPlayerBike(passSrc)
    if oldBikeNetId then ReleaseSeat(oldBikeNetId, true) end

    local passPed   = GetPlayerPed(passSrc)
    local passNetId = NetworkGetNetworkIdFromEntity(passPed)

    bikeData[bikeNetId] = {
        passenger = passSrc,
        passNetId = passNetId,
    }

    TriggerClientEvent('bmx:doMount', -1, bikeNetId, passNetId)
    TriggerClientEvent('bmx:passengerUpdate', driverSrc, true)
end)

-- ─────────────────────────────────────────────────────────────
-- Descendre
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('bmx:requestDismount')
AddEventHandler('bmx:requestDismount', function()
    local passSrc = source

    local bikeNetId = FindPlayerBike(passSrc)
    if not bikeNetId then return end

    ReleaseSeat(bikeNetId, true)
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage à la déconnexion
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source

    local bikeNetId = FindPlayerBike(src)
    while bikeNetId do
        ReleaseSeat(bikeNetId, true)
        bikeNetId = FindPlayerBike(src)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage périodique : BMX détruits / despawn, joueurs partis.
-- Sans cela les netIds recyclés hériteraient d'une place fantôme.
-- ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)

        for bikeNetId, data in pairs(bikeData) do
            if not GetBikeFromNetId(bikeNetId) or not GetPlayerName(data.passenger) then
                ReleaseSeat(bikeNetId, false)
            end
        end
    end
end)
