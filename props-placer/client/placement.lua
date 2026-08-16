--[[
    Mode placement : un objet fantôme suit la visée, on le tourne, on ajuste
    sa hauteur, puis on valide. Rien n'est envoyé au serveur avant la
    validation — bouger le fantôme ne coûte pas un seul paquet réseau.
]]

Placement = { active = false }

local preview    = nil     -- objet fantôme
local previewMin = nil     -- bas du modèle (pour coller au sol proprement)
local editingId  = nil     -- id du prop déplacé (nil = nouveau prop)
local modelName  = nil
local rot        = { x = 0.0, y = 0.0, z = 0.0 }
local axis       = 'z'
local heightOff  = 0.0
local snap       = true

local AXIS_LABEL = { z = 'Z (lacet)', x = 'X (tangage)', y = 'Y (roulis)' }
local AXIS_NEXT  = { z = 'x', x = 'y', y = 'z' }

-- ─────────────────────────────────────────────────────────────
-- Affichage
-- ─────────────────────────────────────────────────────────────

local function DrawLine(text, y)
    SetTextFont(4)
    SetTextScale(0.0, 0.34)
    SetTextColour(255, 255, 255, 220)
    SetTextDropShadow()
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.015, y)
end

local function DrawHud()
    DrawRect(0.115, 0.50, 0.215, 0.30, 0, 0, 0, 150)

    local lines = {
        (editingId and '~y~DÉPLACEMENT~s~  ' or '~y~PLACEMENT~s~  ') .. modelName,
        '',
        '~b~Molette~s~        rotation ' .. AXIS_LABEL[axis],
        '~b~G~s~              changer d\'axe',
        '~b~Flèches ↑↓~s~     hauteur (' .. ('%.2f'):format(heightOff) .. ' m)',
        '~b~MAJ (maintenu)~s~ pas fin',
        '~b~X~s~              coller au sol : ' .. (snap and '~g~oui' or '~r~non'),
        '~b~H~s~              réinitialiser la rotation',
        '',
        '~g~Entrée~s~ valider     ~r~Retour~s~ annuler',
    }

    local y = 0.375
    for i = 1, #lines do
        if lines[i] ~= '' then DrawLine(lines[i], y) end
        y = y + 0.025
    end
end

-- ─────────────────────────────────────────────────────────────
-- Position visée
-- ─────────────────────────────────────────────────────────────

local function AimedPosition()
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local rx, rz = math.rad(camRot.x), math.rad(camRot.z)
    local cosRx  = math.abs(math.cos(rx))
    local dir    = vector3(-math.sin(rz) * cosRx, math.cos(rz) * cosRx, math.sin(rx))
    local dest   = camPos + dir * Config.PlacementDistance

    -- 1 = décor, 16 = objets. Le fantôme est ignoré (dernier paramètre).
    local handle = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        dest.x, dest.y, dest.z,
        17, preview or 0, 0
    )
    local _, hit, endCoords = GetShapeTestResult(handle)

    local pos = (hit == 1) and endCoords or dest

    if snap then
        local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
        if found then
            -- previewMin.z = distance entre l'origine du modèle et son point
            -- le plus bas : on pose donc la BASE de l'objet sur le sol.
            pos = vector3(pos.x, pos.y, groundZ - (previewMin and previewMin.z or 0.0))
        end
    end

    return vector3(pos.x, pos.y, pos.z + heightOff)
end

-- ─────────────────────────────────────────────────────────────
-- Contrôles
-- ─────────────────────────────────────────────────────────────

local function BlockControls()
    DisablePlayerFiring(PlayerId(), true)
    DisableControlAction(0, 24, true)    -- attaque
    DisableControlAction(0, 25, true)    -- viser
    DisableControlAction(0, 47, true)    -- G (arme)
    DisableControlAction(0, 58, true)    -- lancer
    DisableControlAction(0, 73, true)    -- X
    DisableControlAction(0, 74, true)    -- H
    DisableControlAction(0, 14, true)    -- molette bas (armes)
    DisableControlAction(0, 15, true)    -- molette haut (armes)
    DisableControlAction(0, 16, true)
    DisableControlAction(0, 17, true)
    DisableControlAction(0, 99, true)
    DisableControlAction(0, 100, true)
    -- Le menu pause reste volontairement accessible : personne ne doit
    -- pouvoir se retrouver coincé dans le mode placement.
