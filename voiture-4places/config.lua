Config = {}

Config.MountKey  = 23     -- Touche F (INPUT_ENTER)
Config.Distance  = 3.0    -- Distance max pour monter (mètres)

--[[
    Positions des 2 sièges arrière ajoutés, relatives au centre du véhicule.
    x  = gauche(-) / droite(+)
    y  = avant(+)  / arrière(-)
    z  = bas(-)    / haut(+)

    Ces valeurs fonctionnent pour la plupart des voitures de sport.
    Ajustez si besoin selon le modèle.
]]
Config.BackSeats = {
    [1] = { x = -0.35, y = -0.65, z = 0.35, rx = 0.0, ry = 0.0, rz = 0.0 },  -- Arrière gauche
    [2] = { x =  0.35, y = -0.65, z = 0.35, rx = 0.0, ry = 0.0, rz = 0.0 },  -- Arrière droit
}

-- Animation des passagers arrière (laissez vide '' pour désactiver)
Config.AnimDict  = 'amb@world_human_seat_ground@male@base'
Config.AnimName  = 'base'

-- Messages
Config.TextMonter    = 'Appuyez sur ~INPUT_ENTER~ pour monter à l\'arrière'
Config.TextMonte     = '~g~Vous êtes monté à l\'arrière !'
Config.TextDescendu  = '~r~Vous êtes descendu du véhicule.'
Config.TextComplet   = '~r~Les sièges arrière sont déjà complets !'
Config.TextPassMonte = '~g~Un passager est monté à l\'arrière !'
Config.TextPassDesc  = '~r~Un passager est descendu.'
