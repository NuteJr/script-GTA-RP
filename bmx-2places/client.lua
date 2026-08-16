local isPassenger  = false
local currentBike  = nil

-- ─────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────

local function Notify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

local function LoadAnim(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Citizen.Wait(100)
        t = t + 1
    end
    return HasAnimDictLoaded(dict)
end

-- ─────────────────────────────────────────────────────────────
-- Attacher / Détacher le passager
-- ─────────────────────────────────────────────────────────────

local function AttachPassenger(passPed, bike)
    local bone = GetEntityBoneIndexByName(bike, 'chassis_dummy')
    if bone == -1 then bone = 0 end

    AttachEntityToEntity(
        passPed, bike, bone,
        Config.OffsetX, Config.OffsetY, Config.OffsetZ,
        0.0, 0.0, 0.0,
        false, false, false, false, 1, true
    )

    if LoadAnim(Config.AnimDict) then
        TaskPlayAnim(passPed, Config.AnimDict, Config.AnimName,
            8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function DetachPassenger(passPed)
    DetachEntity(passPed, true, true)
    ClearPedTasks(passPed)
end

-- ─────────────────────────────────────────────────────────────
-- Chercher un BMX proche avec un conducteur
-- ─────────────────────────────────────────────────────────────

local function FindNearbyRiddenBMX()
    local ped  = PlayerPedId()
    local pos  = GetEntityCoords(ped)
    local hash = GetHashKey(Config.BMXModel)

    local bike = GetClosestVehicle(pos.x, pos.y, pos.z, Config.Distance, hash, 70)
    if not bike or bike == 0 then return nil end

    local driver = GetPedInVehicleSeat(bike, -1)
    if not driver or driver == 0 or driver == ped then return nil end

    return bike
end

-- ─────────────────────────────────────────────────────────────
-- Spawner le BMX (appelé via l'item ox_inventory)
-- ─────────────────────────────────────────────────────────────

local function SpawnBMX()
    local ped  = PlayerPedId()
    local pos  = GetEntityCoords(ped)
    local hash = GetHashKey(Config.BMXModel)

    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(10) end

    local bike = CreateVehicle(
        hash,
        pos.x + 2.5, pos.y, pos.z,
        GetEntityHeading(ped),
        true, false
    )
    SetVehicleOnGroundProperly(bike)
    SetEntityAsMissionEntity(bike, true, true)
    SetModelAsNoLongerNeeded(hash)
end

-- ─────────────────────────────────────────────────────────────
-- Thread principal
-- ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local ped   = PlayerPedId()
        local inVeh = GetVehiclePedIsIn(ped, false)

        -- Mode passager
        if isPassenger then
            sleep = 0

            -- Bike détruit ou conducteur parti
            if currentBike and not DoesEntityExist(currentBike) then
                DetachPassenger(ped)
                isPassenger = false
                currentBike = nil

            -- Touche F pour descendre
            elseif IsControlJustPressed(0, Config.MountKey) then
                TriggerServerEvent('bmx:requestDismount')
            end

        -- Mode à pied : chercher un BMX à monter
        elseif inVeh == 0 then
            local bike = FindNearbyRiddenBMX()

            if bike then
                sleep = 0

                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Config.TextMonter)
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustPressed(0, Config.MountKey) then
                    local netId = NetworkGetNetworkIdFromEntity(bike)
                    TriggerServerEvent('bmx:requestMount', netId)
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Événements réseau
-- ─────────────────────────────────────────────────────────────

-- Déclenché par le serveur quand l'item est utilisé
RegisterNetEvent('bmx:spawnFromItem')
AddEventHandler('bmx:spawnFromItem', function()
    SpawnBMX()
end)

-- Reçu par TOUS les clients quand un passager monte
RegisterNetEvent('bmx:doMount')
AddEventHandler('bmx:doMount', function(bikeNetId, passNetId)
    local bike    = NetworkGetEntityFromNetworkId(bikeNetId)
    local passPed = NetworkGetEntityFromNetworkId(passNetId)

    if not DoesEntityExist(bike) or not DoesEntityExist(passPed) then return end

    if passPed == PlayerPedId() then
        AttachPassenger(passPed, bike)
        isPassenger = true
        currentBike = bike
        Notify(Config.TextMonte)
    else
        AttachPassenger(passPed, bike)
    end
end)

-- Reçu par TOUS les clients quand le passager descend
RegisterNetEvent('bmx:doDismount')
AddEventHandler('bmx:doDismount', function(passNetId)
    local passPed = NetworkGetEntityFromNetworkId(passNetId)
    if not DoesEntityExist(passPed) then return end

    DetachPassenger(passPed)

    if passPed == PlayerPedId() then
        isPassenger = false
        currentBike = nil
        Notify(Config.TextDescendu)
    end
end)

-- Notification pour le conducteur
RegisterNetEvent('bmx:passengerUpdate')
AddEventHandler('bmx:passengerUpdate', function(mounted)
    Notify(mounted and Config.TextPassMonte or Config.TextPassDesc)
end)
