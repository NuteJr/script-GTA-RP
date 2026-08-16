--[[
    Pont entre le jeu et l'interface NUI.

    Le catalogue est construit UNE FOIS, à la première ouverture, puis mis en
    cache : les milliers d'appels à IsModelInCdimage ne sont pas refaits à
    chaque ouverture du menu.

    Favoris et récents sont stockés en local chez le joueur (KVP), ils ne
    coûtent donc rien au serveur.
]]

local KVP_FAV    = 'props_placer_favorites'
local KVP_RECENT = 'props_placer_recents'

local menuOpen = false
local catalog  = nil   -- payload construit et mis en cache

-- ─────────────────────────────────────────────────────────────
-- Stockage local (favoris / récents)
-- ─────────────────────────────────────────────────────────────

local function LoadList(key)
    local raw = GetResourceKvpString(key)
    if not raw or raw == '' then return {} end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return {} end

    return decoded
end

local function SaveList(key, list)
    SetResourceKvp(key, json.encode(list))
end

local function AddRecent(model)
    local list = LoadList(KVP_RECENT)
    local out  = { model }

    for i = 1, #list do
        if list[i] ~= model and #out < Config.UI.MaxRecents then
            out[#out + 1] = list[i]
        end
    end

    SaveList(KVP_RECENT, out)
end

local function ToggleFavorite(model, wanted)
    local list = LoadList(KVP_FAV)
    local out  = {}

    for i = 1, #list do
        if list[i] ~= model then out[#out + 1] = list[i] end
    end

    if wanted then out[#out + 1] = model end

    SaveList(KVP_FAV, out)
end

-- ─────────────────────────────────────────────────────────────
-- Construction du catalogue
-- ─────────────────────────────────────────────────────────────

local function BuildCatalog()
    local families = {}
    local kept, dropped = 0, 0
    local seen = {}

    for _, fam in ipairs(PropCatalog or {}) do
        local props = {}

        for _, entry in ipairs(fam.props or {}) do
            local model = type(entry) == 'table' and entry.model or entry
            local label = type(entry) == 'table' and entry.label or nil

            if type(model) == 'string' and not seen[model] then
                seen[model] = true

                local valid = true
                if Config.UI.HideInvalidModels then
                    local hash = joaat(model)
                    valid = IsModelInCdimage(hash) and IsModelValid(hash)
                end

                if valid then
                    props[#props + 1] = { model = model, label = label }
                    kept = kept + 1
                else
                    dropped = dropped + 1
                end
            end
        end

        if #props > 0 then
            families[#families + 1] = {
                id    = fam.id,
                label = fam.label,
                icon  = fam.icon,
                props = props,
            }
        end
    end

    if Config.Debug then
        print(('[props] catalogue : %d modèles disponibles, %d absents du jeu')
            :format(kept, dropped))
    end

    return families
end

-- ─────────────────────────────────────────────────────────────
-- Ouverture / fermeture
-- ─────────────────────────────────────────────────────────────

local function CloseMenu()
    if not menuOpen then return end

    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function OpenMenu()
    if menuOpen or Placement.active then return end

    if not Props.canUse then
        Props.Notify('~r~Vous n\'avez pas accès aux props.')
        return
    end

    if not catalog then catalog = BuildCatalog() end

    if #catalog == 0 then
        Props.Notify('~r~Catalogue vide : aucun modèle valide (voir catalog.lua).')
        return
    end

    menuOpen = true

    SendNUIMessage({
        action    = 'open',
        families  = catalog,
        favorites = LoadList(KVP_FAV),
        recents   = LoadList(KVP_RECENT),
        config    = {
            localImages  = Config.UI.LocalImages,
            remoteImages = Config.UI.RemoteImageURL,
            pageSize     = Config.UI.PageSize,
        },
    })

    SetNuiFocus(true, true)
end

-- ─────────────────────────────────────────────────────────────
-- Retours de l'interface
-- ─────────────────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({})
end)

RegisterNUICallback('select', function(data, cb)
    CloseMenu()
    cb({})

    local model = type(data) == 'table' and data.model or nil
    if type(model) ~= 'string' or model == '' then return end

    model = model:lower()
    AddRecent(model)

    -- Laisse un frame au NUI pour rendre le focus avant d'ouvrir le placement
    SetTimeout(50, function()
        Placement.Start(model)
    end)
end)

RegisterNUICallback('favorite', function(data, cb)
    if type(data) == 'table' and type(data.model) == 'string' then
        ToggleFavorite(data.model:lower(), data.state == true)
    end
    cb({})
end)

-- ─────────────────────────────────────────────────────────────
-- Ouverture : commande + touche assignable
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.UI.Command, function()
    OpenMenu()
end, false)

-- Le joueur choisit sa touche dans Paramètres → Commandes → FiveM.
-- Aucune touche par défaut : on n'écrase pas un bind existant.
RegisterKeyMapping(Config.UI.Command, 'Ouvrir le catalogue de props', 'keyboard',
    Config.UI.DefaultKey or '')

-- Sécurité : ne jamais laisser le joueur avec le focus souris bloqué
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
end)

Props.OpenMenu = OpenMenu
