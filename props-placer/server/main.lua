--[[
    Serveur : source de vérité.

    Le client ne fait que *demander*. Toute création, tout déplacement et
    toute suppression est validée ici : accès, cooldown, quotas, modèle
    autorisé, coordonnées plausibles. Un client modifié ne peut donc pas
    inonder la map de props ni déplacer ceux des autres.

    Le serveur sait aussi quelles cellules chaque joueur regarde : quand un
    prop change, seuls les joueurs concernés reçoivent le paquet. Sur un
    serveur à 200 joueurs, poser un prop n'envoie pas 200 messages mais
    seulement quelques-uns.
]]

local props       = {}   -- [id]        = prop complet (avec propriétaire)
local cells       = {}   -- [cellKey]   = { [id] = true }
local ownerCount  = {}   -- [identifier]= nombre de props posés
local playerCells = {}   -- [src]       = { [cellKey] = true }  (abonnement)
local lastAction  = {}   -- [src]       = GetGameTimer()
local total       = 0

local MAX_CELLS = (Config.CellRadius * 2 + 1) ^ 2

local function Log(...) print('[props]', ...) end

-- ═════════════════════════════════════════════════════════════
--  Identité & permissions
-- ═════════════════════════════════════════════════════════════

local function GetIdentifier(src)
    local prefix = Config.IdentifierType .. ':'

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local ident = GetPlayerIdentifier(src, i)
        if ident and ident:sub(1, #prefix) == prefix then return ident end
    end

    return nil
end

-- Renvoie 'admin', 'user' ou nil
local function GetAccess(src)
    if IsPlayerAceAllowed(src, Config.AceAdminPermission) then return 'admin' end

    local granted = Config.AllowedIdentifiers[GetIdentifier(src) or '']
    if granted == 'admin' then return 'admin' end

    if IsPlayerAceAllowed(src, Config.AcePermission) then return 'user' end
    if granted == 'user' or granted == true then return 'user' end

    return nil
end

local function Notify(src, msg)
    TriggerClientEvent('props:notify', src, msg)
end

local function OnCooldown(src)
    local now  = GetGameTimer()
    local last = lastAction[src]

    if last and now - last < Config.ActionCooldown then return true end

    lastAction[src] = now
    return false
end

-- ═════════════════════════════════════════════════════════════
--  Validation
-- ═════════════════════════════════════════════════════════════

local function Coord(v, limit)
    if type(v) ~= 'number' or v ~= v then return nil end   -- v ~= v : NaN
    if v > limit or v < -limit then return nil end          -- attrape aussi ±inf
    return v + 0.0
end

local function ValidTransform(t)
    if type(t) ~= 'table' then return nil end

    local x, y, z = Coord(t.x, 20000.0), Coord(t.y, 20000.0), Coord(t.z, 2000.0)
    if not x or not y or not z then return nil end

    local rx = Coord(t.rx, 3600.0) or 0.0
    local ry = Coord(t.ry, 3600.0) or 0.0
    local rz = Coord(t.rz, 3600.0) or 0.0

    return { x = x, y = y, z = z, rx = rx % 360.0, ry = ry % 360.0, rz = rz % 360.0 }
end

local function ValidModel(name)
    if type(name) ~= 'string' then return nil end

    name = name:lower():gsub('%s', '')
    if #name < 2 or #name > 64 then return nil end
    if not name:match('^[%w_%-%.]+$') then return nil end
    if Config.ModelBlacklist[name] then return nil end
    if next(Config.ModelWhitelist) and not Config.ModelWhitelist[name] then return nil end

    return name
end

local function ValidCellKey(key)
    return type(key) == 'string' and key:match('^%-?%d+:%-?%d+$') ~= nil
end

-- ═════════════════════════════════════════════════════════════
--  Index & diffusion
-- ═════════════════════════════════════════════════════════════

local function GenerateId()
    while true do
        local out = {}
        for i = 1, 16 do out[i] = ('%02x'):format(math.random(0, 255)) end

        local id = table.concat(out)
        if not props[id] then return id end
    end
end

local function Index(prop)
    prop.cell = PropCellKey(prop.x, prop.y)

    local bucket = cells[prop.cell]
    if not bucket then
        bucket = {}
        cells[prop.cell] = bucket
    end
    bucket[prop.id] = true

    props[prop.id] = prop
    total = total + 1

    if prop.owner then
        ownerCount[prop.owner] = (ownerCount[prop.owner] or 0) + 1
    end
end

local function Unindex(prop)
    local bucket = cells[prop.cell]
    if bucket then
        bucket[prop.id] = nil
        if not next(bucket) then cells[prop.cell] = nil end
    end

    props[prop.id] = nil
    total = math.max(0, total - 1)

    if prop.owner and ownerCount[prop.owner] then
        ownerCount[prop.owner] = math.max(0, ownerCount[prop.owner] - 1)
    end
end

-- Version envoyée aux clients : le minimum nécessaire à l'affichage.
local function Public(prop)
    return {
        id = prop.id, model = prop.model,
        x  = prop.x,  y = prop.y,  z = prop.z,
        rx = prop.rx, ry = prop.ry, rz = prop.rz,
    }
end

-- Diffuse uniquement aux joueurs abonnés à l'une des cellules données.
local function SendToCells(cellKeys, event, payload)
    for src, subscribed in pairs(playerCells) do
        for i = 1, #cellKeys do
            if subscribed[cellKeys[i]] then
                TriggerClientEvent(event, src, payload)
                break
            end
        end
    end
end

-- ═════════════════════════════════════════════════════════════
--  Chargement au démarrage
-- ═════════════════════════════════════════════════════════════

local function GetAllForStorage()
    local list = {}
    for _, prop in pairs(props) do
        list[#list + 1] = {
            id = prop.id, model = prop.model,
            x = prop.x, y = prop.y, z = prop.z,
            rx = prop.rx, ry = prop.ry, rz = prop.rz,
            owner = prop.owner, ownerName = prop.ownerName,
            createdAt = prop.createdAt,
        }
    end
    return list
end

CreateThread(function()
    math.randomseed(math.floor(os.time() + os.clock() * 100000))

    Storage.Init(GetAllForStorage)

    Storage.Load(function(list)
        local loaded, skipped = 0, 0

        for i = 1, #list do
            local raw   = list[i]
            local model = ValidModel(raw.model)
            local tf    = ValidTransform(raw)

            if model and tf and type(raw.id) == 'string' and not props[raw.id] then
                Index({
                    id        = raw.id,
                    model     = model,
                    x = tf.x, y = tf.y, z = tf.z,
                    rx = tf.rx, ry = tf.ry, rz = tf.rz,
                    owner     = raw.owner,
                    ownerName = raw.ownerName,
                    createdAt = raw.createdAt or os.time(),
                })
                loaded = loaded + 1
            else
                skipped = skipped + 1
            end
        end

        Log(('%d props chargés%s'):format(loaded,
            skipped > 0 and (', %d ignorés (données invalides)'):format(skipped) or ''))
    end)
end)

-- ═════════════════════════════════════════════════════════════
--  Abonnement aux cellules
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:subscribe', function(wanted, missing)
    local src = source

    if type(wanted) ~= 'table' or #wanted > MAX_CELLS then return end
    if type(missing) ~= 'table' or #missing > MAX_CELLS then return end

    -- Mise à jour de l'abonnement (remplace l'ancien)
    local set = {}
    for i = 1, #wanted do
        if ValidCellKey(wanted[i]) then set[wanted[i]] = true end
    end
    playerCells[src] = set

    -- Envoi des données manquantes uniquement
    local payload = {}
    for i = 1, #missing do
        local key = missing[i]

        if ValidCellKey(key) and set[key] then
            local list   = {}
            local bucket = cells[key]

            if bucket then
                for id in pairs(bucket) do
                    list[#list + 1] = Public(props[id])
                end
            end

            payload[key] = list   -- table vide = cellule vide, mais chargée
        end
    end

    if next(payload) then
        TriggerClientEvent('props:cellsData', src, payload)
    end
end)

