--[[
    Streaming des props.

    Deux niveaux de filtrage, pour ne jamais manipuler plus que nécessaire :

      1. Le SERVEUR n'envoie que les props des cellules autour du joueur
         (grille de Config.CellSize mètres). Un joueur à Paleto ne reçoit
         jamais les props de Los Santos.

      2. Le CLIENT ne crée les objets que dans Config.RenderDistance, par
         paquets de Config.MaxSpawnPerPass, avec une hystérésis à la
         suppression.

    Les objets sont créés en LOCAL (CreateObjectNoOffset avec isNetwork=false) :
    aucune entité réseau, aucune synchronisation, aucun coût serveur. Chaque
    client dessine sa propre copie à partir des coordonnées reçues.
]]

Props = {
    data      = {},   -- [id]        = { id, model, hash, x, y, z, rx, ry, rz, cell }
    objects   = {},   -- [id]        = handle de l'objet créé
    byHandle  = {},   -- [handle]    = id
    cells     = {},   -- [cellKey]   = true si les données de la cellule sont chargées
    requested = {},   -- [cellKey]   = timestamp de la dernière demande au serveur
    spawnedCount = 0,
    editing   = nil,  -- id du prop en cours d'édition (ne pas le rendre)
    canUse    = false,
    isAdmin   = false,
}

local badModels = {}   -- modèles introuvables : on arrête d'essayer

local function Debug(...)
    if Config.Debug then print('[props]', ...) end
end

-- ─────────────────────────────────────────────────────────────
-- Création / suppression d'un objet
-- ─────────────────────────────────────────────────────────────

