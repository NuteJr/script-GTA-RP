--[[
    Commandes joueur.

    Elles sont enregistrées côté client pour que le mode placement s'ouvre
    instantanément, sans aller-retour réseau. Le contrôle d'accès affiché ici
    n'est qu'un confort : la vraie vérification est faite par le serveur à
    chaque événement, un client modifié ne gagne donc rien.
]]

local function Denied()
    Props.Notify('~r~Vous n\'avez pas accès aux props.')
end

-- ─────────────────────────────────────────────────────────────
-- /spawnprop <modèle>
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.spawn, function(_, args)
    if not Props.canUse then return Denied() end

    local model = args[1]
    if not model then
        Props.Notify('~y~Usage : ~w~/' .. Config.Commands.spawn .. ' <modèle>')
        return
    end

    Placement.Start(model:lower())
end, false)

-- ─────────────────────────────────────────────────────────────
-- /moveprop — reprend le prop visé
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.move, function()
    if not Props.canUse then return Denied() end

    local id = Props.FindTarget()
    if not id then
        Props.Notify('~r~Aucun prop visé.')
        return
    end

    local prop = Props.data[id]
    if not prop then return end

    Placement.Start(prop.model, id, { x = prop.rx, y = prop.ry, z = prop.rz })
end, false)

-- ─────────────────────────────────────────────────────────────
-- /delprop — supprime le prop visé
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.del, function()
    if not Props.canUse then return Denied() end

    local id = Props.FindTarget()
    if not id then
        Props.Notify('~r~Aucun prop visé.')
        return
    end

    TriggerServerEvent('props:delete', id)
end, false)

-- ─────────────────────────────────────────────────────────────
-- /propinfo — infos sur le prop visé
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.info, function()
    if not Props.canUse then return Denied() end

    local id = Props.FindTarget()
    if not id then
        Props.Notify('~r~Aucun prop visé.')
        return
    end

    local prop = Props.data[id]
    if not prop then return end

    print(('[props] id=%s modèle=%s pos=%.2f %.2f %.2f rot=%.1f %.1f %.1f')
        :format(prop.id, prop.model, prop.x, prop.y, prop.z, prop.rx, prop.ry, prop.rz))

    Props.Notify(('~b~%s~s~~n~%.2f  %.2f  %.2f~n~~y~détails en console (F8)'):format(
        prop.model, prop.x, prop.y, prop.z))
end, false)

-- ─────────────────────────────────────────────────────────────
-- /propcount — état du streaming local
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.count, function()
    if not Props.canUse then return Denied() end

    local known, cells = 0, 0
    for _ in pairs(Props.data)  do known = known + 1 end
    for _ in pairs(Props.cells) do cells = cells + 1 end

    Props.Notify(('~b~Props~s~~n~%d connus / %d affichés~n~%d cellules chargées')
        :format(known, Props.spawnedCount, cells))

    TriggerServerEvent('props:count')
end, false)

-- ─────────────────────────────────────────────────────────────
-- /propwipe [rayon] — admin, exécuté entièrement côté serveur
-- ─────────────────────────────────────────────────────────────

RegisterCommand(Config.Commands.wipe, function(_, args)
    if not Props.isAdmin then return Denied() end
    TriggerServerEvent('props:wipe', tonumber(args[1]) or 10.0)
end, false)

-- ─────────────────────────────────────────────────────────────
-- Suggestions de chat (uniquement si le joueur a l'accès)
-- ─────────────────────────────────────────────────────────────

function Props.RegisterSuggestions()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.spawn,
        'Poser un nouveau prop', {
            { name = 'modèle', help = 'ex: prop_bench_01a' },
        })
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.move,
        'Déplacer / tourner le prop visé')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.del,
        'Supprimer le prop visé')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.info,
        'Afficher les infos du prop visé')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.count,
        'Compter les props chargés')

    if Props.isAdmin then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.wipe,
            'Supprimer tous les props autour de vous', {
                { name = 'rayon', help = 'en mètres (défaut 10)' },
            })
    end
end
