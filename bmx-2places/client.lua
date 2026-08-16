local isPassenger  = false
local currentBike  = nil
local noDriverAt   = nil   -- timestamp du moment où le BMX s'est retrouvé sans conducteur

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

-- Attend qu'une entité réseau soit streamée localement (elle peut ne pas
-- l'être encore au moment où le serveur diffuse l'événement).
local function WaitForNetEntity(netId, timeout)
    local waited = 0
    while waited <= timeout do
        if NetworkDoesNetworkIdExist(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
        end
        Citizen.Wait(100)
        waited = waited + 100
    end
    return nil
end

local function GetDriverPed(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if not driver or driver == 0 or not DoesEntityExist(driver) then return nil end
    return driver
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

local function ResetPassengerState()
    isPassenger = false
    currentBike = nil
    noDriverAt  = nil
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

    local driver = GetDriverPed(bike)
    if not driver or driver == ped then return nil end

    return bike
end

-- ─────────────────────────────────────────────────────────────
-- Spawner le BMX (appelé via l'item ox_inventory)
-- ─────────────────────────────────────────────────────────────

local function SpawnBMX()
    local ped  = PlayerPedId()
    local hash = GetHashKey(Config.BMXModel)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return end

    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Citizen.Wait(10)
        waited = waited + 10
    end
    if not HasModelLoaded(hash) then return end

    -- Spawn devant le joueur plutôt qu'à sa droite en aveugle
    local pos     = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    local heading = GetEntityHeading(ped)

    local bike = CreateVehicle(hash, pos.x, pos.y, pos.z, heading, true, false)
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

            -- Bike détruit ou disparu
            if not currentBike or not DoesEntityExist(currentBike) then
                DetachPassenger(ped)
                ResetPassengerState()
                TriggerServerEvent('bmx:requestDismount')
            else
                local driver = GetDriverPed(currentBike)

                if not driver then
                    -- Plus de conducteur : on laisse une marge avant d'éjecter
                    noDriverAt = noDriverAt or GetGameTimer()

                    if GetGameTimer() - noDriverAt >= Config.NoDriverGrace then
                        DetachPassenger(ped)
                        ResetPassengerState()
                        Notify(Config.TextEjecte)
                        TriggerServerEvent('bmx:requestDismount')
                    end
                else
                    noDriverAt = nil

                    -- Ré-attache si le jeu a détaché le ped (collision, ragdoll, restream)
                    if not IsEntityAttachedToEntity(ped, currentBike) then
                        AttachPassenger(ped, currentBike)
                    end

                    -- Touche F pour descendre (le contrôle est désactivé pour
                    -- empêcher GTA de tenter une entrée normale dans le véhicule)
                    DisableControlAction(0, Config.MountKey, true)
                    if IsDisabledControlJustPressed(0, Config.MountKey) then
                        TriggerServerEvent('bmx:requestDismount')
                    end
                end
            end

        -- Mode à pied : chercher un BMX à monter
        elseif inVeh == 0 then
            local bike = FindNearbyRiddenBMX()

            if bike then
                sleep = 0
                -- Empêche GTA d'essayer d'entrer le véhicule normalement
                DisableControlAction(0, Config.MountKey, true)

                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Config.TextMonter)
                EndTextCommandDisplayHelp(0, false, true, -1)

                -- Le contrôle étant désactivé, il faut lire sa version "disabled"
                if IsDisabledControlJustPressed(0, Config.MountKey) then
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
    Citizen.CreateThread(function()
        local bike    = WaitForNetEntity(bikeNetId, 2000)
        local passPed = WaitForNetEntity(passNetId, 2000)
        if not bike or not passPed then return end

        AttachPassenger(passPed, bike)

        if passPed == PlayerPedId() then
            isPassenger = true
            currentBike = bike
            noDriverAt  = nil
            Notify(Config.TextMonte)
        end
    end)
end)

-- Reçu par TOUS les clients quand le passager descend
RegisterNetEvent('bmx:doDismount')
AddEventHandler('bmx:doDismount', function(passNetId)
    local isSelf = false

    if NetworkDoesNetworkIdExist(passNetId) then
        local passPed = NetworkGetEntityFromNetworkId(passNetId)
        if passPed and passPed ~= 0 and DoesEntityExist(passPed) then
            isSelf = (passPed == PlayerPedId())
            DetachPassenger(passPed)
        end
    end

    -- Même si le ped n'est pas streamé, l'état local doit être nettoyé
    if isSelf or (isPassenger and passNetId == NetworkGetNetworkIdFromEntity(PlayerPedId())) then
        ResetPassengerState()
        DetachPassenger(PlayerPedId())
        Notify(Config.TextDescendu)
    end
end)

-- Place déjà occupée
RegisterNetEvent('bmx:mountFailed')
AddEventHandler('bmx:mountFailed', function()
    Notify(Config.TextOccupe)
end)

-- Notification pour le conducteur
RegisterNetEvent('bmx:passengerUpdate')
AddEventHandler('bmx:passengerUpdate', function(mounted)
    Notify(mounted and Config.TextPassMonte or Config.TextPassDesc)
end)

-- ─────────────────────────────────────────────────────────────
-- Arrêt de la ressource : ne pas laisser le joueur attaché
-- ─────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isPassenger then
        DetachPassenger(PlayerPedId())
        ResetPassengerState()
    end
end)
