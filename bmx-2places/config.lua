Config = {}

Config.BMXModel  = 'bmx'    -- Modèle du véhicule
Config.MountKey  = 23       -- Touche F (INPUT_ENTER)
Config.Distance  = 2.5      -- Distance max (en mètres) pour monter
Config.ItemName  = 'bmx'    -- Nom de l'item dans ox_inventory

-- Marge ajoutée à Config.Distance pour la vérification serveur (latence / désync).
Config.DistanceTolerance = 2.0

-- Délai (ms) sans conducteur avant d'éjecter automatiquement le passager.
-- Évite les faux positifs pendant les micro-coupures réseau.
Config.NoDriverGrace = 1500

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
Config.TextOccupe    = '~r~Il y a déjà quelqu\'un derrière !'
Config.TextPassMonte = '~g~Un passager est monté derrière vous !'
Config.TextPassDesc  = '~r~Le passager est descendu.'
Config.TextEjecte    = '~r~Le conducteur a quitté le BMX.'
