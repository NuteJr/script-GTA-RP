Config = {}

Config.BMXModel  = 'bmx'    -- Modèle du véhicule
Config.MountKey  = 23       -- Touche F (INPUT_ENTER)
Config.Distance  = 2.5      -- Distance max (en mètres) pour monter
Config.ItemName  = 'bmx'    -- Nom de l'item dans ox_inventory

-- Position du passager sur le BMX (ajustez à votre goût)
Config.OffsetX   =  0.0
Config.OffsetY   = -0.42
Config.OffsetZ   =  0.58

-- Animation du passager (laissez vide '' pour désactiver)
Config.AnimDict  = 'amb@world_human_seat_ground@male@base'
Config.AnimName  = 'base'

-- Messages affichés
Config.TextMonter    = 'Appuyez sur ~INPUT_ENTER~ pour monter derrière'
Config.TextMonte     = '~g~Vous êtes monté derrière !'
Config.TextDescendu  = '~r~Vous êtes descendu du BMX.'
Config.TextPassMonte = '~g~Un passager est monté derrière vous !'
Config.TextPassDesc  = '~r~Le passager est descendu.'
