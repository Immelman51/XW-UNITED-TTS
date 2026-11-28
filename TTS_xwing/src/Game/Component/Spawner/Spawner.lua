local Dim = require("Dim")
local ShipVerification = require("Ship.ShipVerification")
local Vect = require("TTS_Lib.Vector.Vector")
local Decker = require("Game.Component.Spawner.Decker")

local Spawner = {}
local PILOT_CARD_SCRIPT_URL =
    "https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/TTS_xwing/src/Game/Component/Spawner/PilotCard.lua"
local LIMITED_PILOT_BULLET = "•"
local cachedPilotCardScript = nil
local pendingSpawnRequests = {}
local isLoadingPilotCardScript = false

local function RotMatrix(axis, angDeg)
    local ang = math.rad(angDeg)
    local cs = math.cos
    local sn = math.sin

    if axis == 'x' then
        return {
            { 1, 0,       0 },
            { 0, cs(ang), -1 * sn(ang) },
            { 0, sn(ang), cs(ang) }
        }
    elseif axis == 'y' then
        return {
            { cs(ang),      0, sn(ang) },
            { 0,            1, 0 },
            { -1 * sn(ang), 0, cs(ang) }
        }
    elseif axis == 'z' then
        return {
            { cs(ang), -1 * sn(ang), 0 },
            { sn(ang), cs(ang),      0 },
            { 0,       0,            1 }
        }
    end
end

local function RotateVector(rotMat, vect)
    local out = { 0, 0, 0 }
    for i = 1, 3, 1 do
        for j = 1, 3, 1 do
            out[i] = out[i] + rotMat[i][j] * vect[j]
        end
    end
    return out
end

local function LocalPos(object, position)
    local rot = object.getRotation()
    local lPos = { position[1], position[2], position[3] }
    -- Z-X-Y extrinsic
    local zRot = RotMatrix('z', rot.z)
    lPos = RotateVector(zRot, lPos)
    local xRot = RotMatrix('x', rot.x)
    lPos = RotateVector(xRot, lPos)
    local yRot = RotMatrix('y', rot.y)
    lPos = RotateVector(yRot, lPos)

    return Vect.Sum(lPos, object.getPosition())
end

local configTokenScript =
[[
__XW_Token = true
__XW_TokenIdle = true
__XW_TokenType = 'config'

self.addTag('Flippable')

function onFlip()
    local ship = Global.call("getShipTokenIsAssignedTo", { token = self })
    if ship and ship.getVar("SetConfiguration") then
        ship.call("SetConfiguration", { ConfigId = self.is_face_down and 1 or 2 })
    end
end
]]

--spawner function, checks for Pilots and Upgrades lists and spawn the respective objects

local legacyFactionKeys = {
    [0] = "dummy",
    [1] = "rebelalliance",
    [2] = "galacticempire",
    [3] = "scumandvillainy",
    [4] = "resistance",
    [5] = "firstorder",
    [6] = "galacticrepublic",
    [7] = "separatistalliance",
    [8] = "shadowcollective",
    Dum = "dummy",
    Reb = "rebelalliance",
    Imp = "galacticempire",
    Scu = "scumandvillainy",
    Res = "resistance",
    For = "firstorder",
    Rep = "galacticrepublic",
    Cis = "separatistalliance",
    Sha = "shadowcollective"
}

local function normalizeLegacySpawnerList(listTable)
    if listTable == nil then
        return
    end

    listTable.Faction = legacyFactionKeys[listTable.Faction] or listTable.Faction
    for _, pilot in pairs(listTable.Pilots or {}) do
        if pilot.Data ~= nil then
            pilot.Data.Faction = legacyFactionKeys[pilot.Data.Faction] or pilot.Data.Faction
        end
    end
end

local function createSpawnSession(spawnCard, anchorPosition, anchorRotation)
    local session = {
        spawnCard = spawnCard,
        anchorPosition = anchorPosition,
        anchorRotation = anchorRotation,
        spawnedGUIDs = {},
        spawnedGUIDLookup = {},
        waitIDs = {},
        pendingWaits = 0,
        synchronousPhaseComplete = false,
        failed = false,
        complete = false
    }

    function session:track(object)
        if object == nil then
            return object
        end

        local guid = object.getGUID()
        if guid ~= nil and not self.spawnedGUIDLookup[guid] then
            self.spawnedGUIDLookup[guid] = true
            table.insert(self.spawnedGUIDs, guid)
        end
        return object
    end

    function session:restoreAnchor()
        self.spawnCard.setPosition(self.anchorPosition)
        self.spawnCard.setRotation(self.anchorRotation)
    end

    function session:stopPendingWaits()
        for waitID, _ in pairs(self.waitIDs) do
            Wait.stop(waitID)
        end
        self.waitIDs = {}
        self.pendingWaits = 0
    end

    function session:destroySpawnedObjects()
        for index = #self.spawnedGUIDs, 1, -1 do
            local object = getObjectFromGUID(self.spawnedGUIDs[index])
            if object ~= nil then
                object.destruct()
            end
        end
        self.spawnedGUIDs = {}
        self.spawnedGUIDLookup = {}
    end

    function session:fail(spawnError)
        if self.failed or self.complete then
            return
        end

        self.failed = true
        self:stopPendingWaits()
        self:destroySpawnedObjects()
        self:restoreAnchor()
        printToAll("Spawner failed; created squad objects were removed.", { 1, 0.2, 0.2 })
        print("Spawner failure: " .. tostring(spawnError))
    end

    function session:tryComplete()
        if not self.failed and self.synchronousPhaseComplete and self.pendingWaits == 0 then
            self.complete = true
            if self.onComplete then
                pcall(self.onComplete)
            end
            self.spawnedGUIDs = {}
            self.spawnedGUIDLookup = {}
        end
    end

    function session:finishSynchronousPhase()
        self.synchronousPhaseComplete = true
        self:tryComplete()
    end

    function session:waitCondition(action, condition)
        if self.failed then
            return
        end

        self.pendingWaits = self.pendingWaits + 1
        local waitID
        local function executeAction()
            self.waitIDs[waitID] = nil
            self.pendingWaits = self.pendingWaits - 1
            if self.failed then
                return
            end

            local success, actionError = pcall(action)
            if not success then
                self:fail(actionError)
                return
            end
            self:tryComplete()
        end
        local function evaluateCondition()
            if self.failed then
                return false
            end

            local success, isReady = pcall(condition)
            if not success then
                self:fail(isReady)
                return false
            end
            return isReady
        end

        waitID = Wait.condition(executeAction, evaluateCondition)
        self.waitIDs[waitID] = true
    end

    function session:waitFrames(action, frameCount)
        if self.failed then
            return
        end

        self.pendingWaits = self.pendingWaits + 1
        local waitID
        local function executeAction()
            self.waitIDs[waitID] = nil
            self.pendingWaits = self.pendingWaits - 1
            if self.failed then
                return
            end

            local success, actionError = pcall(action)
            if not success then
                self:fail(actionError)
                return
            end
            self:tryComplete()
        end

        waitID = Wait.frames(executeAction, frameCount)
        self.waitIDs[waitID] = true
    end

    return session
end

local function initializeSpawnerAccessoryContext(context, spawnCard, bagPosition)
    context.bag = getObjectFromGUID(bagGuids['Accessories']).clone({ position = bagPosition })
    context.tokens = {}
    context.borrowedSources = {}
    context.accessories = context.bag.getObjects()

    for _, accessory in ipairs(context.accessories) do
        if accessory.name == 'Charge' or accessory.name == 'Force' or accessory.name == 'Shield' or
            accessory.name == 'Energy' then
            context.tokens[accessory.name] = context.bag.takeObject({
                rotation = spawnCard.getRotation(),
                guid = accessory.guid,
                smooth = false
            })
        end
    end

end

local function takeSpawnerAccessorySource(context, parameters)
    local source = context.bag.takeObject(parameters)
    context.borrowedSources[source.getGUID()] = true
    return source
end

local function returnSpawnerAccessorySource(context, source)
    local guid = source.getGUID()
    context.bag.putObject(source)
    context.borrowedSources[guid] = nil
end

local function destroySpawnerAccessoryContext(context)
    if context == nil then
        return
    end
    for guid, _ in pairs(context.borrowedSources or {}) do
        local source = getObjectFromGUID(guid)
        if source ~= nil then
            source.destruct()
        end
    end
    if context.bag ~= nil then
        context.bag.destruct()
    end
    for _, token in pairs(context.tokens or {}) do
        token.destruct()
    end
end

local function cloneSpawnerToken(session, template, position, ownerVar, owner, tokenName)
    local token = session:track(template.clone())
    token.setPosition(position)
    token.setVar(ownerVar, owner)
    if tokenName ~= nil then
        token.setVar("charge_name", tokenName)
    end
    return token
