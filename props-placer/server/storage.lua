--[[
    Couche de persistance.

    Deux backends interchangeables, choisis par Config.Storage :

      'json'  — fichier data/props.json. Aucune dépendance. Les écritures
                sont REGROUPÉES : on marque le fichier « sale » et un thread
                l'écrit au plus une fois toutes les Config.SaveInterval ms.
                Poser 100 props d'affilée = 1 écriture disque, pas 100.

      'mysql' — table SQL via oxmysql (exports, donc dépendance optionnelle :
                si vous restez en JSON, oxmysql n'est pas nécessaire).
                Les requêtes sont asynchrones, elles ne bloquent jamais le tick.

    L'interface est identique dans les deux cas, le reste du script ne sait
    pas lequel est actif.
]]

Storage = {}

local backend  = Config.Storage
local dirty    = false
local provider = nil   -- fonction renvoyant la liste complète des props

local function Log(...)
    print('[props][storage]', ...)
end

-- ═════════════════════════════════════════════════════════════
--  JSON
-- ═════════════════════════════════════════════════════════════

local Json = {}

function Json.Load(cb)
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.JsonFile)

    if not raw or raw == '' then
        Log('aucun fichier existant, démarrage à vide')
        return cb({})
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        Log('^1fichier illisible, il sera écrasé au prochain enregistrement^7')
        return cb({})
    end

    cb(decoded)
end

function Json.Flush()
    if not dirty or not provider then return end

    local list = provider()
    local ok, encoded = pcall(json.encode, list)
    if not ok then
        Log('^1échec de l\'encodage JSON^7')
        return
    end

    if SaveResourceFile(GetCurrentResourceName(), Config.JsonFile, encoded, -1) then
        dirty = false
        if Config.Debug then Log(('%d props enregistrés'):format(#list)) end
    else
        Log('^1échec de l\'écriture de ' .. Config.JsonFile .. '^7')
    end
end

-- ═════════════════════════════════════════════════════════════
--  MySQL (oxmysql)
-- ═════════════════════════════════════════════════════════════

local Sql = {}

function Sql.Load(cb)
    local query = ('SELECT id, model, x, y, z, rx, ry, rz, owner, owner_name, created_at FROM `%s`')
        :format(Config.MySQLTable)

    exports.oxmysql:query(query, {}, function(rows)
        local list = {}

        for i = 1, #(rows or {}) do
            local r = rows[i]
            list[#list + 1] = {
                id        = r.id,
                model     = r.model,
                x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0,
                rx = r.rx + 0.0, ry = r.ry + 0.0, rz = r.rz + 0.0,
                owner     = r.owner,
                ownerName = r.owner_name,
                createdAt = r.created_at,
            }
        end

        cb(list)
    end)
end

function Sql.Insert(prop)
    local query = ('INSERT INTO `%s` (id, model, x, y, z, rx, ry, rz, owner, owner_name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
        :format(Config.MySQLTable)

    exports.oxmysql:insert(query, {
        prop.id, prop.model, prop.x, prop.y, prop.z,
        prop.rx, prop.ry, prop.rz,
        prop.owner, prop.ownerName, prop.createdAt,
    })
end

function Sql.Update(prop)
    local query = ('UPDATE `%s` SET x = ?, y = ?, z = ?, rx = ?, ry = ?, rz = ? WHERE id = ?')
        :format(Config.MySQLTable)

    exports.oxmysql:update(query, {
        prop.x, prop.y, prop.z, prop.rx, prop.ry, prop.rz, prop.id,
    })
end

function Sql.Delete(ids)
    if #ids == 0 then return end

    local marks = {}
    for i = 1, #ids do marks[i] = '?' end

    local query = ('DELETE FROM `%s` WHERE id IN (%s)')
        :format(Config.MySQLTable, table.concat(marks, ','))

    exports.oxmysql:update(query, ids)
end

-- ═════════════════════════════════════════════════════════════
--  Interface publique
-- ═════════════════════════════════════════════════════════════

function Storage.Init(getAll)
    provider = getAll

    if backend == 'mysql' and GetResourceState('oxmysql') ~= 'started' then
        Log('^1oxmysql introuvable — bascule automatique sur le backend JSON^7')
        backend = 'json'
    end

    Log('backend actif : ' .. backend)

    if backend == 'json' then
        CreateThread(function()
            while true do
                Wait(Config.SaveInterval)
                Json.Flush()
            end
        end)
    end
end

function Storage.Load(cb)
    if backend == 'mysql' then
        Sql.Load(cb)
    else
        Json.Load(cb)
    end
end

function Storage.OnCreate(prop)
    if backend == 'mysql' then Sql.Insert(prop) else dirty = true end
end

function Storage.OnUpdate(prop)
    if backend == 'mysql' then Sql.Update(prop) else dirty = true end
end

function Storage.OnDelete(ids)
    if backend == 'mysql' then Sql.Delete(ids) else dirty = true end
end

-- Écriture immédiate (arrêt de la ressource, arrêt du serveur).
function Storage.Flush()
    if backend == 'json' then Json.Flush() end
end
