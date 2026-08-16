Config = {}

-- ═════════════════════════════════════════════════════════════
--  ACCÈS
-- ═════════════════════════════════════════════════════════════

-- Permissions ACE (à déclarer dans server.cfg, voir le README).
-- 'manage' : poser / déplacer / supprimer SES propres props.
-- 'admin'  : en plus, modifier ceux des autres + /propwipe.
Config.AcePermission      = 'props.manage'
Config.AceAdminPermission = 'props.admin'

--[[
    Accès accordé directement par identifiant, sans passer par ACE.
    Utile pour donner l'accès à une personne précise sans toucher aux groupes.

        ['license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = 'admin',
        ['license:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'] = 'user',

    'user'  = équivalent Config.AcePermission
    'admin' = équivalent Config.AceAdminPermission
]]
Config.AllowedIdentifiers = {}

-- Type d'identifiant utilisé ci-dessus et pour la propriété des props.
Config.IdentifierType = 'license'   -- 'license', 'steam', 'discord', 'fivem'...

-- Un joueur non-admin peut-il déplacer / supprimer les props des autres ?
Config.OnlyOwnerCanEdit = true

-- ═════════════════════════════════════════════════════════════
--  PERSISTANCE
-- ═════════════════════════════════════════════════════════════

-- 'json'  : fichier data/props.json (aucune dépendance)
-- 'mysql' : table SQL via oxmysql (voir install.sql)
Config.Storage = 'json'

Config.JsonFile     = 'data/props.json'
Config.MySQLTable   = 'placed_props'

-- Intervalle (ms) d'écriture du fichier JSON quand il y a eu des changements.
-- Les écritures sont regroupées : 50 props posés d'affilée = 1 seule écriture.
Config.SaveInterval = 30000

-- ═════════════════════════════════════════════════════════════
--  STREAMING / PERFORMANCE
--  Ces valeurs sont le cœur de l'optimisation. Voir le README.
-- ═════════════════════════════════════════════════════════════

-- Taille d'une cellule de la grille spatiale, en mètres.
-- Le serveur n'envoie à un joueur que les props des cellules autour de lui.
Config.CellSize = 150.0

-- Rayon en cellules autour du joueur (1 = grille 3x3 = 450m de côté).
Config.CellRadius = 1

-- Distance à laquelle les objets sont réellement créés en jeu.
Config.RenderDistance = 120.0

-- Marge avant suppression (hystérésis) : évite qu'un objet clignote quand on
-- fait des allers-retours pile à la limite. 1.2 = supprimé à 120 % de la distance.
Config.DespawnFactor = 1.2

-- Distance de LOD appliquée aux objets créés (plus bas = moins coûteux).
Config.LodDistance = 300

-- Nombre max d'objets créés par passe. Empêche les micro-freezes quand on
-- arrive d'un coup dans une zone qui contient 200 props.
Config.MaxSpawnPerPass = 6

-- Intervalle (ms) entre deux passes de rendu. Ne descendez pas sous 250.
Config.RenderInterval = 500

-- Plafond d'objets créés simultanément chez un client (protection du pool
-- d'entités du jeu, qui est limité et partagé avec le reste du serveur).
Config.MaxObjects = 400

-- ═════════════════════════════════════════════════════════════
--  LIMITES ANTI-ABUS
-- ═════════════════════════════════════════════════════════════

Config.MaxProps          = 5000   -- total sur le serveur
Config.MaxPropsPerPlayer = 250    -- par joueur (0 = illimité)
Config.ActionCooldown    = 250    -- ms minimum entre deux actions d'un même joueur
Config.MaxWipeRadius     = 100.0  -- rayon max de /propwipe

-- ═════════════════════════════════════════════════════════════
--  MODÈLES AUTORISÉS
-- ═════════════════════════════════════════════════════════════

-- Vide = tous les modèles sont autorisés.
-- Rempli = SEULS ces modèles le sont. Exemple :
--   Config.ModelWhitelist = { ['prop_bench_01a'] = true, ['prop_barrier_work05'] = true }
Config.ModelWhitelist = {}

-- Toujours refusés, même si la whitelist est vide.
Config.ModelBlacklist = {}

-- ═════════════════════════════════════════════════════════════
--  MODE PLACEMENT
-- ═════════════════════════════════════════════════════════════

Config.PlacementDistance = 10.0   -- distance max du prop devant la caméra
Config.RotationStep      = 5.0    -- degrés par cran de molette
Config.RotationStepFine  = 0.5    -- degrés par cran en maintenant MAJ
Config.HeightStep        = 0.10   -- mètres par appui sur les flèches
Config.HeightStepFine    = 0.01   -- mètres en maintenant MAJ
Config.SnapToGround      = true   -- coller au sol activé par défaut

Config.Keys = {
    Confirm     = 18,   -- Entrée
    Cancel      = 177,  -- Retour arrière
    CycleAxis   = 47,   -- G  — change l'axe de rotation (Z → X → Y)
    ToggleSnap  = 73,   -- X  — colle au sol / libre
    ResetRot    = 74,   -- H  — remet la rotation à zéro
    HeightUp    = 172,  -- Flèche haut
    HeightDown  = 173,  -- Flèche bas
    Fine        = 21,   -- MAJ (maintenu) — pas fin
}

-- ═════════════════════════════════════════════════════════════
--  DIVERS
-- ═════════════════════════════════════════════════════════════

Config.Frozen     = true    -- props figés (recommandé : pas de physique = pas de coût)
Config.Collisions = true    -- props solides
Config.Debug      = false   -- logs console

Config.Commands = {
    spawn = 'spawnprop',
    move  = 'moveprop',
    del   = 'delprop',
    info  = 'propinfo',
    count = 'propcount',
    wipe  = 'propwipe',
}

-- ═════════════════════════════════════════════════════════════
--  Clé de cellule — partagée client/serveur, ne pas modifier.
-- ═════════════════════════════════════════════════════════════

function PropCellKey(x, y)
    return ('%d:%d'):format(math.floor(x / Config.CellSize), math.floor(y / Config.CellSize))
end