end

local function spawnPilotResourceTokens(session, pilot, spawnCard, tokens, hasMobileUpgrade)
    -- Spawn pilot and standardized-loadout charge tokens.
    if pilot.Charge > 0 or pilot.standardized_loadout then
        local chargeValue = pilot.Charge
        while chargeValue > 0 do
            chargeValue = chargeValue - 1
            local position
            if pilot.standardized_loadout then
                position = LocalPos(spawnCard, { 0.5 + 0.9 * chargeValue, 1, 3.4 })
                if chargeValue > 2 then
                    position = LocalPos(spawnCard, { 0.5 + 0.9 * (chargeValue - 3), 1, 2.5 })
                end
            elseif chargeValue == 3 then
                position = LocalPos(spawnCard, { -0.9, 1, 0.6 })
            elseif chargeValue == 2 then
                position = LocalPos(spawnCard, { 0.9, 1, 1.6 })
            elseif chargeValue == 1 then
                position = LocalPos(spawnCard, { 0, 1, 1.6 })
            elseif chargeValue == 0 then
                position = LocalPos(spawnCard, { -0.9, 1, 1.6 })
            else
                position = vector(0, 0, 0)
            end
            cloneSpawnerToken(session, tokens.Charge, position, "charge_owner", pilot.name)
        end

        if pilot.standardized_loadout and pilot.standardized_upgrades then
            local totalHeight = 3.0
            local step = totalHeight / #pilot.standardized_upgrades
            for index, upgrade in pairs(pilot.standardized_upgrades) do
                if upgrade.charge > 0 then
                    for chargeIndex = 1, upgrade.charge, 1 do
                        local token = cloneSpawnerToken(
                            session,
                            tokens.Charge,
                            LocalPos(spawnCard, { -2.7 - chargeIndex * 0.6, 1, 4 + step * (index - 1) + step / 2 }),
                            "charge_owner",
                            pilot.name,
                            upgrade.name
                        )
                        token.setScale(token.getScale() * 0.75)
                    end
                end
            end
        end
    end

    if pilot.Force > 0 then
        local forceValue = pilot.Force
        while forceValue > 0 do
            forceValue = forceValue - 1
            local position
            if pilot.standardized_loadout then
                position = LocalPos(spawnCard, { 3.2, 1, 4.5 + 0.9 * forceValue })
            elseif hasMobileUpgrade == 1 then
                position = LocalPos(spawnCard, { 1.7 + 0.9 * forceValue, 1, 3.4 })
                if forceValue > 2 then
                    position = LocalPos(spawnCard, { 1.7 + 0.9 * (forceValue - 3), 1, 2.5 })
                end
            else
                position = LocalPos(spawnCard, { 1.7, 1, 3.7 + 0.9 * forceValue })
            end
            cloneSpawnerToken(session, tokens.Force, position, "force_owner", pilot.name)
        end
    end

    if pilot.Energy > 0 then
        local energyValue = pilot.Energy
        while energyValue > 0 do
            energyValue = energyValue - 1
            local position
            if pilot.standardized_loadout then
                position = LocalPos(spawnCard, { 0.5 + 0.9 * energyValue, 1, 3.4 })
                if energyValue > 2 then
                    position = LocalPos(spawnCard, { 0.5 + 0.9 * (energyValue - 3), 1, 2.5 })
                end
            else
                position = LocalPos(spawnCard, { 1.7, 1, 3.7 + 0.9 * energyValue })
            end
            cloneSpawnerToken(session, tokens.Energy, position, "energy_owner", pilot.name)
        end
    end

    -- X-Wing United : les boucliers sont posés au-dessus de la fiche pilote
    if pilot.Shield > 0 and pilot.UnitedFiche == nil then
        local shieldValue = pilot.Shield
        while shieldValue > 0 do
            shieldValue = shieldValue - 1
            local position
            if pilot.standardized_loadout then
                position = LocalPos(spawnCard, { -2.2 + 0.9 * shieldValue, 1, 3.4 })
                if shieldValue > 5 then
                    position = LocalPos(spawnCard, { -2.2 + 0.9 * (shieldValue - 6), 1, 1.6 })
                elseif shieldValue > 2 then
                    position = LocalPos(spawnCard, { -2.2 + 0.9 * (shieldValue - 3), 1, 2.5 })
                end
            else
                position = LocalPos(spawnCard, { -1 + 0.9 * shieldValue, 1, 3.4 })
                if shieldValue > 5 then
                    position = LocalPos(spawnCard, { -1 + 0.9 * (shieldValue - 6), 1, 1.6 })
                elseif shieldValue > 2 then
                    position = LocalPos(spawnCard, { -1 + 0.9 * (shieldValue - 3), 1, 2.5 })
                end
            end
            cloneSpawnerToken(session, tokens.Shield, position, "shield_owner", pilot.name)
        end
    end
end

-- X-Wing United : fiches (leader, pilotes, améliorations) qui remplacent les
-- cartes. Chaque fiche est un bloc plat portant UnitedFicheScript ; sa taille
-- dépend de son texte. Les jetons de charge / Force sont posés dessus.
-- Disposition :
--   - une colonne par pilote (fiche pilote puis ses améliorations en
--     dessous), toutes sur une seule rangée centrée sur la ligne d'ancrage ;
--   - les boucliers du pilote sur une ligne juste au-dessus de sa fiche ;
--   - sous la rangée des fiches, le vaisseau de chaque pilote dans sa
--     colonne, puis son cadran juste en dessous ;
--   - la fiche du leader sous les cadrans, sur toute la largeur.
-- Les positions sont calculées AVANT la création des objets : les fiches
-- apparaissent directement à leur place, verrouillées (pas de chute).
local UnitedFicheScript = require("Game.Component.Spawner.United.UnitedFicheScript")
local UNITED_FICHE_GAP = 0.3        -- espace entre deux fiches
local UNITED_FICHE_THICKNESS = 0.06 -- doit correspondre à UnitedFicheScript
local UNITED_TOKEN_SCALE = 0.75     -- taille des jetons posés sur les fiches
local UNITED_TOKEN_STEP = 0.8       -- écart entre deux jetons
local UNITED_TOKEN_MARGIN = 0.5     -- bords bas / droit de fiche -> centre du jeton
local UNITED_TOKEN_DROP = 0.25      -- hauteur de laquelle les jetons sont lâchés
local UNITED_SHIELD_MARGIN = 0.55   -- distance bord haut de fiche -> boucliers
local UNITED_SHIP_GAP = 1.2         -- bas des fiches -> avant des socles
local UNITED_DIAL_GAP = 0.6         -- arrière des socles -> cadrans
local UNITED_DIAL_DEPTH = 2.6       -- encombrement d'un cadran (avec son étiquette)
local UNITED_LEADER_GAP = 0.8       -- cadrans -> fiche du leader
-- Orientation des vaisseaux et des cadrans : rotation (degrés, autour de
-- l'axe vertical) ajoutée à celle de l'ancre (la main du joueur), pour
-- qu'ils fassent face à l'aire de jeu quel que soit le côté de la table.
-- (Main du joueur rouge : 0° -> vaisseaux à 180°.)
local UNITED_FACING_YAW = 180

local function unitedAnchorYaw(anchor)
    local rotation = anchor.rotation or { 0, 0, 0 }
    return tonumber(rotation.y or rotation[2]) or 0
end

local function unitedFacing(rot, yaw)
    return Vector(rot.x, yaw % 360, rot.z)
end

-- Grand panneau de description à l'écran (UI globale, un panneau par
-- couleur de joueur : voir United/UnitedDetail.xml). Ouvert par un clic
-- sur une fiche (UnitedFicheScript), refermé par un nouveau clic sur la
-- même fiche, par la croix ou par un clic sur le panneau.
local unitedDetailOpen = {}   -- couleur du joueur -> GUID de la fiche affichée

