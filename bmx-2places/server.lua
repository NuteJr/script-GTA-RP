-- [bikeNetId] = { driver = src, passenger = src, passNetId = netId }
local bikeData = {}

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
end)

-- ─────────────────────────────────────────────────────────────
-- Monter
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('bmx:requestMount')
AddEventHandler('bmx:requestMount', function(bikeNetId)
    local passSrc = source

    -- Déjà un passager sur ce BMX
    if bikeData[bikeNetId] then return end

    local bike = NetworkGetEntityFromNetworkId(bikeNetId)
    if not bike or bike == 0 then return end

    local driverSrc  = NetworkGetEntityOwner(bike)
    local passPed    = GetPlayerPed(passSrc)
    local passNetId  = NetworkGetNetworkIdFromEntity(passPed)

    bikeData[bikeNetId] = {
        driver    = driverSrc,
        passenger = passSrc,
        passNetId = passNetId,
    }

    TriggerClientEvent('bmx:doMount', -1, bikeNetId, passNetId)

    if driverSrc and driverSrc ~= passSrc then
        TriggerClientEvent('bmx:passengerUpdate', driverSrc, true)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Descendre
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('bmx:requestDismount')
AddEventHandler('bmx:requestDismount', function()
    local passSrc = source

    for bikeNetId, data in pairs(bikeData) do
        if data.passenger == passSrc then
            TriggerClientEvent('bmx:doDismount', -1, data.passNetId)

            if data.driver and data.driver ~= passSrc then
                TriggerClientEvent('bmx:passengerUpdate', data.driver, false)
            end

            bikeData[bikeNetId] = nil
            return
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage à la déconnexion
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source

    for bikeNetId, data in pairs(bikeData) do
        if data.passenger == src then
            TriggerClientEvent('bmx:doDismount', -1, data.passNetId)
            if data.driver then
                TriggerClientEvent('bmx:passengerUpdate', data.driver, false)
            end
            bikeData[bikeNetId] = nil

        elseif data.driver == src then
            TriggerClientEvent('bmx:doDismount', -1, data.passNetId)
            bikeData[bikeNetId] = nil
        end
    end
end)
