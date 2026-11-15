-- X-Wing United : conversion d'un code d'escadron du squad builder en liste
-- de spawn pour Spawner.lua.
--
-- Format du code (produit par scriptship.js / hasher()) :
--   leaderID,pilotIDuUpgIDuUpgID,pilotID,...,LANGUE
-- ex. "1,155u200u12,4u0,FRA"
-- Le lien de la page d'impression (print_squad.html?#...) est aussi accepté.

local UnitedMapping = require("Game.Component.Spawner.United.UnitedMapping")
local UnitedData = require("Game.Component.Spawner.United.UnitedData")

local UnitedSquad = {}

local DEFAULT_LANG = "FRA"

-- Couleurs d'identification quand plusieurs vaisseaux du même type sont
-- présents (mêmes valeurs que DataPad.lua).
local TINT_COLORS = {
    [1] = { 1, 0, 0, 1 },        -- Rouge
    [2] = { 1, 1, 0, 1 },        -- Jaune
    [3] = { 0, 0.5, 0, 1 },      -- Vert
    [4] = { 0, 0, 1, 1 },        -- Bleu
    [5] = { 1, 0, 0.8, 1 },      -- Rose
    [6] = { 0.5, 0.25, 0.1, 1 }, -- Marron
    [7] = { 1, 1, 1, 1 },        -- Blanc
    [8] = { 0.5, 0.5, 0.5, 1 },  -- Gris
}
local NO_TINT = { 0, 0, 0, 0 }

local DIAL_SKIN_BASE = "http://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/dial/skin/1/"
local DIAL_SKINS = {
    rebelalliance = "Rebel.png",
    galacticempire = "Empire.png",
    scumandvillainy = "Scum.png",
    resistance = "Resistance.png",
    firstorder = "FO.png",
    galacticrepublic = "Republic.png",
    separatistalliance = "CIS.png",
}

-- Espacement horizontal entre deux vaisseaux, selon la taille du socle
local SHIP_SPACING = { small = 4, medium = 5, large = 6, huge = 8 }

---------------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------------

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(s, sep)
    local out = {}
    for part in string.gmatch(s, "([^" .. sep .. "]*)") do
        table.insert(out, part)
    end
    return out
end

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deepcopy(v)
    end
    return out
end

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

-- Texte localisé : champ_FRA / champ_ENG, avec repli sur l'autre langue
-- puis sur le champ sans suffixe.
local function localized(obj, field, lang)
    if obj == nil then
        return ""
    end
    local other = (lang == "ENG") and "FRA" or "ENG"
    local candidates = { field .. "_" .. lang, field .. lang, field .. "_" .. other, field }
    for _, key in ipairs(candidates) do
        local value = obj[key]
        if type(value) == "string" and trim(value) ~= "" and trim(value) ~= "??" then
            return value
        end
    end
    return ""
end

-- Convertit le HTML des textes du builder en texte lisible dans TTS.
function UnitedSquad.cleanText(html, lang)
    lang = (lang == "ENG") and "ENG" or "FRA"
    if html == nil or html == "" then
        return ""
    end
    local text = tostring(html)
    text = text:gsub("<img[^>]-src%s*=%s*['\"]img/([^'\"]+)['\"][^>]*>", function(file)
        local icon = UnitedMapping.TEXT_ICONS[file]
        if icon then
            return icon[lang] or icon.FRA
        end
        return "[" .. file:gsub("%.%w+$", "") .. "]"
    end)
    text = text:gsub("<[bB][rR]%s*/?>", "\n")
    text = text:gsub("</[dD][iI][vV]>", "\n")
    text = text:gsub("</?[pP][^>]*>", "\n")
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&nbsp;", " "):gsub("&lt;", "‹"):gsub("&gt;", "›")
        :gsub("&quot;", "\""):gsub("&#39;", "'"):gsub("&amp;", "&")
    -- TTS interprète < et > comme du texte enrichi : on les neutralise
    text = text:gsub("<", "‹"):gsub(">", "›")
    text = text:gsub("[ \t]+", " ")
    text = text:gsub(" *\n *", "\n"):gsub("\n\n+", "\n")
    return trim(text)
end