local function unitedDetailHeight(text)
    local lines, pos = 0, 1
    while pos <= #text + 1 do
        local stop = string.find(text, "\n", pos, true) or (#text + 1)
        local line = string.sub(text, pos, stop - 1)
        local visible = #(string.gsub(line, "<[^>]*>", ""))
        lines = lines + math.max(1, math.ceil(visible / 62))
        pos = stop + 1
    end
    return math.max(260, math.min(900, lines * 38 + 150))
end

local UNITED_DETAIL_ROWS = 3    -- rangées de pictogrammes (UnitedDetail.xml)
local UNITED_DETAIL_SLOTS = 16  -- emplacements par rangée

-- Remplit une rangée de pictogrammes ; retourne sa hauteur (0 si vide)
local function unitedFillDetailRow(color, index, row)
    local items = row and row.items or {}
    local suffix = "_" .. color
    for slot = 1, UNITED_DETAIL_SLOTS do
        local item = items[slot]
        local imageId = "UDR" .. index .. "I" .. slot .. suffix
        local textId = "UDR" .. index .. "T" .. slot .. suffix
        if item ~= nil and item.image then
            UI.setAttributes(imageId, { image = item.image, preferredWidth = item.w, preferredHeight = item.h,
                active = "true" })
            UI.setAttribute(textId, "active", "false")
        elseif item ~= nil and (item.text or item.space) then
            local text = item.text or ""
            local size = item.size or 40
            UI.setAttributes(textId, {
                fontSize = size,
                fontStyle = item.bold and "Bold" or "Normal",
                color = item.color or "#FFFFFF",
                preferredWidth = item.space or math.floor(#text * size * 0.62 + 6),
                preferredHeight = row.height,
                active = "true",
            })
            UI.setValue(textId, text)
            UI.setAttribute(imageId, "active", "false")
        else
            UI.setAttribute(imageId, "active", "false")
            UI.setAttribute(textId, "active", "false")
        end
    end
    local rowId = "UDRow" .. index .. suffix
    if #items == 0 then
        UI.setAttribute(rowId, "active", "false")
        return 0
    end
    UI.setAttribute(rowId, "height", row.height)
    UI.setAttribute(rowId, "active", "true")
    return row.height
end

function unitedShowDetail(params)
    local color = params.color
    if color == nil then
        return
    end
    local panel = "UnitedDetail_" .. color
    if unitedDetailOpen[color] ~= nil and unitedDetailOpen[color] == params.guid then
        unitedDetailOpen[color] = nil
        UI.hide(panel)
        return
    end
    unitedDetailOpen[color] = params.guid
    local text = params.text or ""
    -- Rangées de pictogrammes (caractéristiques, actions), puis le texte
    local top = 90
    local rows = params.rows or {}
    for index = 1, UNITED_DETAIL_ROWS do
        local rowId = "UDRow" .. index .. "_" .. color
        UI.setAttribute(rowId, "offsetXY", "30 -" .. top)
        local height = unitedFillDetailRow(color, index, rows[index])
        if height > 0 then
            top = top + height + 12
        end
    end
    UI.setAttribute("UnitedDetailText_" .. color, "offsetXY", "30 -" .. top)
    UI.setAttributes(panel, {
        height = unitedDetailHeight(text) + top - 90,
        color = (params.bgColor or "#101418") .. "F5",
        outline = params.outlineColor or "#D9A61A",
    })
    UI.setAttribute("UnitedDetailTitle_" .. color, "color", params.accentColor or params.outlineColor or "#D9A61A")
    UI.setAttribute("UnitedDetailText_" .. color, "color", params.textColor or "#FFFFFF")
    UI.setValue("UnitedDetailTitle_" .. color, params.title or "")
    UI.setValue("UnitedDetailText_" .. color, text)
    UI.show(panel)
end

function unitedCloseDetail(player, value, id)
    if player == nil or player.color == nil then
        return
    end
    unitedDetailOpen[player.color] = nil
    UI.hide("UnitedDetail_" .. player.color)
end

-- Change la largeur d'une fiche (leader sur toute la largeur) et recalcule
-- sa hauteur ; le nombre de caractères par ligne suit la largeur.
-- (Même calcul que UnitedSquad.fiche, qui n'est pas chargé dans Global.)
local function resizeUnitedFiche(fiche, widthPx)
    if fiche.lines == nil then
        return
    end
    fiche.widthPx = math.floor(widthPx)
    local charsPerLine = math.max(1, math.floor(fiche.charsPerLine * fiche.widthPx / fiche.baseWidthPx))
    local lineTotal = 0
    for _, length in ipairs(fiche.lines) do
        lineTotal = lineTotal + math.max(1, math.ceil(length / charsPerLine))
    end
    fiche.heightPx = math.floor(lineTotal * fiche.lineHeight + fiche.extraPx)
end

-- Copie : la mise en page modifie la fiche (largeur, échelle)
local function copyFiche(fiche)
    local copy = {}
    for key, value in pairs(fiche) do
        copy[key] = value
    end
    return copy
end

local function collectUnitedLeader(leader, fiches)
    if leader ~= nil and leader.fiche ~= nil then
        table.insert(fiches, { fiche = copyFiche(leader.fiche), leader = true })
    end
end

local function collectUnitedPilotFiches(pilot, fiches)
    if pilot.UnitedFiche == nil then
        return
    end
    local column = 1
    for _, entry in ipairs(fiches) do
        if entry.column ~= nil then
            column = math.max(column, entry.column + 1)
        end
    end
    table.insert(fiches, { fiche = copyFiche(pilot.UnitedFiche), column = column, shields = pilot.Shield or 0,
        size = pilot.Size })
    for _, fiche in ipairs(pilot.UnitedUpgradeFiches or {}) do
        table.insert(fiches, { fiche = copyFiche(fiche), column = column })
    end
    return column
end

-- Hauteur de la surface (table, tapis...) sous un point
local function unitedSurfaceY(x, z, fallback)
    local ok, hits = pcall(Physics.cast, {
        origin = { x, 30, z },
        direction = { 0, -1, 0 },
        type = 1,
        max_distance = 60,
    })
    if not ok or hits == nil then
        return fallback
    end
    local best = nil
    for _, hit in ipairs(hits) do
        local object = hit.hit_object
        local ignored = object ~= nil and (object.type == "Scripting" or object.type == "Hand"
            or object.type == "Fog" or object.type == "Layout" or object.type == "Randomize")
        if not ignored and hit.point ~= nil and (best == nil or hit.distance < best.distance) then
            best = hit
        end
    end
    return best and best.point.y or fallback
end

-- Calcule centre, taille et position des jetons de chaque fiche.
-- De haut (côté aire de jeu, ligne d'ancrage) en bas (côté joueur) :
--   boucliers, fiches pilote / améliorations, vaisseaux, cadrans, leader.
local function computeUnitedLayout(fiches, anchor)
    local right = Vector(anchor.right[1], anchor.right[2], anchor.right[3]):normalized()
    local forward = Vector(anchor.forward[1], anchor.forward[2], anchor.forward[3]):normalized()
    local origin = Vector(anchor.position[1], 0, anchor.position[3])

    local function size(entry)
        entry.width = entry.fiche.widthPx * entry.fiche.k
        entry.depth = entry.fiche.heightPx * entry.fiche.k
    end

    local function shieldsPerLine(entry)
        return math.max(1, math.floor((entry.width - 0.2) / UNITED_TOKEN_STEP) + 1)
    end

    -- Colonnes des pilotes (dans l'ordre de l'escadron)
    local columns, order, leaderEntry = {}, {}, nil
    for _, entry in ipairs(fiches) do
        if entry.leader then
            leaderEntry = entry
            entry.baseWidthPx = entry.fiche.widthPx
        else
            local column = columns[entry.column]
            if column == nil then
                column = { entries = {}, id = entry.column }
                columns[entry.column] = column
                table.insert(order, column)
            end
            column.size = column.size or entry.size
            table.insert(column.entries, entry)
        end
    end

    -- Encombrement fixe (ne dépend pas de l'échelle des fiches) : vaisseaux,
    -- cadrans et marges
    local baseDepth = 0
    for _, column in ipairs(order) do
        local mm = Dim.mm_baseSize[column.size or "small"] or Dim.mm_baseSize.small
        baseDepth = math.max(baseDepth, mm * Dim.mm_igu_ratio)
    end
    local shipBlock = 0
    if #order > 0 then
        shipBlock = UNITED_SHIP_GAP + baseDepth + UNITED_DIAL_GAP + UNITED_DIAL_DEPTH
        if leaderEntry ~= nil then
            shipBlock = shipBlock + UNITED_LEADER_GAP
        end
    end

    -- Mesure : largeur / profondeur de la rangée des pilotes, bande des
    -- boucliers au-dessus, profondeur du leader (élargi à toute la rangée)
    local rowWidth, rowDepth, shieldBand, leaderDepth
    local function measure()
        rowWidth, rowDepth, shieldBand, leaderDepth = 0, 0, 0, 0
        for index, column in ipairs(order) do
            column.width, column.depth = 0, 0
            for entryIndex, entry in ipairs(column.entries) do
                size(entry)
                column.width = math.max(column.width, entry.width)
                column.depth = column.depth + entry.depth + ((entryIndex > 1) and UNITED_FICHE_GAP or 0)
                local shields = entry.shields or 0
                if shields > 0 then
                    local lines = math.ceil(shields / shieldsPerLine(entry))
                    shieldBand = math.max(shieldBand,
                        UNITED_SHIELD_MARGIN + (lines - 1) * UNITED_TOKEN_STEP + UNITED_TOKEN_STEP / 2)
                end
            end
            rowWidth = rowWidth + column.width + ((index > 1) and UNITED_FICHE_GAP or 0)
            rowDepth = math.max(rowDepth, column.depth)
        end
        if leaderEntry ~= nil then
            local fiche = leaderEntry.fiche
            local width = math.max(rowWidth, leaderEntry.baseWidthPx * fiche.k)
            resizeUnitedFiche(fiche, width / fiche.k)
            size(leaderEntry)
            leaderDepth = leaderEntry.depth
        end
    end

    -- Taille fixe : aucune réduction, même si le bloc déborde de la place
    -- disponible (aire de jeu, zone de main, voisin)
    measure()

    local function place(entry, x, top)
        local center = origin + right * x + forward * (top - entry.depth / 2)
        local surface = unitedSurfaceY(center.x, center.z, anchor.surfaceY or 1)
        entry.surface = surface
        entry.position = Vector(center.x, surface + UNITED_FICHE_THICKNESS / 2, center.z)
        entry.tokenPositions = {}
        -- Charges / Force : posées sur la fiche, dans le coin bas droite,
        -- chaque jeton suivant à gauche du précédent
        local count = (entry.fiche.charge or 0) + (entry.fiche.force or 0)
        local tokenY = top - entry.depth + math.min(UNITED_TOKEN_MARGIN, entry.depth / 2)
        for index = 1, count do
            local tokenX = x + entry.width / 2 - UNITED_TOKEN_MARGIN - (index - 1) * UNITED_TOKEN_STEP
            local p = origin + right * tokenX + forward * tokenY
            table.insert(entry.tokenPositions, Vector(p.x, surface + UNITED_FICHE_THICKNESS, p.z))
        end
        -- Boucliers : ligne(s) centrée(s) juste au-dessus de la fiche pilote
        -- (la première ligne collée à la fiche, les suivantes vers le haut)
        local shields = entry.shields or 0
        local perLine = shieldsPerLine(entry)
        for index = 1, shields do
            local line = math.floor((index - 1) / perLine)
            local inLine = math.min(perLine, shields - line * perLine)
            local slot = (index - 1) % perLine
            local tokenX = x + (slot - (inLine - 1) / 2) * UNITED_TOKEN_STEP
            local tokenY = top + UNITED_SHIELD_MARGIN + line * UNITED_TOKEN_STEP
            local p = origin + right * tokenX + forward * tokenY
            local y = unitedSurfaceY(p.x, p.z, surface)
            table.insert(entry.tokenPositions, Vector(p.x, y, p.z))
        end
    end

    -- Rangée des pilotes : centrée, sous la bande des boucliers (la ligne
    -- d'ancrage est la limite haute du bloc, côté aire de jeu)
    local rowTop = -shieldBand
    local left = -rowWidth / 2
    for _, column in ipairs(order) do
        local x = left + column.width / 2
        column.x = x
        local top = rowTop
        for _, entry in ipairs(column.entries) do
            place(entry, x, top)
            top = top - entry.depth - UNITED_FICHE_GAP
        end
        left = left + column.width + UNITED_FICHE_GAP
    end

    -- Vaisseaux puis cadrans : une rangée chacun, sous la rangée des fiches,
    -- chaque vaisseau dans la colonne de son pilote
    local slots = {}
    local rowBottom = rowTop - rowDepth
    if #order > 0 then
        local shipY = rowBottom - UNITED_SHIP_GAP - baseDepth / 2
        local dialY = rowBottom - UNITED_SHIP_GAP - baseDepth - UNITED_DIAL_GAP - UNITED_DIAL_DEPTH / 2
        for _, column in ipairs(order) do
            local ship = origin + right * column.x + forward * shipY
            local dial = origin + right * column.x + forward * dialY
            local marker = dial + right * (UNITED_DIAL_DEPTH / 2 + 0.6)
            local fallback = anchor.surfaceY or 1
            slots[column.id] = {
                ship = Vector(ship.x, unitedSurfaceY(ship.x, ship.z, fallback) + 0.5, ship.z),
                dial = Vector(dial.x, unitedSurfaceY(dial.x, dial.z, fallback) + 0.5, dial.z),
                marker = Vector(marker.x, unitedSurfaceY(marker.x, marker.z, fallback) + 1, marker.z),
            }
        end
    end

    -- Leader : sous les cadrans, sur toute la largeur (déjà redimensionné
    -- par measure)
    if leaderEntry ~= nil then
        place(leaderEntry, 0, rowBottom - shipBlock)
    end
    return slots
end

-- Ancre par défaut (spectateur, sans place) : fiches devant le DataPad
local function unitedDefaultAnchor(spawnCard)
    local origin = LocalPos(spawnCard, { 0, 0, -4 })
    local r = spawnCard.getTransformRight()
    local f = spawnCard.getTransformForward()
    return {
        position = origin,
        rotation = spawnCard.getRotation(),
        right = { r.x, 0, r.z },
        forward = { -f.x, 0, -f.z },
    }
end

-- Crée les fiches à leur place (calculée au préalable par
-- computeUnitedLayout), puis les jetons au-dessus, puis :
--   1) dimensionne chaque fiche (setFiche) une fois son script chargé,
--   2) pose les jetons juste au-dessus de leur fiche et les libère.
local function spawnUnitedFiches(session, fiches, anchor, tokens)
    if #fiches == 0 then
        return
    end

    local allTokens = {}
    for _, entry in ipairs(fiches) do
        local object = session:track(spawnObject({
            type = "BlockSquare",
            position = entry.position,
            rotation = anchor.rotation,
            scale = { 1, 1, 1 },
            sound = false,
        }))
        object.setLock(true)
        local bg = string.gsub(entry.fiche.bgColor or "#101418", "#", "")
        object.setColorTint({ (tonumber(string.sub(bg, 1, 2), 16) or 16) / 255,
            (tonumber(string.sub(bg, 3, 4), 16) or 20) / 255, (tonumber(string.sub(bg, 5, 6), 16) or 24) / 255 })
        object.setName(entry.fiche.title or "")
        object.setLuaScript(UnitedFicheScript)
        object.addTag("UnitedFiche")
        entry.object = object

        entry.tokens = {}
        local templates = {}
        for _ = 1, entry.fiche.charge or 0 do
            table.insert(templates, { tokens.Charge, "charge_owner" })
        end
        for _ = 1, entry.fiche.force or 0 do
            table.insert(templates, { tokens.Force, "force_owner" })
        end
        for _ = 1, entry.shields or 0 do
            table.insert(templates, { tokens.Shield, "shield_owner", noName = true })
        end
        for index, template in ipairs(templates) do
            local p = entry.tokenPositions[index]
            -- Créé en hauteur et immobilisé tant que la fiche n'a pas sa taille
            local token = cloneSpawnerToken(session, template[1], { p.x, p.y + 3, p.z }, template[2],
                entry.fiche.owner, (not template.noName) and entry.fiche.title or nil)
            token.setLock(true)
            token.setRotation(anchor.rotation)
            token.setScale(token.getScale() * UNITED_TOKEN_SCALE)
            table.insert(entry.tokens, { object = token, position = p })
            table.insert(allTokens, token)
        end
    end

    local function dropTokens()
        for _, entry in ipairs(fiches) do
            for _, token in ipairs(entry.tokens) do
                local p = token.position
                token.object.setPositionSmooth({ p.x, p.y + UNITED_TOKEN_DROP, p.z }, false, true)
                token.object.setLock(false)
            end
        end
    end

    local function sizeFiches()
        for _, entry in ipairs(fiches) do
            entry.object.call("setFiche", entry.fiche)
        end
        session:waitFrames(dropTokens, 10)
    end

    session:waitCondition(function()
        session:waitFrames(sizeFiches, 10)
    end, function()
        for _, entry in ipairs(fiches) do
            if entry.object.spawning then
                return false
            end
        end
        for _, token in ipairs(allTokens) do
            if token.spawning then
                return false
            end
        end
        return true
    end)
end

local function cloneSpawnerAccessory(session, accessoryContext, accessory, position, rotation)
    local source = takeSpawnerAccessorySource(accessoryContext, {
        position = position,
        rotation = rotation,
        guid = accessory.guid,
        smooth = false
    })
    local clone = session:track(source.clone())
    clone.setPosition(position)
    returnSpawnerAccessorySource(accessoryContext, source)
    return clone
end

local function cloneAllMatchingSpawnerAccessories(session, accessoryContext, accessoryName, position, rotation)
    local clones = {}
    for _, accessory in pairs(accessoryContext.accessories) do
        if accessory.name == accessoryName then
            table.insert(clones, cloneSpawnerAccessory(session, accessoryContext, accessory, position, rotation))
        end
    end
    return clones
end

local function spawnAssignableAccessories(session, accessoryContext, accessoryName, position, rotation)
    for _, clone in ipairs(cloneAllMatchingSpawnerAccessories(session, accessoryContext, accessoryName, position,
        rotation)) do
        clone.addTag("Assignable")
    end
end

local function spawnPilotAccessories(session, pilot, spawnCard, accessoryContext, faction, rotation, arcPosition)
    faction = pilot.Data.Faction or faction
    for mount, turret in pairs(pilot.Data.arcs.turret or {}) do
        local indicatorName = 'Arc Indicator' .. tostring(faction)
        if turret.type[1] == 'doubleturret' then
            indicatorName = 'Dual Arc Indicator' .. tostring(faction)
        end
        local mountingPoint = pilot.Data.mountingPoints[mount]
        local offset = LocalPos(spawnCard, { mountingPoint[1], 0, mountingPoint[2] + 9 })
        for _, indicator in ipairs(cloneAllMatchingSpawnerAccessories(session, accessoryContext, indicatorName, offset,
            rotation)) do
            indicator.setPosition(arcPosition)
            indicator.setName(string.gsub(indicator.getName(), faction, ''))
        end
    end

    local markerPosition = pilot.UnitedMarkerPosition or LocalPos(spawnCard, { -1.5, 1, 8.7 })
    if pilot.Bomb == true then
        for _, bombDrop in ipairs(cloneAllMatchingSpawnerAccessories(session, accessoryContext, 'Bomb drop token (unassigned)',
            markerPosition, rotation)) do
            bombDrop.setDescription(pilot.bombD)
        end
    end
    if pilot.Docking == true then
        cloneAllMatchingSpawnerAccessories(session, accessoryContext, 'Shuttle Launcher (assigned to mothership)',
            markerPosition,
            rotation)
    end
    if pilot.wingleader == true then
        cloneAllMatchingSpawnerAccessories(session, accessoryContext, 'Epic Wing Token', markerPosition, rotation)
    end
end

local function spawnSpawnerRemotes(session, remotes, spawnCard, accessoryContext)
    for _, remote in pairs(remotes or {}) do
        local remoteName = type(remote) == 'table' and remote.name or remote
        local remoteCharge = type(remote) == 'table' and (remote.Charge or 0) or 0
        print("Spawning remote:" .. remoteName)
        for _, accessory in ipairs(accessoryContext.accessories) do
            if accessory.name == remoteName then
                local position = LocalPos(spawnCard, { 1, 1, 0 })
                print("Found remote, spawning pos: " .. tostring(position[1]) .. "," ..
                    tostring(position[2]) .. "," .. tostring(position[3]))
                cloneSpawnerAccessory(session, accessoryContext, accessory, position, spawnCard.getRotation())

                local charge = remoteCharge
                while charge > 0 do
                    local chargePosition
                    if charge == 2 then
                        chargePosition = LocalPos(spawnCard, { 1.45, 1, -2.2 })
                    elseif charge == 1 then
                        chargePosition = LocalPos(spawnCard, { 0.55, 1, -2.2 })
                    end
                    charge = charge - 1
                    cloneSpawnerToken(session, accessoryContext.tokens.Charge, chargePosition, "charge_owner", remoteName,
                        remoteName)
                end

                spawnCard.setPosition(LocalPos(spawnCard, { -3, 0, 0 }))
                break
            end
        end
    end
end

local function spawnSpawnerObstacles(session, obstacles, spawnCard, bagPosition)
    if obstacles == nil then
        return
    end

    local obstacleBag = getObjectFromGUID(bagGuids['Obstacles']).clone({ position = bagPosition })
    local borrowedObstacles = {}
    local success, spawnError = pcall(function()
        local availableObstacles = obstacleBag.getObjects()
        for _, obstacleName in ipairs(obstacles) do
            local found = false
            for _, obstacle in ipairs(availableObstacles) do
                if obstacle.name == obstacleName then
                    print("Found obstacle: " .. obstacle.name .. " - " .. obstacleName)
                    local position = LocalPos(spawnCard, { 0, 1, 0 })
                    local obstacleToken = obstacleBag.takeObject({
                        rotation = spawnCard.getRotation(),
                        guid = obstacle.guid,
                        smooth = false
                    })
                    local obstacleGuid = obstacleToken.getGUID()
                    borrowedObstacles[obstacleGuid] = true
                    local obstacleClone = session:track(obstacleToken.clone())
                    obstacleClone.setPosition(position)
                    obstacleBag.putObject(obstacleToken)
                    borrowedObstacles[obstacleGuid] = nil
                    found = true
                    break
                end
            end
            if not found then
                print("Couldnt find obstacle: " .. obstacleName)
            else
                spawnCard.setPosition(LocalPos(spawnCard, { -4, 0, 0 }))
            end
        end
    end)
    obstacleBag.destruct()
    for guid, _ in pairs(borrowedObstacles) do
        local source = getObjectFromGUID(guid)
        if source ~= nil then
            source.destruct()
        end
    end

    if not success then
        error(spawnError)
    end
end

local function spawnPilotCardAndDial(context, pilot, pilotName, pilotCustomization, tint)
    local session = context.session
    local accessoryContext = context.accessoryContext
    local spawnCard = context.spawnCard
    local dialSkin = pilot.dialSkin or context.dialSkin
    local pilotCardScript = context.pilotCardScript

    local card = pilotCustomization.face or pilot.card
    local cardB = pilotCustomization.back or pilot.cardB
    local pos = LocalPos(spawnCard, { 0, 1.2, 5.5 })
    local rot = spawnCard.getRotation()
    local pilotCard = nil

    if card ~= '' and cardB ~= nil then
        local deck = Decker.Asset(card, cardB)
        local spawnedCard = Decker.Card(deck, 1, 1)
        pilotCard = session:track(spawnedCard:spawn({ position = pos, rotation = rot }))
        pilotCard.setName(pilotName)
        pilotCard.setDescription(pilot.list)
        pilotCard.setLuaScript(pilotCardScript)
        pilotCard.setTable("PointsTrackerConfig", {
            landscape = pilot.standardized_loadout == true,
            visible = ShouldShowShipPointsTrackerForCurrentLayout()
        })
        pilotCard.setLock(true)

        local idpos = pos
        local idrot = rot
        local trackedCard = pilotCard
        local pilotIdSpawnFunc = function()
            local pilotId = session:track(spawnObject({
                type = "Custom_Model",
                position = idpos,
                rotation = idrot,
                scale = Dim.mm_ship_scale,
                sound = false,
                snap_to_grid = false,
            }))
            pilotId.setCustomObject({
                mesh =
                '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/cardid.obj',
                convex = true,
                material = 1,
                type = 0
            })
            pilotId.setColorTint(tint)
            trackedCard.addAttachment(pilotId)
            trackedCard.setLock(false)
        end
        session:waitCondition(pilotIdSpawnFunc, function()
            return not trackedCard.spawning
        end)
    end

    if pilotName ~= '' then
        for _, acc in pairs(accessoryContext.accessories) do
            if acc.name == 'Unassigned Dial' then
                local dialpos = pilot.UnitedDialPosition or LocalPos(spawnCard, { 0, 1, 13.2 })
                local dialrot = pilot.UnitedFacing and unitedFacing(rot, pilot.UnitedFacing) or rot
                local dial = takeSpawnerAccessorySource(accessoryContext, {
                    position = dialpos,
                    rotation = dialrot,
                    guid = acc.guid
                })
                local newDial = session:track(dial.clone())
                newDial.setPosition(pos)
                returnSpawnerAccessorySource(accessoryContext, dial)
                local conditionFunc = function()
                    -- X-Wing United : pas de carte pilote, le cadran ne doit pas l'attendre
                    return (pilotCard == nil or not pilotCard.spawning) and (not newDial.spawning)
                end
                local executeFunc = function()
                    newDial.setCustomObject({ ['diffuse'] = dialSkin })
                    newDial = session:track(newDial.reload())
                    newDial.setColorTint(tint)
                    newDial.setPosition(dialpos)
                    newDial.setRotation(dialrot)
                    if pilotCard ~= nil then
                        pilotCard.call('addTintObject', { 'dial', newDial })
                    end
                end
                session:waitCondition(executeFunc, conditionFunc)
            end
        end
    end

    return pilotCard
end

local function resolvePilotTexture(pilot, pilotCustomization, pilotName)
    if pilotCustomization.texture ~= nil then
        return pilotCustomization.texture
    end

    local textureKey = pilot.Data.texture
    local textureUrl
    if textureKey ~= nil and pilot.Data.textures ~= nil then
        textureUrl = pilot.Data.textures[textureKey]
    end
    if textureUrl ~= nil then
        return '{verifycache}' .. textureUrl
    end
    if textureKey ~= nil then
        print("Missing ship texture '" .. tostring(textureKey) .. "' for " .. tostring(pilotName) ..
            " (" .. tostring(pilot.Data.shipId) .. ")")
    end
    return nil
end

-- X-Wing United : combinaisons taille/arc pour lesquelles il existe un socle
-- par faction United (assets/ships-v2/bases/<taille>/<arc>/<faction>.png).
-- Ajouter une ligne ici quand de nouvelles images sont créées.
local UNITED_BASE_SETS = {
    ["small/frontback"] = true,
}

local function spawnCompositeShipBase(context, pilot, pilotName, texture, modeltint)
    local session = context.session
    local spawnCard = context.spawnCard
    local faction = context.faction
    local spawnPrefix = context.spawnPrefix
    local factionnames = context.factionnames

    local shipoffset = vector(0, 2.2, 0)
    local size = pilot.Size
    local arcs = pilot.Data.arcs
    local fixedarc = "none"
    if arcs.fixed then
        fixedarc = arcs.fixed.type[1] or "none"
    end

    local pos
    if pilot.UnitedShipPosition then
        pos = pilot.UnitedShipPosition
    elseif size == "huge" then
        pos = LocalPos(spawnCard, { 0, 0, 13.2 })
    else
        pos = LocalPos(spawnCard, { 0, 0, 10.2 })
    end
    local rot = spawnCard.getRotation()
    if pilot.UnitedFacing then
        rot = unitedFacing(rot, pilot.UnitedFacing)
    end
    local base_prototype = getObjectFromGUID(CompositeBase_GUID)
    local pilotFaction = pilot.Data.Faction or faction
    local factionName = factionnames[pilotFaction]
    if factionName == nil then
        print("Missing faction base texture for faction " .. tostring(faction) .. " on " .. tostring(pilotName))
        factionName = factionnames[1]
    end
    if pilot.UnitedBase and UNITED_BASE_SETS[size .. "/" .. fixedarc] then
        factionName = pilot.UnitedBase
    end
    local baseDiffuse = spawnPrefix .. "bases/" .. size .. "/" .. fixedarc .. "/" .. factionName .. ".png"
    local newShip = session:track(base_prototype.clone())
    -- Move without collisions; dependent attachments wait until the fast smooth move completes.
    newShip.setPositionSmooth(pos, false, true)
    newShip.setRotationSmooth(rot, false, true)
    newShip.setScale(Dim.mm_ship_scale)

    newShip.setCustomObject({
        mesh = spawnPrefix .. "bases/" .. size .. "/base.obj?1",
        collider = ShipVerification.colliders[size],
        diffuse = baseDiffuse,
        convex = true,
        material = 1,
        type = 1
    })
    newShip.setTable("Data", pilot.Data)
    newShip.setLock(true)
    if pilot.Data.ProximityHider then
        newShip.addTag("ProximityHider")
    end

    local base_name_str = pilotName
    if pilot.Data.limited and pilot.Data.limited > 0 then
        base_name_str = string.rep(LIMITED_PILOT_BULLET, pilot.Data.limited) .. " " .. pilotName
    end
    newShip.setTable("UiData", {
        name = base_name_str,
        icon = pilot.Icon or pilot.Ship,
        init = "init" .. pilot.Data.initiative
    })

    local pegtype = pilot.peg or size
    local pegCustomObject = {
        mesh = spawnPrefix .. "bases/pegs/" .. pegtype .. ".obj",
        diffuse = baseDiffuse,
        collider =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/minisculebox.obj',
        convex = true,
        material = 1,
        type = 1
    }
    local shippos = pos
    local shiprot = rot
    local ship = newShip
    local shipCustomObject
    if pilot.Data.mesh then
        shipCustomObject = {
            mesh = '{verifycache}' .. pilot.Data.mesh,
            diffuse = texture,
            collider =
            '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/minisculebox.obj',
            convex = true,
            material = 1,
            type = 1
        }
    end

    local pegAndShipSpawnFunction = function()
        local pegModel = session:track(spawnObject({
            type         = "Custom_Model",
            position     = shippos,
            rotation     = shiprot,
            scale        = Dim.mm_ship_scale,
            sound        = false,
            snap_to_grid = false,
        }))
        pegModel.setName("Peg")
        pegModel.setCustomObject(pegCustomObject)
        ship.addAttachment(pegModel)
        if shipCustomObject then
            local shipModel = session:track(spawnObject({
                type         = "Custom_Model",
                position     = vector(shippos[1], shippos[2], shippos[3]) + shipoffset,
                rotation     = shiprot,
                scale        = Dim.mm_ship_scale,
                sound        = false,
                snap_to_grid = false,
            }))
            shipModel.setName("Ship")
            shipModel.setCustomObject(shipCustomObject)
            shipModel.setColorTint(modeltint)
            ship.addAttachment(shipModel)
        end
    end
    session:waitCondition(pegAndShipSpawnFunction,
        function() return (not ship.spawning) and (not ship.isSmoothMoving()) end)

    return {
        ship = ship,
        shipOffset = shipoffset,
        shipPosition = pos,
        shipRotation = rot,
    }
end

local function shipIdCustomObjectForSize(size)
    local customObj = {
        convex = true,
        material = 1,
        type = 1,
        collider =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/minisculebox.obj',
    }
    if size == "small" then
        customObj.mesh =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/Base_ID_Marker.obj'
    elseif size == "medium" then
        customObj.mesh =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/Base%20ID%20MED.obj'
    elseif size == "large" then
        customObj.mesh =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/Base%20ID%20LAR.obj'
    elseif size == "huge" then
        customObj.mesh =
        '{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/models/Base_ID_HUGE.obj'
    end
    return customObj
end

local function spawnShipIdentifiersAndConfig(context, pilot, pilotCard, tint, modeltint, texture, shipSpawnResult)
    local session = context.session
    local spawnCard = context.spawnCard

    local ship = shipSpawnResult.ship
    local shipoffset = shipSpawnResult.shipOffset
    local pos = shipSpawnResult.shipPosition
    local rot = shipSpawnResult.shipRotation

    local idpos = pos
    local idrot = rot
    local customObj = shipIdCustomObjectForSize(pilot.Size)

    local shipIdSpawnFunc = function()
        local shipId = session:track(spawnObject({
            type = "Custom_Model",
            position = idpos,
            rotation = idrot,
            scale = Dim.mm_ship_scale * 0.99,
            sound = false,
            snap_to_grid = false,
        }))
        shipId.setCustomObject(customObj)
        shipId.setColorTint(tint)
        shipId.setName("ColorId")
        ship.addAttachment(shipId)
        ship.setLock(false)
        ship.addTag("Ship")
        ship.drag_selectable = true
        ship.interactable = true

        if pilotCard ~= nil then
            pilotCard.call('addTintObject', { 'ship', ship })
        end
        ship.call('initContextMenu')
    end
    session:waitCondition(shipIdSpawnFunc,
        function()
            return (not ship.spawning) and (not ship.isSmoothMoving()) and (pilotCard == nil or not pilotCard.spawning)
        end)

    if pilot.Data.Config and pilot.Data.Config.States then
        for k, config in pairs(pilot.Data.Config.States) do
            if config.Model then
                local customObject = ship.getCustomObject()
                customObject.mesh = config.Model
                customObject.diffuse = texture
                local configSpawnFunction = function()
                    local configModel = session:track(spawnObject({
                        type = "Custom_Model",
                        position = vector(idpos[1], idpos[2], idpos[3]) + shipoffset,
                        rotation = idrot,
                        scale = Dim.mm_ship_scale,
                        sound = false,
                        snap_to_grid = false,
                    }))
                    configModel.setName("Config")
                    configModel.setDescription(tostring(k))
                    configModel.setCustomObject(customObject)
                    configModel.setColorTint(modeltint)
                    if k ~= 1 then
                        configModel.setScale(vector(0.0001, 0.0001, 0.0001))
                    end
                    ship.addAttachment(configModel)
                    session:waitFrames(function()
                        ship.call("DisableAttachedColliders")
                    end, 2)
                    session:waitFrames(function()
                        ship.call("DisableAttachedColliders")
                    end, 10)
                    session:waitFrames(function()
                        ship.call("DisableAttachedColliders")
                    end, 30)
                end
                session:waitCondition(configSpawnFunction,
                    function()
                        return (not ship.spawning) and (not ship.isSmoothMoving())
                    end)
            end
        end
        if pilot.Data.Config and pilot.Data.Config.Token then
            pos = LocalPos(spawnCard, { -1.5, 1, 8.7 })
            local configToken = session:track(spawnObject({
                type = "Custom_Model",
                scale = { 0.38, 0.38, 0.38 },
                rotation = { 0, 270, 0 },
                position = pos,
            }))
            configToken.setCustomObject({
                mesh =
                "https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/Items/tokens/flip/flipToken.obj",
                diffuse = pilot.Data.Config.Token,
                type = 5,
                material = 1,
                specular_intensity = 0
            })
            configToken.setLuaScript(configTokenScript)
        end
    end

    return {
        shipPosition = shipSpawnResult.shipPosition,
        shipRotation = shipSpawnResult.shipRotation,
    }
end

local function spawnPilotShipBundle(context, pilot, upgradeResult, pilotName, pilotCustomization, tint, modeltint, pilotCard)
    local configCardGUID = upgradeResult.configCardGUID
    local texture = resolvePilotTexture(pilot, pilotCustomization, pilotName)

    pilot.Data.ColorId = tint
    if pilot.Data.Config then
        pilot.Data.Config.CardGUID = configCardGUID
    end

    local shipSpawnResult = spawnCompositeShipBase(context, pilot, pilotName, texture, modeltint)

    return spawnShipIdentifiersAndConfig(context, pilot, pilotCard, tint, modeltint, texture, shipSpawnResult)
end

local function spawnPilotBundle(context, pilot, upgradeResult)
    if pilot.id == '' then
        return
    end

    local session = context.session
    local accessoryContext = context.accessoryContext
    local spawnCard = context.spawnCard
    local faction = context.faction
    local customization = context.customization
    local tokens = context.tokens

    local hasMob = upgradeResult.hasMobileUpgrade
    local upNum = upgradeResult.count

    local pilotName = pilot.name
    local pilotCustomization = customization[pilotName] or {}
    local tint = color(0, 0, 0, 0)
    local modeltint = color(1, 1, 1, 1)
    tint = pilotCustomization.tint or tint
    modeltint = pilotCustomization.modeltint or modeltint

    local pilotCard = spawnPilotCardAndDial(context, pilot, pilotName, pilotCustomization, tint)

    if pilot.Condition ~= nil then
        spawnAssignableAccessories(session, accessoryContext, pilot.Condition,
            LocalPos(spawnCard, { -2 - 1.78 * upNum, 1, 8 }), spawnCard.getRotation())
    end

    local shipBundleResult = spawnPilotShipBundle(context, pilot, upgradeResult, pilotName, pilotCustomization, tint,
        modeltint, pilotCard)

    spawnPilotAccessories(session, pilot, spawnCard, accessoryContext, faction, shipBundleResult.shipRotation,
        shipBundleResult.shipPosition)
    spawnPilotResourceTokens(session, pilot, spawnCard, tokens, hasMob)
end

local function isExtendedWidthUpgrade(upgrade)
    return upgrade.extended_width == true
end

local function extendedWidthOffset(upgrade, direction, extendedWidthTuck)
    if isExtendedWidthUpgrade(upgrade) then
        return extendedWidthTuck * direction
    end
    return 0
end

local function upgradeCardLayout(cursor, upgrade, upgradeStepX, upgradeStepY, extendedWidthTuck, extendedWidthStep)
    local widthOffset = extendedWidthOffset(upgrade, -1, extendedWidthTuck)
    local layout = {
        x = cursor.x + widthOffset,
        y = cursor.y,
        z = cursor.z,
    }
    if isExtendedWidthUpgrade(upgrade) then
        cursor.x = cursor.x - extendedWidthStep
    else
        cursor.x = cursor.x - upgradeStepX
    end
    cursor.y = cursor.y - upgradeStepY
    return layout
end

local function configCardLayout(upgrade, configCardAnchorX, extendedWidthTuck)
    local layout = {
        x = configCardAnchorX + extendedWidthOffset(upgrade, 1, extendedWidthTuck),
        y = 0,
        z = 5.5,
    }
    return layout
end

local function localLayoutPos(spawnCard, layout, dx, dy, dz)
    return LocalPos(spawnCard, {
        layout.x + (dx or 0),
        layout.y + (dy or 0),
        layout.z + (dz or 0),
    })
end

local function spawnUpgradeCharges(session, tokenTemplate, spawnCard, upgrade, pilot, layout, isConfiguration)
    local charges = upgrade.Charge
    while charges > 0 do
        local position
        if isConfiguration then
            if charges == 5 then
                position = localLayoutPos(spawnCard, layout, 0.88, 0, -3.6)
            elseif charges == 4 then
                position = localLayoutPos(spawnCard, layout, 0.88, 0, -2.7)
            elseif charges == 3 then
                position = localLayoutPos(spawnCard, layout, -0.02, 0, -2.7)
            elseif charges == 2 then
                position = localLayoutPos(spawnCard, layout, 0.88, 0, -1.8)
            elseif charges == 1 then
                position = localLayoutPos(spawnCard, layout, -0.02, 0, -1.8)
            end
        else
            if charges == 5 then
                position = localLayoutPos(spawnCard, layout, -0.28, 1 - layout.y, -3.6)
            elseif charges == 4 then
                position = localLayoutPos(spawnCard, layout, -0.28, 1 - layout.y, -2.7)
            elseif charges == 3 then
                position = localLayoutPos(spawnCard, layout, -1.18, 1 - layout.y, -2.7)
            elseif charges == 2 then
                position = localLayoutPos(spawnCard, layout, -0.28, 1 - layout.y, -1.8)
            elseif charges == 1 then
                position = localLayoutPos(spawnCard, layout, -1.18, 1 - layout.y, -1.8)
            end
        end
        if position == nil then
            break
        end
        charges = charges - 1
        cloneSpawnerToken(session, tokenTemplate, position, "charge_owner", pilot.name, upgrade.name)
    end
end

local function spawnPilotUpgrades(context, pilot, upgrades)
    local session = context.session
    local accessoryContext = context.accessoryContext
    local spawnCard = context.spawnCard
    local customization = context.customization
    local upgradeStepX = context.upgradeStepX
    local upgradeStepY = context.upgradeStepY
    local extendedWidthTuck = context.extendedWidthTuck
    local extendedWidthStep = context.extendedWidthStep
    local configCardAnchorX = context.configCardAnchorX
    local configCardShiftX = context.configCardShiftX

    local result = {
        configCardGUID = nil,
        hasMobileUpgrade = 0,
        count = 0,
        layoutCursor = { x = -1.42, y = 1, z = 5.5 }
    }

    for _, upgrade in pairs(upgrades) do
        if upgrade.Config == true then
            local layout = configCardLayout(upgrade, configCardAnchorX, extendedWidthTuck)
            spawnCard.setPosition(LocalPos(spawnCard, { configCardShiftX, 0, 0 }))
            local position = localLayoutPos(spawnCard, layout)
            local rotation = spawnCard.getRotation()
            local cardLink = upgrade.card
            local cardBackLink = upgrade.cardB
            if customization[upgrade.name] ~= nil then
                cardLink = customization[upgrade.name].face or upgrade.card
                cardBackLink = customization[upgrade.name].back or upgrade.cardB
            end
            local deck = Decker.Asset(cardLink, cardBackLink)
            local card = Decker.Card(deck, 1, 1)
            local spawnedUpgrade = session:track(card:spawn({
                position = position,
                rotation = rotation,
                scale = { 0.68, 0.68, 0.68 }
            }))
            spawnedUpgrade.setName(upgrade.name)
            spawnedUpgrade.addTag("ConfigCard")
            result.configCardGUID = spawnedUpgrade.getGUID()
            result.hasMobileUpgrade = 1
            spawnUpgradeCharges(session, accessoryContext.tokens.Charge, spawnCard, upgrade, pilot, layout, true)
        end
    end

    for _, upgrade in pairs(upgrades) do
        if upgrade.Config ~= true then
            local layout = upgradeCardLayout(result.layoutCursor, upgrade, upgradeStepX, upgradeStepY,
                extendedWidthTuck, extendedWidthStep)
            local position = localLayoutPos(spawnCard, layout)
            local rotation = spawnCard.getRotation()
            local cardLink = upgrade.card
            local cardBackLink = upgrade.cardB
            if customization[upgrade.name] ~= nil then
                cardLink = customization[upgrade.name].face or upgrade.card
                cardBackLink = customization[upgrade.name].back or upgrade.cardB
            end
            local deck = Decker.Asset(cardLink, cardBackLink)
            local card = Decker.Card(deck, 1, 1)
            local spawnedUpgrade = session:track(card:spawn({
                position = position,
                rotation = rotation,
                scale = { 0.68, 0.68, 0.68 }
            }))
            spawnedUpgrade.setName(upgrade.name)
            if upgrade.Condition ~= nil then
                spawnAssignableAccessories(session, accessoryContext, upgrade.Condition,
                    localLayoutPos(spawnCard, layout, -0.58, 0, 2.5), spawnCard.getRotation())
            end
            spawnUpgradeCharges(session, accessoryContext.tokens.Charge, spawnCard, upgrade, pilot, layout, false)
            result.count = result.count + 1
        end
    end

    return result
end

local function advancePilotSpawnCursor(spawnCard, pilot, upgradeLayoutCursor)
    if pilot.SpawnSpacing then
        spawnCard.setPosition(LocalPos(spawnCard, { -pilot.SpawnSpacing, 0, 0 }))
    elseif pilot.standardized_loadout then
        local charges = 0
        for _, upgrade in pairs(pilot.standardized_upgrades) do
            charges = math.max(charges, upgrade.charge)
        end
        spawnCard.setPosition(LocalPos(spawnCard, { -(5.5 + charges * 0.7), 0, 0 }))
    else
        spawnCard.setPosition(LocalPos(spawnCard, { upgradeLayoutCursor.x - 2.58, 0, 0 }))
    end
end

local function createSpawnRequest(listTable)
    local spawnCard = listTable.spawnCard
    return {
        listTable = listTable,
        anchorPosition = spawnCard.getPosition(),
        anchorRotation = spawnCard.getRotation()
    }
end

local function spawnSquad(request, pilotCardScript)
    local listTable = request.listTable
    normalizeLegacySpawnerList(listTable)
    --listTable contains :

    --Pilots[x] = table

    --Upgrades[x] = {string1, string2...}
    --spawnCard = Object reference used to position the spawned material
    --Faction = String

    local Pilots = listTable.Pilots
    local Upgrades = listTable.Upgrades
    local spawnCard = listTable.spawnCard
    local Faction = listTable.Faction
    local Customization = listTable.Customization or {}
    local dialSkin = listTable.factionDial
    local spawnPrefix =
    "{verifycache}https://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/ships-v2/"
    local factionnames = {
        rebelalliance = "rebel",
        galacticempire = "empire",
        scumandvillainy = "scum",
        resistance = "resistance",
        firstorder = "first-order",
        galacticrepublic = "republic",
        separatistalliance = "separatists",
        shadowcollective = "shadowcollective"
    }

    local bagPosition = { 15, 15, 0 }
    local storePos = request.anchorPosition
    local storeRot = request.anchorRotation
    local session = createSpawnSession(spawnCard, storePos, storeRot)
    if listTable.United then
        local function now()
            local ok, t = pcall(function() return Time.time end)
            return (ok and type(t) == "number") and t or os.time()
        end
        local spawnStart = now()
        session.onComplete = function()
            print(string.format("X-Wing United : escadron posé en %.1f s (objets, modèles 3D, jetons)",
                now() - spawnStart))
        end
    end
    local accessoryContext = { tokens = {} }

    local spawnSuccess, spawnError = pcall(function()
        -- An initial script download can defer spawning; preserve the click-time anchor.
        spawnCard.setPosition(storePos)
        spawnCard.setRotation(storeRot)
        initializeSpawnerAccessoryContext(accessoryContext, spawnCard, bagPosition)
        local tokens = accessoryContext.tokens

        local UPGRADE_STEP_X = 1.78
        local UPGRADE_STEP_Y = 0.2
        local UPGRADE_EXTENDED_WIDTH_TUCK = 0.6
        local UPGRADE_EXTENDED_WIDTH_STEP = UPGRADE_STEP_X + UPGRADE_EXTENDED_WIDTH_TUCK
        local CONFIG_CARD_ANCHOR_X = 1.42
        local CONFIG_CARD_SHIFT_X = -1.9

        -- X-Wing United : la disposition (fiches, vaisseaux, cadrans) est
        -- calculée avant toute création d'objet
        local unitedFiches = {}
        local unitedAnchor = listTable.NotesAnchor
        if listTable.United then
            unitedAnchor = unitedAnchor or unitedDefaultAnchor(spawnCard)
            collectUnitedLeader(listTable.Leader, unitedFiches)
            local pilotColumns = {}
            for index, pilot in ipairs(Pilots) do
                if pilot.id ~= '' then
                    pilotColumns[index] = collectUnitedPilotFiches(pilot, unitedFiches)
                end
            end
            if #unitedFiches > 0 then
                local slots = computeUnitedLayout(unitedFiches, unitedAnchor)
                for index, column in pairs(pilotColumns) do
                    local slot = slots[column]
                    if slot ~= nil then
                        Pilots[index].UnitedShipPosition = slot.ship
                        Pilots[index].UnitedDialPosition = slot.dial
                        Pilots[index].UnitedMarkerPosition = slot.marker
                        Pilots[index].UnitedFacing = unitedAnchorYaw(unitedAnchor) + UNITED_FACING_YAW
                    end
                end
            end
        end

        local shipIndex = 1 --Sets index of ship being spawned

        while Pilots[shipIndex] ~= nil do
            local pilot = Pilots[shipIndex]
            if pilot.standardized_loadout then
                spawnCard.setPosition(LocalPos(spawnCard, { -1.1, 0, 0 }))
            end

            local upgradeResult = spawnPilotUpgrades({
                session = session,
                accessoryContext = accessoryContext,
                spawnCard = spawnCard,
                customization = Customization,
                upgradeStepX = UPGRADE_STEP_X,
                upgradeStepY = UPGRADE_STEP_Y,
                extendedWidthTuck = UPGRADE_EXTENDED_WIDTH_TUCK,
                extendedWidthStep = UPGRADE_EXTENDED_WIDTH_STEP,
                configCardAnchorX = CONFIG_CARD_ANCHOR_X,
                configCardShiftX = CONFIG_CARD_SHIFT_X,
            }, pilot, Upgrades[shipIndex])
            local upgradeLayoutCursor = upgradeResult.layoutCursor

            spawnPilotBundle({
                session = session,
                accessoryContext = accessoryContext,
                spawnCard = spawnCard,
                faction = Faction,
                customization = Customization,
                dialSkin = dialSkin,
                pilotCardScript = pilotCardScript,
                spawnPrefix = spawnPrefix,
                factionnames = factionnames,
                tokens = tokens,
            }, pilot, upgradeResult)


            advancePilotSpawnCursor(spawnCard, pilot, upgradeLayoutCursor)
            shipIndex = shipIndex + 1
        end

        spawnCard.setPosition(LocalPos(spawnCard, { 0, 0, 5.5 }))

        spawnUnitedFiches(session, unitedFiches, unitedAnchor, tokens)

        spawnSpawnerRemotes(session, listTable.Remotes, spawnCard, accessoryContext)

        spawnSpawnerObstacles(session, listTable.Obstacles, spawnCard, bagPosition)
    end)

    -- Temporary source objects and the spawn anchor must be released on success or failure.
    local cleanupSuccess, cleanupError = pcall(function()
        destroySpawnerAccessoryContext(accessoryContext)
        session:restoreAnchor()
    end)

    if not spawnSuccess then
        session:fail(spawnError)
        error(spawnError)
    end
    if not cleanupSuccess then
        session:fail(cleanupError)
        error(cleanupError)
    end
    session:finishSynchronousPhase()
end

local function loadPilotCardScript()
    if isLoadingPilotCardScript then
        return
    end

    isLoadingPilotCardScript = true
    WebRequest.get(PILOT_CARD_SCRIPT_URL, function(request)
        if request.is_error then
            local hadQueuedSpawns = #pendingSpawnRequests > 0
            pendingSpawnRequests = {}
            isLoadingPilotCardScript = false
            if hadQueuedSpawns then
                printToAll("Failed to download pilot card script; squad was not spawned.", { 1, 0.2, 0.2 })
            end
            return
        end
        if not request.is_done then
            return
        end
        if request.text == nil or request.text == "" then
            local hadQueuedSpawns = #pendingSpawnRequests > 0
            pendingSpawnRequests = {}
            isLoadingPilotCardScript = false
            if hadQueuedSpawns then
                printToAll("Downloaded pilot card script was empty; squad was not spawned.", { 1, 0.2, 0.2 })
            end
            return
        end

        cachedPilotCardScript = request.text
        isLoadingPilotCardScript = false
        local queuedSpawns = pendingSpawnRequests
        pendingSpawnRequests = {}
        for _, queuedRequest in ipairs(queuedSpawns) do
            spawnSquad(queuedRequest, cachedPilotCardScript)
        end
    end)
end

function Spawner.newSpawner(listTable)
    local compositeBase = nil
    if CompositeBase_GUID ~= nil then
        compositeBase = getObjectFromGUID(CompositeBase_GUID)
    end
    if compositeBase == nil then
        printToAll(
            "Unable to spawn squad: the composite ship base object is missing from this save. " ..
            "Restore the deleted object or load a save that still contains it.",
            { 1, 0.2, 0.2 }
        )
        print("Spawner aborted: no object found for CompositeBase_GUID " .. tostring(CompositeBase_GUID))
        return
    end

    local request = createSpawnRequest(listTable)
    if cachedPilotCardScript ~= nil then
        spawnSquad(request, cachedPilotCardScript)
        return
    end

    table.insert(pendingSpawnRequests, request)
    loadPilotCardScript()
end

-- Fetch while Global loads so normal player-initiated spawns remain synchronous.
loadPilotCardScript()


return Spawner