end

local function ScrollDelta()
    -- Selon la configuration du joueur, la molette remonte sur l'un ou
    -- l'autre de ces contrôles : on écoute les deux.
    if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then
        return 1
    elseif IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then
        return -1
    end
    return 0
end

local function HandleInput()
    local fine = IsControlPressed(0, Config.Keys.Fine)

    local scroll = ScrollDelta()
    if scroll ~= 0 then
        local step = (fine and Config.RotationStepFine or Config.RotationStep) * scroll
        rot[axis] = (rot[axis] + step) % 360.0
    end

    if IsDisabledControlJustPressed(0, Config.Keys.CycleAxis) then
        axis = AXIS_NEXT[axis]
    end

    if IsDisabledControlJustPressed(0, Config.Keys.ToggleSnap) then
        snap = not snap
    end

    if IsDisabledControlJustPressed(0, Config.Keys.ResetRot) then
        rot.x, rot.y, rot.z = 0.0, 0.0, 0.0
        heightOff = 0.0
    end

    local hStep = fine and Config.HeightStepFine or Config.HeightStep
    if IsControlPressed(0, Config.Keys.HeightUp) then
        heightOff = heightOff + hStep
    elseif IsControlPressed(0, Config.Keys.HeightDown) then
        heightOff = heightOff - hStep
    end
end

-- ─────────────────────────────────────────────────────────────
-- Entrée / sortie du mode
-- ─────────────────────────────────────────────────────────────

local function DestroyPreview()
    if preview and DoesEntityExist(preview) then
        SetEntityAsMissionEntity(preview, true, true)
        DeleteEntity(preview)
    end
    preview = nil
end

function Placement.Stop()
    Placement.active = false
    DestroyPreview()
    Props.editing = nil
    editingId     = nil
end

function Placement.Start(model, existingId, startRot)
    if Placement.active then
        Props.Notify('~r~Un placement est déjà en cours.')
        return
    end
    if not Props.canUse then
        Props.Notify('~r~Vous n\'avez pas accès à cette fonctionnalité.')
        return
    end

    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        Props.Notify('~r~Modèle inconnu : ~w~' .. model)
        return
    end

    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(10)
        waited = waited + 10
    end
    if not HasModelLoaded(hash) then
        Props.Notify('~r~Impossible de charger le modèle : ~w~' .. model)
        return
    end

    modelName = model
    editingId = existingId
    heightOff = 0.0
    snap      = Config.SnapToGround
    axis      = 'z'
    rot.x     = startRot and startRot.x or 0.0
    rot.y     = startRot and startRot.y or 0.0
    rot.z     = startRot and startRot.z or 0.0

    previewMin = select(1, GetModelDimensions(hash))

    local pos = GetEntityCoords(PlayerPedId())
    preview = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityAlpha(preview, 170, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetEntityInvincible(preview, true)
    SetModelAsNoLongerNeeded(hash)

    -- On masque le prop d'origine pendant qu'on le déplace
    Props.editing = existingId

    Placement.active = true

    CreateThread(function()
        while Placement.active do
            Wait(0)

            BlockControls()
            HandleInput()

            local target = AimedPosition()
            SetEntityCoords(preview, target.x, target.y, target.z, false, false, false, false)
            SetEntityRotation(preview, rot.x, rot.y, rot.z, 2, true)

            DrawHud()

            if IsDisabledControlJustPressed(0, Config.Keys.Confirm) then
                local coords = GetEntityCoords(preview)
                local final  = { x = coords.x, y = coords.y, z = coords.z,
                                 rx = rot.x, ry = rot.y, rz = rot.z }

                if editingId then
                    TriggerServerEvent('props:update', editingId, final)
                else
                    TriggerServerEvent('props:create', modelName, final)
                end

                Placement.Stop()

            elseif IsDisabledControlJustPressed(0, Config.Keys.Cancel) then
                Props.Notify('~r~Placement annulé.')
                Placement.Stop()
            end
        end
    end)
end

-- Sécurité : si la ressource s'arrête en plein placement
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Placement.Stop()
end)