function Props.Spawn(prop)
    if Props.spawnedCount >= Config.MaxObjects then return false end

    local hash = prop.hash
    if badModels[hash] then return false end

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        badModels[hash] = true
        Debug('modèle introuvable', prop.model)
        return false
    end

    if not HasModelLoaded(hash) then
        RequestModel(hash)
        prop.tries = (prop.tries or 0) + 1
        if prop.tries > 40 then          -- ~20 s à 500 ms : le modèle ne viendra pas
            badModels[hash] = true
        end
        return false                      -- on réessaiera à la passe suivante
    end

    prop.tries = nil

    local obj = CreateObjectNoOffset(hash, prop.x, prop.y, prop.z, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetEntityRotation(obj, prop.rx, prop.ry, prop.rz, 2, true)
    FreezeEntityPosition(obj, Config.Frozen)
    SetEntityCollision(obj, Config.Collisions, Config.Collisions)
    SetEntityInvincible(obj, true)
    SetEntityLodDist(obj, Config.LodDistance)
    SetModelAsNoLongerNeeded(hash)

    Props.objects[prop.id]  = obj
    Props.byHandle[obj]     = prop.id
    Props.spawnedCount      = Props.spawnedCount + 1
    return true
end

function Props.Despawn(id)
    local obj = Props.objects[id]
    if not obj then return end

    Props.objects[id]  = nil
    Props.byHandle[obj] = nil
    Props.spawnedCount  = math.max(0, Props.spawnedCount - 1)

    if DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteEntity(obj)
    end
end

-- ─────────────────────────────────────────────────────────────
-- Ajout / retrait de données
-- ─────────────────────────────────────────────────────────────

function Props.Store(prop)
    prop.hash = joaat(prop.model)
    prop.cell = prop.cell or PropCellKey(prop.x, prop.y)
    Props.data[prop.id] = prop
end

function Props.Forget(id)
    Props.Despawn(id)
    Props.data[id] = nil
end

-- ─────────────────────────────────────────────────────────────
-- Gestion des cellules
-- ─────────────────────────────────────────────────────────────

local function NeededCells(pos)
    local size = Config.CellSize
    local cx   = math.floor(pos.x / size)
    local cy   = math.floor(pos.y / size)
    local out  = {}

    for dx = -Config.CellRadius, Config.CellRadius do
        for dy = -Config.CellRadius, Config.CellRadius do
            out[('%d:%d'):format(cx + dx, cy + dy)] = true
        end
    end

    return out
end

local function SyncCells(pos)
    local needed  = NeededCells(pos)
    local now     = GetGameTimer()
    local list    = {}   -- toutes les cellules voulues (abonnement serveur)
    local missing = {}   -- celles dont on n'a pas encore les données

    for key in pairs(needed) do
        list[#list + 1] = key
        if not Props.cells[key] then
            local last = Props.requested[key]
            if not last or now - last > 10000 then   -- anti-spam si le serveur tarde
                Props.requested[key] = now
                missing[#missing + 1] = key
            end
        end
    end

    -- Décharger ce qui est sorti du rayon
    for key in pairs(Props.cells) do
        if not needed[key] then
            for id, prop in pairs(Props.data) do
                if prop.cell == key then Props.Forget(id) end
            end
            Props.cells[key]     = nil
            Props.requested[key] = nil
        end
    end

    TriggerServerEvent('props:subscribe', list, missing)
end

-- ─────────────────────────────────────────────────────────────
-- Passe de rendu
-- ─────────────────────────────────────────────────────────────

local function Render(pos)
    local renderSq  = Config.RenderDistance * Config.RenderDistance
    local despawnSq = (Config.RenderDistance * Config.DespawnFactor) ^ 2
    local budget    = Config.MaxSpawnPerPass

    for id, prop in pairs(Props.data) do
        local dx, dy, dz = prop.x - pos.x, prop.y - pos.y, prop.z - pos.z
        local distSq = dx * dx + dy * dy + dz * dz

        if Props.objects[id] then
            if distSq > despawnSq or id == Props.editing then
                Props.Despawn(id)
            end
        elseif budget > 0 and distSq <= renderSq and id ~= Props.editing then
            if Props.Spawn(prop) then budget = budget - 1 end
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- Boucle principale
-- ─────────────────────────────────────────────────────────────

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end

    TriggerServerEvent('props:checkPermission')

    local lastCell = nil

    while true do
        Wait(Config.RenderInterval)

        local pos  = GetEntityCoords(PlayerPedId())
        local cell = PropCellKey(pos.x, pos.y)

        if cell ~= lastCell then
            lastCell = cell
            SyncCells(pos)
        end

        Render(pos)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Événements serveur
-- ─────────────────────────────────────────────────────────────

-- Données des cellules demandées : { [cellKey] = { prop, prop, ... } }
RegisterNetEvent('props:cellsData', function(payload)
    for cellKey, list in pairs(payload) do
        Props.cells[cellKey] = true
        for i = 1, #list do
            local prop = list[i]
            prop.cell = cellKey
            Props.Store(prop)
        end
    end
end)

RegisterNetEvent('props:added', function(prop)
    local cell = PropCellKey(prop.x, prop.y)
    if not Props.cells[cell] then return end   -- hors de notre zone : on ignore
    prop.cell = cell
    Props.Store(prop)
end)

RegisterNetEvent('props:moved', function(prop)
    Props.Forget(prop.id)                       -- l'objet est recréé à la bonne place
    local cell = PropCellKey(prop.x, prop.y)
    if not Props.cells[cell] then return end
    prop.cell = cell
    Props.Store(prop)
end)

RegisterNetEvent('props:removed', function(id)
    Props.Forget(id)
end)

RegisterNetEvent('props:permission', function(canUse, isAdmin)
    Props.canUse  = canUse
    Props.isAdmin = isAdmin
    if canUse and Props.RegisterSuggestions then Props.RegisterSuggestions() end
end)

function Props.Notify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

RegisterNetEvent('props:notify', function(msg)
    Props.Notify(msg)
end)

-- ─────────────────────────────────────────────────────────────
-- Recherche du prop visé (raycast) ou du plus proche
-- ─────────────────────────────────────────────────────────────

function Props.FindTarget(maxDist)
    maxDist = maxDist or 15.0

    local camPos = GetGameplayCamCoord()
    local rot    = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cosRx  = math.abs(math.cos(rx))
    local dir    = vector3(-math.sin(rz) * cosRx, math.cos(rz) * cosRx, math.sin(rx))
    local dest   = camPos + dir * maxDist

    local handle = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        dest.x, dest.y, dest.z,
        16, PlayerPedId(), 0            -- 16 = objets uniquement
    )
    local _, hit, _, _, entityHit = GetShapeTestResult(handle)

    if hit == 1 and entityHit and entityHit ~= 0 then
        local id = Props.byHandle[entityHit]
        if id then return id end
    end

    -- Repli : le prop créé le plus proche du joueur
    local pos     = GetEntityCoords(PlayerPedId())
    local bestId, bestDist = nil, maxDist

    for id in pairs(Props.objects) do
        local prop = Props.data[id]
        if prop then
            local d = #(pos - vector3(prop.x, prop.y, prop.z))
            if d < bestDist then bestId, bestDist = id, d end
        end
    end

    return bestId
end

-- ─────────────────────────────────────────────────────────────
-- Nettoyage
-- ─────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Props.objects) do
        Props.Despawn(id)
    end
end)
