local isPassenger  = false
local currentCar   = nil
local currentSlot  = nil

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

local function AttachPassenger(passPed, car, slot)
    local s    = Config.BackSeats[slot]
    local bone = GetEntityBoneIndexByName(car, 'chassis_dummy')
    if bone == -1 then bone = 0 end

    AttachEntityToEntity(
        passPed, car, bone,
        s.x, s.y, s.z,
        s.rx, s.ry, s.rz,
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
-- Détection : voiture 2 places conduite par quelqu'un
-- ─────────────────────────────────────────────────────────────

local function Is2SeatCar(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    -- Exclut motos (8), vélos (13), bateaux (14), hélicos (15), avions (16+)
    if GetVehicleClass(vehicle) > 7 then return false end
    -- 1 siège passager max = voiture 2 places (driver + 1)
    return GetVehicleMaxNumberOfPassengers(vehicle) <= 1
end

local function FindNearby2SeatCar()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    local car = GetClosestVehicle(pos.x, pos.y, pos.z, Config.Distance, 0, 70)
    if not car or car == 0 then return nil end
    if not Is2SeatCar(car) then return nil end

    local driver = GetPedInVehicleSeat(car, -1)
    if not driver or driver == 0 or driver == ped then return nil end

    return car
end

-- ─────────────────────────────────────────────────────────────
-- Thread principal
-- ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local ped   = PlayerPedId()
        local inVeh = GetVehiclePedIsIn(ped, false)

        -- Mode passager arrière
        if isPassenger then
            sleep = 0

            -- Voiture détruite ou disparue
            if currentCar and not DoesEntityExist(currentCar) then
                DetachPassenger(ped)
                isPassenger = false
                currentCar  = nil
                currentSlot = nil

            -- Touche F pour descendre
            elseif IsControlJustPressed(0, Config.MountKey) then
                TriggerServerEvent('car4p:requestDismount')
            end

        -- Mode à pied
        elseif inVeh == 0 then
            local car = FindNearby2SeatCar()

            if car then
                sleep = 0
                -- Empêche GTA d'essayer d'entrer le véhicule normalement
                DisableControlAction(0, Config.MountKey, true)

                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Config.TextMonter)
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustPressed(0, Config.MountKey) then
                    local netId = NetworkGetNetworkIdFromEntity(car)
                    TriggerServerEvent('car4p:requestMount', netId)
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Événements réseau
-- ─────────────────────────────────────────────────────────────

-- Reçu par TOUS quand un passager monte (slot = 1 ou 2)
RegisterNetEvent('car4p:doMount')
AddEventHandler('car4p:doMount', function(carNetId, passNetId, slot)
    local car     = NetworkGetEntityFromNetworkId(carNetId)
    local passPed = NetworkGetEntityFromNetworkId(passNetId)

    if not DoesEntityExist(car) or not DoesEntityExist(passPed) then return end

    AttachPassenger(passPed, car, slot)

    if passPed == PlayerPedId() then
        isPassenger = true
        currentCar  = car
        currentSlot = slot
        Notify(Config.TextMonte)
    end
end)

-- Reçu par TOUS quand un passager descend
RegisterNetEvent('car4p:doDismount')
AddEventHandler('car4p:doDismount', function(passNetId)
    local passPed = NetworkGetEntityFromNetworkId(passNetId)
    if not DoesEntityExist(passPed) then return end

    DetachPassenger(passPed)

    if passPed == PlayerPedId() then
        isPassenger = false
        currentCar  = nil
        currentSlot = nil
        Notify(Config.TextDescendu)
    end
end)

-- Sièges complets
RegisterNetEvent('car4p:mountFailed')
AddEventHandler('car4p:mountFailed', function()
    Notify(Config.TextComplet)
end)

-- Notification conducteur
RegisterNetEvent('car4p:passengerUpdate')
AddEventHandler('car4p:passengerUpdate', function(mounted)
    Notify(mounted and Config.TextPassMonte or Config.TextPassDesc)
end)