local function chargeValue(charge)
    if type(charge) ~= "table" then
        return tonumber(charge) or 0, false
    end
    local count = tonumber(charge[1]) or 0
    local recurring = false
    for i = 2, #charge do
        if charge[i] == "+" then
            recurring = true
        end
    end
    return count, recurring
end

local function chargeLabel(count, recurring, lang)
    if count <= 0 then
        return ""
    end
    local text = tostring(count) .. " charge" .. (count > 1 and "s" or "")
    if recurring then
        text = text .. ((lang == "ENG") and " (recurring)" or (count > 1 and " (récurrentes)" or " (récurrente)"))
    end
    return text
end

---------------------------------------------------------------------------
-- Lecture du code d'escadron
---------------------------------------------------------------------------

-- Retourne { leaderId, lang, ships = { { pilotId, upgrades = {ids} } } }
-- ou nil, message d'erreur.
function UnitedSquad.parseCode(code)
    code = trim(code)
    if code == "" then
        return nil, "code d'escadron vide"
    end
    local hashPos = code:find("#", 1, true)
    if hashPos then
        code = code:sub(hashPos + 1)
    end
    code = code:gsub("%s", "")

    local parts = {}
    for _, part in ipairs(split(code, ",")) do
        if part ~= "" and part ~= "undefined" then
            table.insert(parts, part)
        end
    end
    if #parts < 2 then
        return nil, "code incomplet : il faut au moins un leader et un pilote"
    end

    local result = { lang = DEFAULT_LANG, ships = {} }
    local last = parts[#parts]
    if last:match("^%a+$") then
        result.lang = string.upper(last)
        table.remove(parts)
    end

    result.leaderId = tonumber(parts[1])
    if result.leaderId == nil then
        return nil, "identifiant de leader invalide : " .. parts[1]
    end

    for i = 2, #parts do
        local ids = {}
        for _, id in ipairs(split(parts[i], "u")) do
            if id ~= "" and id ~= "undefined" then
                local number = tonumber(id)
                if number == nil then
                    return nil, "identifiant invalide dans « " .. parts[i] .. " »"
                end
                table.insert(ids, number)
            end
        end
        if #ids > 0 then
            local ship = { pilotId = ids[1], upgrades = {} }
            for j = 2, #ids do
                table.insert(ship.upgrades, ids[j])
            end
            table.insert(result.ships, ship)
        end
    end
    if #result.ships == 0 then
        return nil, "aucun pilote dans le code"
    end
    return result
end

---------------------------------------------------------------------------
-- Caractéristiques du vaisseau
---------------------------------------------------------------------------

function UnitedSquad.moveSet(ship)
    local moves = {}
    for row, speeds in ipairs(ship.maneuvers or {}) do
        local speed = row - 1
        for column, value in ipairs(speeds) do
            local colour = UnitedMapping.MANEUVER_COLORS[tonumber(value) or 0]
            local maneuver = UnitedMapping.MANEUVER_COLUMNS[column]
            if colour and maneuver then
                table.insert(moves, colour .. maneuver[1] .. tostring(speed) .. maneuver[2])
            end
        end
    end
    return moves
end

local function actionCodesFrom(entry, into)
    -- entry = { 0, "Fo W" } ou { 1, "Fo W", "Br R" }
    if type(entry) ~= "table" then
        return
    end
    for i = 2, #entry do
        local code = UnitedMapping.ACTIONS[tostring(entry[i]):sub(1, 2)]
        if code and not contains(into, code) then
            table.insert(into, code)
        end
    end
end

function UnitedSquad.actionSet(ship)
    local actions = {}
    for _, entry in ipairs(ship.actions or {}) do
        actionCodesFrom(entry, actions)
    end
    return actions
end

-- Actions ajoutées par une amélioration (champ add_Data)
local function upgradeAddedActions(upgrade, into)
    local addData = upgrade.add_Data
    if type(addData) ~= "table" then
        return
    end
    if addData[1] == "add_action" then
        actionCodesFrom(addData[2], into)
    else
        for _, item in ipairs(addData) do
            if type(item) == "table" and item[1] == "add_action" then
                actionCodesFrom(item[2], into)
            end
        end
    end
end

-- Arcs pour les vaisseaux sans modèle (dérivés du champ "attack")
function UnitedSquad.arcsFromAttack(ship)
    local fixedTypes, range = {}, 0
    local turret = nil
    for _, attack in ipairs(type(ship.attack) == "table" and ship.attack or {}) do
        if type(attack) == "table" then
            local kind = tostring(attack[1])
            local value = tonumber(attack[2]) or 0
            if UnitedMapping.FIXED_ARCS[kind] then
                local arc = UnitedMapping.FIXED_ARCS[kind]
                if not contains(fixedTypes, arc) then
                    table.insert(fixedTypes, arc)
                end
                range = math.max(range, value)
            elseif UnitedMapping.TURRET_ARCS[kind] and turret == nil then
                turret = { main = { name = "primary", type = { UnitedMapping.TURRET_ARCS[kind] } } }
            end
        end
    end
    -- La texture du socle dépend du premier arc fixe : on met l'avant en tête
    table.sort(fixedTypes, function(a, b)
        local order = { front = 1, fullfront = 2, bullseye = 3, back = 4 }
        return (order[a] or 9) < (order[b] or 9)
    end)
    local arcs = {}
    if #fixedTypes > 0 then
        arcs.fixed = { range = math.max(range, 1), type = fixedTypes }
    end
    arcs.turret = turret
    return arcs
end

local function defaultTexture(textures)
    if textures == nil then
        return nil
    end
    if textures.standard then
        return "standard"
    end
    local keys = {}
    for key, _ in pairs(textures) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys[1]
end

---------------------------------------------------------------------------
-- Construction de la liste de spawn
---------------------------------------------------------------------------

local function chassisLines(data, ship, lang)
    local lines = {}
    for _, chassisId in ipairs(ship.chassis or {}) do
        local chassis = data.chassis[tonumber(chassisId)]
        if chassis and tonumber(chassisId) ~= 0 then
            local effects = {}
            for i = 1, 3 do
                local effect = UnitedSquad.cleanText(localized(chassis, "effect" .. i, lang), lang)
                if effect ~= "" then
                    table.insert(effects, effect)
                end
            end
            if #effects > 0 then
                table.insert(lines, table.concat(effects, " "))
            end
        end
    end
    return lines
end

-- Texte affiché dans le panneau d'information du vaisseau
local function buildInfoText(info, lang)
    local fr = lang ~= "ENG"
    local out = {}
    table.insert(out, "<b>" .. info.pilotName .. "</b>")
    table.insert(out, info.shipName .. "  ·  " .. (fr and "Pilotage " or "Skill ") .. tostring(info.skill)
        .. "  ·  " .. tostring(info.points) .. " pts")
    local stats = {}
    if info.attackText ~= "" then
        table.insert(stats, (fr and "Att " or "Atk ") .. info.attackText)
    end
    table.insert(stats, (fr and "Agi " or "Agi ") .. tostring(info.agility))
    table.insert(stats, (fr and "Coque " or "Hull ") .. tostring(info.hull))
    table.insert(stats, (fr and "Boucl. " or "Shld ") .. tostring(info.shields))
    if info.force > 0 then
        table.insert(stats, "Force " .. tostring(info.force))
    end
    if info.charge ~= "" then
        table.insert(stats, info.charge)
    end
    table.insert(out, table.concat(stats, "  ·  "))
    if info.ability ~= "" then
        table.insert(out, "")
        table.insert(out, info.ability)
    end
    for _, line in ipairs(info.chassis) do
        table.insert(out, "")
        table.insert(out, "<i>" .. line .. "</i>")
    end
    if #info.upgrades > 0 then
        table.insert(out, "")
        table.insert(out, fr and "<b>Améliorations</b>" or "<b>Upgrades</b>")
        for _, upgrade in ipairs(info.upgrades) do
            local header = "• <b>" .. upgrade.name .. "</b> (" .. upgrade.slot
            if upgrade.charge ~= "" then
                header = header .. ", " .. upgrade.charge
            end
            header = header .. ")"
            if upgrade.effect ~= "" then
                header = header .. " : " .. upgrade.effect
            end
            table.insert(out, header)
        end
    end
    return table.concat(out, "\n")
end

local function attackText(ship)
    local parts = {}
    for _, attack in ipairs(type(ship.attack) == "table" and ship.attack or {}) do
        if type(attack) == "table" and (tonumber(attack[2]) or 0) > 0 then
            table.insert(parts, tostring(attack[2]) .. " (" .. tostring(attack[1]) .. ")")
        end
    end
    return table.concat(parts, " / ")
end

-- Transforme un code d'escadron en liste prête pour Global.newSpawner.
-- shipDb : la table masterShipDB du mod (modèles 3D, textures, arcs...).
-- Retourne fList, résumé, avertissements  — ou nil, erreur.
function UnitedSquad.build(code, data, shipDb)
    local squad, err = UnitedSquad.parseCode(code)
    if squad == nil then
        return nil, err
    end
    local lang = squad.lang
    local warnings = {}

    local leader = data.leaders[squad.leaderId]
    if leader == nil then
        return nil, "leader inconnu (id " .. tostring(squad.leaderId) .. ")"
    end

    local fList = {
        United = true,
        NoCards = true,
        Pilots = {},
        Upgrades = {},
        Remotes = {},
        Obstacles = {},
        Customization = {},
        SqdExecOptions = {},
        sqdAction = {},
        listCost = 0,
    }

    -- Première passe : résoudre pilotes et vaisseaux, compter les doublons
    local resolved = {}
    local perShipType = {}
    for index, entry in ipairs(squad.ships) do
        local pilot = data.pilots[entry.pilotId]
        if pilot == nil then
            return nil, "pilote inconnu (id " .. tostring(entry.pilotId) .. ")"
        end
        local ship = UnitedData.shipForPilot(data, pilot)
        if ship == nil then
            return nil, "vaisseau introuvable pour le pilote " .. localized(pilot, "name", lang)
        end
        resolved[index] = { entry = entry, pilot = pilot, ship = ship }
        perShipType[ship.name] = (perShipType[ship.name] or 0) + 1
    end

    local tintIndex = 0
    local usedNames = {}
    local factionSkin = nil

    for index, item in ipairs(resolved) do
        local pilot, ship = item.pilot, item.ship
        local skin = UnitedMapping.FACTION_SKIN[pilot.faction] or UnitedMapping.DEFAULT_FACTION_SKIN
        factionSkin = factionSkin or skin

        local modelKey = UnitedMapping.SHIP_MODEL[ship.name]
        local model = modelKey and shipDb and shipDb[modelKey] or nil
        if modelKey and model == nil then
            table.insert(warnings, "modèle « " .. tostring(modelKey) .. " » absent de ShipDb pour " .. ship.name)
        end
        if model == nil then
            table.insert(warnings, ship.name .. " : pas de modèle 3D, socle seul")
        end

        -- Nom unique (TTS identifie les vaisseaux par leur nom)
        local pilotName = localized(pilot, "name", lang)
        usedNames[pilotName] = (usedNames[pilotName] or 0) + 1
        if usedNames[pilotName] > 1 then
            pilotName = pilotName .. " " .. tostring(usedNames[pilotName])
        end

        local tint = NO_TINT
        if perShipType[ship.name] > 1 then
            tintIndex = tintIndex + 1
            tint = TINT_COLORS[((tintIndex - 1) % #TINT_COLORS) + 1]
        end

        local size = string.lower(ship.base or (model and model.size) or "small")
        local pilotCharge, pilotRecurring = chargeValue(pilot.charge)
        local force = tonumber(pilot.force) or 0
        local actions = UnitedSquad.actionSet(ship)
        local arcs
        local mountingPoints
        if model then
            arcs = deepcopy(model.arcs or {})
            mountingPoints = model.mounting_points or { main = { 0, 0 } }
        else
            arcs = UnitedSquad.arcsFromAttack(ship)
            mountingPoints = { main = { 0, 0 } }
        end

        -- Améliorations : pas de cartes, mais charges, Force et actions
        local upgradeInfos = {}
        local extraCharges = {}
        local points = tonumber(pilot.points) or 0
        for _, upgradeId in ipairs(item.entry.upgrades) do
            local upgrade = data.upgrades[upgradeId]
            if upgrade == nil then
                table.insert(warnings, "amélioration inconnue (id " .. tostring(upgradeId) .. ") ignorée")
            else
                local name = localized(upgrade, "name", lang)
                local count, recurring = chargeValue(upgrade.charge)
                if count > 0 then
                    table.insert(extraCharges, { name = name, count = count })
                end
                force = force + (tonumber(upgrade.force) or 0)
                upgradeAddedActions(upgrade, actions)
                table.insert(upgradeInfos, {
                    name = name,
                    slot = tostring(upgrade.slot or ""),
                    charge = chargeLabel(count, recurring, lang),
                    effect = UnitedSquad.cleanText(localized(upgrade, "effect", lang), lang),
                })
            end
        end

        local info = {
            pilotName = pilotName,
            shipName = ship.name,
            skill = tonumber(pilot.skill) or 0,
            points = points,
            attackText = attackText(ship),
            agility = tonumber(ship.agility) or 0,
            hull = tonumber(ship.hull) or 0,
            shields = tonumber(ship.shields) or 0,
            force = force,
            charge = chargeLabel(pilotCharge, pilotRecurring, lang),
            ability = UnitedSquad.cleanText(localized(pilot, "ability", lang), lang),
            chassis = chassisLines(data, ship, lang),
            upgrades = upgradeInfos,
        }

        local textures = model and model.textures or nil
        local maxCharges = pilotCharge
        for _, extra in ipairs(extraCharges) do
            maxCharges = math.max(maxCharges, extra.count)
        end

        local spawnPilot = {
            id = "united-" .. tostring(pilot.id),
            name = pilotName,
            cost = points,
            card = "",
            Ship = modelKey or ("united-" .. tostring(ship.id)),
            Icon = model and modelKey or "",
            peg = model and model.peg or nil,
            Size = size,
            Shield = tonumber(ship.shields) or 0,
            Hull = tonumber(ship.hull) or 0,
            list = "",
            bombD = "s1",
            Docking = model and model.docking or nil,
            Charge = pilotCharge,
            Force = force,
            Energy = 0,
            ExtraCharges = extraCharges,
            SpawnSpacing = math.max(SHIP_SPACING[size] or 4, 1.5 + 0.9 * math.max(maxCharges, 3)),
            dialSkin = DIAL_SKIN_BASE .. (DIAL_SKINS[skin] or DIAL_SKINS.scumandvillainy),
            Data = {
                name = pilotName,
                xws = "united-" .. tostring(pilot.id),
                mesh = model and model.mesh or nil,
                texture = defaultTexture(textures),
                textures = textures,
                limited = (tonumber(pilot.max_per_squad) == 1) and 1 or 0,
                shipId = modelKey or ("united-" .. tostring(ship.id)),
                initiative = tonumber(pilot.skill) or 0,
                moveSet = UnitedSquad.moveSet(ship),
                Config = nil,
                mountingPoints = mountingPoints,
                arcs = arcs,
                actSet = actions,
                executeOptions = {},
                movethrough = false,
                ProximityHider = model and model.proximity_hider or false,
                Faction = skin,
                Size = size,
                points = points,
                half_points = math.floor(points / 2),
                United = {
                    pilotId = pilot.id,
                    shipId = ship.id,
                    faction = pilot.faction,
                    lang = lang,
                    text = buildInfoText(info, lang),
                },
            },
        }
        fList.Pilots[index] = spawnPilot
        fList.Upgrades[index] = {}
        fList.Customization[pilotName] = { tint = tint }
        fList.listCost = fList.listCost + points
    end

    fList.Faction = factionSkin

    local leaderCharge, leaderRecurring = chargeValue(leader.charge)
    local factions = {}
    for _, faction in ipairs(leader.leaderfaction or {}) do
        if faction ~= "" then
            table.insert(factions, (faction:gsub("_", " ")))
        end
    end
    fList.Leader = {
        name = localized(leader, "leadername", lang),
        ability = UnitedSquad.cleanText(localized(leader, "leaderability", lang), lang),
        factions = factions,
        logistic = tonumber(leader.logistic) or 0,
        charge = leaderCharge,
        recurring = leaderRecurring,
        lang = lang,
    }

    return fList, nil, warnings
end

return UnitedSquad