RegisterNetEvent('props:checkPermission', function()
    local access = GetAccess(source)
    TriggerClientEvent('props:permission', source, access ~= nil, access == 'admin')
end)

-- ═════════════════════════════════════════════════════════════
--  Créer
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:create', function(model, transform)
    local src    = source
    local access = GetAccess(src)

    if not access then return end
    if OnCooldown(src) then return end

    model = ValidModel(model)
    if not model then
        return Notify(src, '~r~Modèle refusé.')
    end

    local tf = ValidTransform(transform)
    if not tf then return end

    if total >= Config.MaxProps then
        return Notify(src, '~r~Limite serveur atteinte (' .. Config.MaxProps .. ' props).')
    end

    local owner = GetIdentifier(src)
    if Config.MaxPropsPerPlayer > 0 and access ~= 'admin' and owner then
        if (ownerCount[owner] or 0) >= Config.MaxPropsPerPlayer then
            return Notify(src, '~r~Vous avez atteint votre limite de '
                .. Config.MaxPropsPerPlayer .. ' props.')
        end
    end

    local prop = {
        id        = GenerateId(),
        model     = model,
        x = tf.x, y = tf.y, z = tf.z,
        rx = tf.rx, ry = tf.ry, rz = tf.rz,
        owner     = owner,
        ownerName = GetPlayerName(src),
        createdAt = os.time(),
    }

    Index(prop)
    Storage.OnCreate(prop)

    SendToCells({ prop.cell }, 'props:added', Public(prop))
    Notify(src, '~g~Prop posé.')
end)

