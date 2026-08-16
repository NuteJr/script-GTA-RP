--[[
    carData[carNetId] = {
        [1] = { src = playerSrc, pedNetId = netId },  -- slot arrière gauche
        [2] = { src = playerSrc, pedNetId = netId },  -- slot arrière droit
    }
]]
local carData = {}

-- ─────────────────────────────────────────────────────────────
-- Monter
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('car4p:requestMount')
AddEventHandler('car4p:requestMount', function(carNetId)
    local passSrc = source

    if not carData[carNetId] then carData[carNetId] = {} end
    local slots = carData[carNetId]

    -- Chercher un slot libre (1 ou 2)
    local freeSlot = nil
    for i = 1, 2 do
        if not slots[i] then freeSlot = i break end
    end

    if not freeSlot then
        TriggerClientEvent('car4p:mountFailed', passSrc)
        return
    end

    local car = NetworkGetEntityFromNetworkId(carNetId)
    if not car or car == 0 then return end

    local driverSrc = NetworkGetEntityOwner(car)
    local passPed   = GetPlayerPed(passSrc)
    local passNetId = NetworkGetNetworkIdFromEntity(passPed)

    slots[freeSlot] = { src = passSrc, pedNetId = passNetId }

    -- Synchroniser l'attachement chez tous les clients
    TriggerClientEvent('car4p:doMount', -1, carNetId, passNetId, freeSlot)

    -- Notifier le conducteur
    if driverSrc and driverSrc ~= passSrc then
        TriggerClientEvent('car4p:passengerUpdate', driverSrc, true)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Descendre
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('car4p:requestDismount')
AddEventHandler('car4p:requestDismount', function()
    local passSrc = source

    for carNetId, slots in pairs(carData) do
        for slot, data in pairs(slots) do
            if data.src == passSrc then
                TriggerClientEvent('car4p:doDismount', -1, data.pedNetId)

                local car = NetworkGetEntityFromNetworkId(carNetId)
                if car and car ~= 0 then
                    local driverSrc = NetworkGetEntityOwner(car)
                    if driverSrc and driverSrc ~= passSrc then
                        TriggerClientEvent('car4p:passengerUpdate', driverSrc, false)
                    end
                end

                slots[slot] = nil
                if not next(slots) then carData[carNetId] = nil end
                return
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Nettoyage à la déconnexion
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source

    for carNetId, slots in pairs(carData) do
        for slot, data in pairs(slots) do
            if data.src == src then
                TriggerClientEvent('car4p:doDismount', -1, data.pedNetId)
                slots[slot] = nil
                if not next(slots) then carData[carNetId] = nil end
            end
        end
    end
end)