-- ═════════════════════════════════════════════════════════════
--  Déplacer / tourner
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:update', function(id, transform)
    local src    = source
    local access = GetAccess(src)

    if not access then return end
    if OnCooldown(src) then return end
    if type(id) ~= 'string' then return end

    local prop = props[id]
    if not prop then return end

    if Config.OnlyOwnerCanEdit and access ~= 'admin' then
        if prop.owner and prop.owner ~= GetIdentifier(src) then
            return Notify(src, '~r~Ce prop ne vous appartient pas.')
        end
    end

    local tf = ValidTransform(transform)
    if not tf then return end

    local oldCell = prop.cell

    Unindex(prop)
    prop.x,  prop.y,  prop.z  = tf.x,  tf.y,  tf.z
    prop.rx, prop.ry, prop.rz = tf.rx, tf.ry, tf.rz
    Index(prop)

    Storage.OnUpdate(prop)

    -- Les abonnés de l'ancienne ET de la nouvelle cellule doivent être informés
    if oldCell == prop.cell then
        SendToCells({ prop.cell }, 'props:moved', Public(prop))
    else
        SendToCells({ oldCell, prop.cell }, 'props:moved', Public(prop))
    end

    Notify(src, '~g~Prop déplacé.')
end)

-- ═════════════════════════════════════════════════════════════
--  Supprimer
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:delete', function(id)
    local src    = source
    local access = GetAccess(src)

    if not access then return end
    if OnCooldown(src) then return end
    if type(id) ~= 'string' then return end

    local prop = props[id]
    if not prop then return end

    if Config.OnlyOwnerCanEdit and access ~= 'admin' then
        if prop.owner and prop.owner ~= GetIdentifier(src) then
            return Notify(src, '~r~Ce prop ne vous appartient pas.')
        end
    end

    local cell = prop.cell

    Unindex(prop)
    Storage.OnDelete({ id })

    SendToCells({ cell }, 'props:removed', id)
    Notify(src, '~g~Prop supprimé.')
end)

-- ═════════════════════════════════════════════════════════════
--  Nettoyage de zone (admin)
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:wipe', function(radius)
    local src = source

    if GetAccess(src) ~= 'admin' then return end
    if OnCooldown(src) then return end

    radius = tonumber(radius) or 10.0
    if radius <= 0 then return end
    if radius > Config.MaxWipeRadius then radius = Config.MaxWipeRadius end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local origin  = GetEntityCoords(ped)
    local removed = {}

    for id, prop in pairs(props) do
        if #(origin - vector3(prop.x, prop.y, prop.z)) <= radius then
            removed[#removed + 1] = { id = id, cell = prop.cell, prop = prop }
        end
    end

    local ids = {}
    for i = 1, #removed do
        local entry = removed[i]
        ids[#ids + 1] = entry.id
        Unindex(entry.prop)
        SendToCells({ entry.cell }, 'props:removed', entry.id)
    end

    if #ids > 0 then Storage.OnDelete(ids) end

    Notify(src, ('~g~%d prop(s) supprimé(s) dans %.0f m.'):format(#ids, radius))
    Log(('%s a nettoyé %d props (rayon %.0f m)'):format(GetPlayerName(src), #ids, radius))
end)

-- ═════════════════════════════════════════════════════════════
--  Divers
-- ═════════════════════════════════════════════════════════════

RegisterNetEvent('props:count', function()
    local src = source
    if not GetAccess(src) then return end

    local mine = ownerCount[GetIdentifier(src) or ''] or 0
    Notify(src, ('~b~Serveur~s~~n~%d props au total~n~%d à vous'):format(total, mine))
end)

AddEventHandler('playerDropped', function()
    playerCells[source] = nil
    lastAction[source]  = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Storage.Flush()
end)

-- ═════════════════════════════════════════════════════════════
--  Exports (pour d'autres ressources)
-- ═════════════════════════════════════════════════════════════

-- exports['props-placer']:GetProps()  → liste complète
exports('GetProps', function()
    return GetAllForStorage()
end)

-- exports['props-placer']:AddProp('prop_bench_01a', { x=..., y=..., z=..., rz=... })
exports('AddProp', function(model, transform, owner)
    model = ValidModel(model)
    local tf = ValidTransform(transform)
    if not model or not tf or total >= Config.MaxProps then return nil end

    local prop = {
        id        = GenerateId(),
        model     = model,
        x = tf.x, y = tf.y, z = tf.z,
        rx = tf.rx, ry = tf.ry, rz = tf.rz,
        owner     = owner,
        ownerName = 'script',
        createdAt = os.time(),
    }

    Index(prop)
    Storage.OnCreate(prop)
    SendToCells({ prop.cell }, 'props:added', Public(prop))

    return prop.id
end)

-- exports['props-placer']:RemoveProp(id)
exports('RemoveProp', function(id)
    local prop = props[id]
    if not prop then return false end

    local cell = prop.cell
    Unindex(prop)
    Storage.OnDelete({ id })
    SendToCells({ cell }, 'props:removed', id)

    return true
end)
