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

-- Couleur de socle de chaque vaisseau (une par vaisseau, dans l'ordre de
-- l'escadron ; mêmes valeurs que DataPad.lua).
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

local DIAL_SKIN_BASE = "http://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/dial/skin/1/"
local DIAL_SKINS = {
    rebelalliance = "Rebel.png",
    galacticempire = "Empire.png",
    scumandvillainy = "Scum.png",
    resistance = "Resistance.png",
    firstorder = "FO.png",
    galacticrepublic = "Republic.png",
    separatistalliance = "CIS.png",
    shadowcollective = "Shadow_Collective.png"
}

-- Cadrans propres à chaque faction United (assets/Items/dials3d/<fichier>).
-- Une faction absente de cette table retombe sur le cadran de sa faction
-- d'origine (DIAL_SKINS ci-dessus).
local FACTION_DIAL_BASE = "http://raw.githubusercontent.com/Immelman51/XW-UNITED-TTS/main/assets/Items/dials3d/"
local FACTION_DIALS = {
    Rebel_Alliance           = "rebel_alliance.png",
    Phoenix_Cell             = "phoenix_cell.png",
    Partisans                = "partisans.png",
    Heroes_of_the_Resistance = "heroes_of_the_resistance.png",
    New_Republic_Patrol      = "new_republic_patrol.png",
    Colossus                 = "colossus.png",
    First_Order_Vanguard     = "first_order_vanguard.png",
    First_Order_Specialists  = "first_order_specialists.png",
    Imperial_Remnants        = "imperial_remnants.png",
    Imperial_Academy         = "imperial_academy.png",
    Imperial_Elite_Squadrons = "imperial_elite_squadrons.png",
    ISB                      = "ISB.png",
    Clone_Army               = "clone_army.png",
    Jedi_Order               = "jedi_order.png",
    Naboo_Defense_Force      = "naboo_defense_force.png",
    Trade_Federation         = "trade_federation.png",
    Separatist_Government    = "separatist_government.png",
    Agents_of_Chaos          = "agents_of_chaos.png",
    Hutt_Cartel              = "hutt_cartel.png",
    Bounty_Hunters_Guild     = "bounty_hunters_guild.png",
    Pirates_and_Smugglers    = "pirates_and_smugglers.png",
    Black_Sun                = "black_sun.png",
    Crime_Syndicates         = "crime_syndicates.png",
    Mandalorian_Clans        = "mandalorian_clans.png",
}

local function dialSkinFor(faction, skin)
    local file = FACTION_DIALS[faction]
    if file then
        return FACTION_DIAL_BASE .. file
    end
    return DIAL_SKIN_BASE .. (DIAL_SKINS[skin] or DIAL_SKINS.scumandvillainy)
end

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

-- Fiches posées devant le joueur (voir UnitedFicheScript.lua).
-- widthPx/fontSize/lineHeight : mise en page en pixels d'UI
-- charsPerLine : estimation du nombre de caractères par ligne (hauteur)
-- k : unités de table par pixel (0.011 => fiche de ~5,5 unités de large ;
--     le leader a le sien, voir LEADER_FICHE)
-- flip : true si le texte apparaît à l'envers pour le joueur
UnitedSquad.FICHE = {
    widthPx = 500,
    fontSize = 20,
    lineHeight = 25,
    charsPerLine = 47,
    k = 0.011,
    flip = true,
    titleSize = 32,      -- taille de police du titre des améliorations (nom)
    pilotTitleSize = 43, -- taille de police du titre des pilotes (pilotage + nom)
    shipOutlineSize = 5, -- épaisseur du cadre aux couleurs du socle (pilotes, améliorations)
    tokenRowPx = 80,     -- hauteur réservée aux jetons posés sur la fiche
    statIconPx = 53,     -- pictogrammes des caractéristiques
    statSize = 53,       -- valeurs des caractéristiques
    actionIconPx = 51,   -- pictogrammes des actions
    rowWidthPx = 472,    -- largeur utile des rangées de pictogrammes (widthPx - 28)
}

-- Réglages propres à la fiche du leader (le reste vient de FICHE)
UnitedSquad.LEADER_FICHE = {
    k = 0.014625,
    fontSize = 24,
    lineHeight = 30,
    charsPerLine = 39,
    titleSize = 34,
}

-- Grand panneau affiché par un clic (UI globale)
UnitedSquad.DETAIL = {
    statIconPx = 48,
    statSize = 44,
    actionIconPx = 52,
    rowWidthPx = 930,
    rowSlots = 16,       -- doit correspondre à UNITED_DETAIL_SLOTS (Spawner.lua)
}

-- Couleurs des valeurs de caractéristiques (comme sur les cartes officielles)
UnitedSquad.STAT_COLORS = {
    attack = "#FF5A4D",
    agility = "#6EDB5E",
    hull = "#F5D33D",
    shields = "#5CC8FF",
    force = "#C99BFF",
}

-- Apparence des fiches.
--   bg     : couleur de fond (fiches et bloc)
--   text   : couleur du texte
--   accent : couleur des titres et du contour de la fiche leader
-- Le contour des fiches pilote / amélioration reprend la couleur du socle
-- du vaisseau (voir TINT_COLORS).
-- Palette choisie selon le leader : byLeader[leaderid] en priorité, sinon
-- byFaction[première faction du leader], sinon default.
UnitedSquad.STYLE = {
    outlineSize = 4,
    default = { bg = "#101418", text = "#FFFFFF", accent = "#D9A61A" },
    byLeader = {
        -- [2] = { bg = "#3A1F12", text = "#FCEBD6", accent = "#E07B39" },
    },
    byFaction = {
        -- Rébellion
        Rebel_Alliance           = { bg = "#b92525", text = "#ffffff", accent = "#ff0303" },
        Phoenix_Cell             = { bg = "#b92525", text = "#d3a91e", accent = "#ee6a36" },
        Partisans                = { bg = "#b92525", text = "#4b0d0d", accent = "#ffffff" },
        
        -- Résistance
        Heroes_of_the_Resistance = { bg = "#db7cf8", text = "#FFF1DE", accent = "#da12c9" },
        New_Republic_Patrol      = { bg = "#db7cf8", text = "#520505", accent = "#c00202" },
        Colossus                 = { bg = "#db7cf8", text = "#032b05", accent = "#0ee64e" },

        -- Premier Ordre
        First_Order_Vanguard     = { bg = "#5b0470", text = "#F2F2F2", accent = "#9d06e4" },
        First_Order_Specialists  = { bg = "#5b0470", text = "#face8b", accent = "#ff970f" },
        Imperial_Remnants        = { bg = "#5b0470", text = "#92fa89", accent = "#117704" },

        -- Empire
        Imperial_Academy         = { bg = "#1c5f02", text = "#F0F3F5", accent = "#03cc25" },
        Imperial_Elite_Squadrons = { bg = "#1c5f02", text = "#ca454c", accent = "#5B8BD6" },        
        ISB                      = { bg = "#1c5f02", text = "#f3c4ff", accent = "#6900cc" },

        -- République
        Clone_Army               = { bg = "#11598a", text = "#ffffff", accent = "#04286b" },
        Jedi_Order               = { bg = "#11598a", text = "#e6b6fc", accent = "#d95cff" },
        Naboo_Defense_Force      = { bg = "#11598a", text = "#d6c794", accent = "#ebee4b" },

        -- Separatistes
        Trade_Federation         = { bg = "#803f02", text = "#F2E8DA", accent = "#d47f00" },
        Separatist_Government    = { bg = "#803f02", text = "#a0b2ff", accent = "#2041d3" },       
        Agents_of_Chaos          = { bg = "#803f02", text = "#927d94", accent = "#410047" },

        -- Racailles
        Hutt_Cartel              = { bg = "#fceb00", text = "#ffffff", accent = "#a79c03" },
        Bounty_Hunters_Guild     = { bg = "#f0c82b", text = "#c0ffba", accent = "#60d149" },
        Pirates_and_Smugglers    = { bg = "#f0c82b", text = "#e44f4f", accent = "#ff1616" },
        
        --Shadow Collective
        Black_Sun                = { bg = "#e4f3f3", text = "#000000", accent = "#b8b8b8" },
        Crime_Syndicates         = { bg = "#e4f3f3", text = "#29271a", accent = "#ffe346" },        
        Mandalorian_Clans        = { bg = "#e4f3f3", text = "#1e2b1b", accent = "#399248" },
        
    },
}

function UnitedSquad.styleForLeader(leader)
    local style = UnitedSquad.STYLE
    if leader ~= nil then
        local byId = style.byLeader[tonumber(leader.leaderid)]
        if byId then
            return byId
        end
        for _, faction in ipairs(leader.leaderfaction or {}) do
            if faction ~= "" and style.byFaction[faction] then
                return style.byFaction[faction]
            end
        end
    end
    return style.default
end

-- { r, g, b[, a] } (0..1) -> "#RRGGBB"
function UnitedSquad.colorHex(c)
    local function byte(v)
        return math.max(0, math.min(255, math.floor((tonumber(v) or 0) * 255 + 0.5)))
    end
    return string.format("#%02X%02X%02X", byte(c[1]), byte(c[2]), byte(c[3]))
end

-- Longueur visible (balises exclues), sans motifs Lua (limite de MoonSharp)
local function visibleLength(line)
    local length, pos = 0, 1
    while pos <= #line do
        local open = string.find(line, "<", pos, true)
        if open == nil then
            return length + (#line - pos + 1)
        end
        length = length + (open - pos)
        local close = string.find(line, ">", open, true)
        if close == nil then
            return length + (#line - open + 1)
        end
        pos = close + 1
    end
    return length
end

function UnitedSquad.lineCount(text, charsPerLine)
    local lines, pos = 0, 1
    while pos <= #text + 1 do
        local stop = string.find(text, "\n", pos, true) or (#text + 1)
        local line = string.sub(text, pos, stop - 1)
        lines = lines + math.max(1, math.ceil(visibleLength(line) / charsPerLine))
        pos = stop + 1
    end
    return lines
end

-- Titre en gros caractères (première ligne de la fiche)
function UnitedSquad.ficheTitle(text, color, size)
    local inner = "<b>" .. text .. "</b>"
    if color then
        inner = "<color=" .. color .. ">" .. inner .. "</color>"
    end
    return "<size=" .. (size or UnitedSquad.FICHE.titleSize) .. ">" .. inner .. "</size>"
end

-- Longueurs visibles de chaque ligne du texte
local function lineLengths(text)
    local lengths, pos = {}, 1
    while pos <= #text + 1 do
        local stop = string.find(text, "\n", pos, true) or (#text + 1)
        table.insert(lengths, visibleLength(string.sub(text, pos, stop - 1)))
        pos = stop + 1
    end
    return lengths
end

-- opts : description (texte affiché en grand par un clic), detailRows
--        (rangées de pictogrammes du grand panneau), iconRows (rangées de
--        pictogrammes sous le texte de la fiche), charge, force (jetons
--        posés sur la fiche), owner (nom du vaisseau propriétaire des jetons),
--        style (palette, voir STYLE), outline (couleur du contour, "#RRGGBB"),
--        layout (réglages de police remplaçant ceux de FICHE, voir LEADER_FICHE)
-- La fiche emporte de quoi recalculer sa hauteur si on change sa largeur
-- (lines, charsPerLine, lineHeight, extraPx, baseWidthPx) : voir
-- resizeUnitedFiche dans Spawner.lua, qui n'a pas accès à ce module.
function UnitedSquad.fiche(title, text, opts)
    opts = opts or {}
    local f = {}
    for key, value in pairs(UnitedSquad.FICHE) do
        f[key] = value
    end
    for key, value in pairs(opts.layout or {}) do
        f[key] = value
    end
    local style = opts.style or UnitedSquad.STYLE.default
    local charge = opts.charge or 0
    local force = opts.force or 0
    local lines = lineLengths(text)
    local lineTotal = 0
    for _, length in ipairs(lines) do
        lineTotal = lineTotal + math.max(1, math.ceil(length / f.charsPerLine))
    end
    -- Lignes en plus grande taille (titre)
    local sizeExtra = 0
    local pos = 1
    while pos <= #text do
        local stop = string.find(text, "\n", pos, true) or (#text + 1)
        local size = tonumber(string.match(string.sub(text, pos, math.min(stop, pos + 12)), "^<size=(%d+)>"))
        if size and size > f.fontSize then
            sizeExtra = sizeExtra + (size - f.fontSize) * 1.4
        end
        pos = stop + 1
    end
    local textPx = math.floor(lineTotal * f.lineHeight + sizeExtra + 18)
    local rowsPx = 0
    for _, row in ipairs(opts.iconRows or {}) do
        rowsPx = rowsPx + row.height + 8
    end
    local height = math.floor(textPx + rowsPx + 12)
    -- Rangée de jetons en bas des fiches pilote / leader uniquement ; sur les
    -- améliorations, les jetons se placent à droite sans agrandir la fiche
    if opts.tokenRow and charge + force > 0 then
        height = height + f.tokenRowPx
    end
    return {
        title = title,
        text = text,
        description = opts.description or "",
        detailRows = opts.detailRows,
        iconRows = opts.iconRows,
        textPx = textPx,
        widthPx = f.widthPx,
        heightPx = height,
        fontSize = f.fontSize,
        k = f.k,
        flip = f.flip,
        charge = charge,
        force = force,
        owner = opts.owner or title,
        tokenRow = opts.tokenRow and true or false,
        lines = lines,
        baseWidthPx = f.widthPx,
        charsPerLine = f.charsPerLine,
        lineHeight = f.lineHeight,
        extraPx = height - lineTotal * f.lineHeight,
        bgColor = style.bg,
        textColor = style.text,
        outlineColor = opts.outline or style.accent,
        accentColor = style.accent,
        outlineSize = opts.outlineSize or UnitedSquad.STYLE.outlineSize,
    }
end

-- Rangées de pictogrammes (fiches et grand panneau). Un élément est
--   { image = url, w = px, h = px }  ou  { text = "...", size = n, color = "#..." }
--   ou { space = px }
local function imageUrl(file)
    return UnitedMapping.IMG_BASE .. string.gsub(file, " ", "%%20")
end

-- Caractéristiques : valeurs en couleur, sans libellé ; pictogramme
-- seulement pour le type d'attaque et la Force
local function statItems(info, iconPx, valueSize)
    local c = UnitedSquad.STAT_COLORS
    local items = {}
    local function icon(file)
        table.insert(items, { image = imageUrl(file), w = iconPx, h = iconPx })
        table.insert(items, { space = 4, glue = true })
    end
    local function value(text, color)
        table.insert(items, { text = text, size = valueSize, color = color, bold = true })
        table.insert(items, { space = math.floor(valueSize * 0.7) })
    end
    for _, attack in ipairs(info.attacks) do
        local file = UnitedMapping.ATTACK_IMAGES[attack.kind]
        if file then
            icon(file)
        else
            table.insert(items, { text = UnitedMapping.ATTACK_LABELS[attack.kind] or attack.kind,
                size = math.floor(valueSize * 0.6), color = c.attack, bold = true })
            table.insert(items, { space = 4, glue = true })
        end
        value(tostring(attack.value), c.attack)
    end
    value(tostring(info.agility), c.agility)
    value(tostring(info.hull), c.hull)
    value(tostring(info.shields), c.shields)
    if info.force > 0 then
        icon(UnitedMapping.STAT_IMAGES.force)
        value(tostring(info.force), c.force)
    end
    table.remove(items) -- dernier espace
    return items
end

-- Image d'une action ("Fo W") ; repli sur la version blanche, puis sur du texte
local function actionItem(code, iconPx)
    code = tostring(code)
    code = string.upper(string.sub(code, 1, 1)) .. string.lower(string.sub(code, 2, 2)) .. string.sub(code, 3)
    local images = UnitedMapping.ACTION_IMAGES
    if images[code] then
        return { image = imageUrl(code .. ".png"), w = iconPx, h = iconPx }
    end
    local white = string.sub(code, 1, 2) .. " W"
    if images[white] then
        return { image = imageUrl(white .. ".png"), w = iconPx, h = iconPx }
    end
    return { text = "[" .. code .. "]", size = math.floor(iconPx * 0.5), color = "#FFFFFF" }
end

-- Actions : simples ou liées (action -> flèche -> seconde action)
local function actionItems(entries, iconPx)
    local items = {}
    for index, entry in ipairs(entries) do
        if index > 1 then
            table.insert(items, { space = math.floor(iconPx * 0.7) })
        end
        table.insert(items, actionItem(entry[2], iconPx))
        if tonumber(entry[1]) == 1 and entry[3] ~= nil then
            table.insert(items, { image = imageUrl("fleche.png"), w = math.floor(iconPx / 2), h = iconPx })
            table.insert(items, actionItem(entry[3], iconPx))
        end
    end
    return items
end

-- Largeur estimée d'un élément (même calcul que l'affichage)
local function itemWidth(item)
    if item.image then
        return item.w
    elseif item.space then
        return item.space
    end
    return math.floor(#(item.text or "") * (item.size or 20) * 0.62 + 6)
end

-- Coupe une rangée trop large en plusieurs, aux espaces entre deux groupes
-- (maxItems : nombre d'emplacements d'une rangée du grand panneau)
local function wrapRow(rows, height, items, maxWidth, maxItems)
    local current, width, lastSpace = {}, 0, nil
    local function over(item)
        return width + itemWidth(item) > maxWidth or (maxItems ~= nil and #current >= maxItems)
    end
    for _, item in ipairs(items) do
        if item.space and not item.glue and over(item) then
            -- l'espace tombe en bout de ligne : on passe à la ligne suivante
            table.insert(rows, { height = height, items = current })
            current, width, lastSpace = {}, 0, nil
        elseif not (item.space and not item.glue) and over(item) and lastSpace ~= nil then
            local nextItems = {}
            for i = lastSpace + 1, #current do
                table.insert(nextItems, current[i])
            end
            for i = #current, lastSpace, -1 do
                table.remove(current, i)
            end
            table.insert(rows, { height = height, items = current })
            current, width, lastSpace = nextItems, 0, nil
            for _, kept in ipairs(current) do
                width = width + itemWidth(kept)
            end
            table.insert(current, item)
            width = width + itemWidth(item)
        else
            table.insert(current, item)
            if item.space and not item.glue then
                lastSpace = #current
            end
            width = width + itemWidth(item)
        end
    end
    if #current > 0 then
        table.insert(rows, { height = height, items = current })
    end
end

-- sizes : FICHE (fiche posée sur la table) ou DETAIL (grand panneau)
local function iconRows(info, sizes)
    local rows = {}
    wrapRow(rows, math.max(sizes.statIconPx, sizes.statSize + 6),
        statItems(info, sizes.statIconPx, sizes.statSize), sizes.rowWidthPx, sizes.rowSlots)
    if #info.actionEntries > 0 then
        wrapRow(rows, sizes.actionIconPx, actionItems(info.actionEntries, sizes.actionIconPx), sizes.rowWidthPx,
            sizes.rowSlots)
    end
    return rows
end

-- Fiche du pilote : valeur de pilotage + nom en titre, vaisseau et points,
-- puis pictogrammes (caractéristiques, actions : voir iconRows). Capacités
-- du pilote et du châssis : affichées par un clic (voir pilotDetailText).
-- Les améliorations ont chacune leur fiche, en dessous.
local function buildPilotFicheText(info, lang, style)
    local out = {}
    table.insert(out, UnitedSquad.ficheTitle(tostring(info.skill) .. "  " .. info.pilotName, style.accent,
        UnitedSquad.FICHE.pilotTitleSize))
    table.insert(out, info.shipName .. "  ·  " .. tostring(info.points) .. " pts")
    return table.concat(out, "\n")
end

-- Texte affiché en grand par un clic sur la fiche pilote (caractéristiques
-- et actions sont affichées au-dessus, en pictogrammes)
local function pilotDetailText(info, lang)
    local fr = lang ~= "ENG"
    local out = {}
    table.insert(out, info.shipName .. "  ·  " .. (fr and "Pilotage " or "Skill ") .. tostring(info.skill)
        .. "  ·  " .. tostring(info.points) .. " pts")
    if info.charge ~= "" then
        table.insert(out, info.charge)
    end
    if info.ability ~= "" then
        table.insert(out, "")
        table.insert(out, info.ability)
    end
    for _, line in ipairs(info.chassis) do
        table.insert(out, "")
        table.insert(out, "<i>" .. line .. "</i>")
    end
    return table.concat(out, "\n")
end

-- Texte affiché en grand par un clic sur une fiche d'amélioration
local function upgradeDetailText(upgradeInfo)
    local header = "<i>" .. upgradeInfo.slot .. "</i>"
    if upgradeInfo.charge ~= "" then
        header = header .. "  ·  " .. upgradeInfo.charge
    end
    if upgradeInfo.effect == "" then
        return header
    end
    return header .. "\n\n" .. upgradeInfo.effect
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

-- Attaques { kind = "F", value = 3 } (valeur > 0)
local function attackList(ship)
    local list = {}
    for _, attack in ipairs(type(ship.attack) == "table" and ship.attack or {}) do
        if type(attack) == "table" and (tonumber(attack[2]) or 0) > 0 then
            table.insert(list, { kind = tostring(attack[1]), value = tonumber(attack[2]) })
        end
    end
    return list
end

-- Actions affichées : celles du vaisseau, puis celles ajoutées par les
-- améliorations (sans doublon)
local function displayActions(ship, upgrades)
    local entries, seen = {}, {}
    local function add(entry)
        if type(entry) ~= "table" or entry[2] == nil then
            return
        end
        local key = table.concat({ tostring(entry[1]), tostring(entry[2]), tostring(entry[3] or "") }, "|")
        if not seen[key] then
            seen[key] = true
            table.insert(entries, entry)
        end
    end
    for _, entry in ipairs(ship.actions or {}) do
        add(entry)
    end
    for _, upgrade in ipairs(upgrades) do
        local addData = upgrade.add_Data
        if type(addData) == "table" then
            if addData[1] == "add_action" then
                add(addData[2])
            else
                for _, item in ipairs(addData) do
                    if type(item) == "table" and item[1] == "add_action" then
                        add(item[2])
                    end
                end
            end
        end
    end
    return entries
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
    end

    local style = UnitedSquad.styleForLeader(leader)
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

        -- Chaque vaisseau a sa couleur de socle : elle sert aussi de contour
        -- à ses fiches (pilote + améliorations), pour les associer d'un coup d'œil
        tintIndex = tintIndex + 1
        local tint = TINT_COLORS[((tintIndex - 1) % #TINT_COLORS) + 1]
        local outline = UnitedSquad.colorHex(tint)

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
        local upgradeFiches = {}
        local upgradeRecords = {}
        local points = tonumber(pilot.points) or 0
        for _, upgradeId in ipairs(item.entry.upgrades) do
            local upgrade = data.upgrades[upgradeId]
            if upgrade == nil then
                table.insert(warnings, "amélioration inconnue (id " .. tostring(upgradeId) .. ") ignorée")
            else
                local name = localized(upgrade, "name", lang)
                local count, recurring = chargeValue(upgrade.charge)
                local upgradeForce = tonumber(upgrade.force) or 0
                force = force + upgradeForce
                upgradeAddedActions(upgrade, actions)
                table.insert(upgradeRecords, upgrade)
                local upgradeInfo = {
                    name = name,
                    slot = tostring(upgrade.slot or ""),
                    charge = chargeLabel(count, recurring, lang),
                    effect = UnitedSquad.cleanText(localized(upgrade, "effect", lang), lang),
                }
                table.insert(upgradeInfos, upgradeInfo)
                table.insert(upgradeFiches, UnitedSquad.fiche(name,
                    UnitedSquad.ficheTitle(name) .. "\n<i>" .. upgradeInfo.slot .. "</i>", {
                        description = upgradeDetailText(upgradeInfo),
                        charge = count,
                        force = upgradeForce,
                        owner = pilotName,
                        style = style,
                        outline = outline,
                        outlineSize = UnitedSquad.FICHE.shipOutlineSize,
                    }))
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
            ownForce = tonumber(pilot.force) or 0,
            charge = chargeLabel(pilotCharge, pilotRecurring, lang),
            ability = UnitedSquad.cleanText(localized(pilot, "ability", lang), lang),
            chassis = chassisLines(data, ship, lang),
            upgrades = upgradeInfos,
            attacks = attackList(ship),
            actionEntries = displayActions(ship, upgradeRecords),
        }

        local textures = model and model.textures or nil

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
            -- Charges et Force sont posées sur les fiches, pas près du vaisseau
            Charge = 0,
            Force = 0,
            Energy = 0,
            SpawnSpacing = SHIP_SPACING[size] or 4,
            UnitedFiche = UnitedSquad.fiche(pilotName, buildPilotFicheText(info, lang, style), {
                description = pilotDetailText(info, lang),
                iconRows = iconRows(info, UnitedSquad.FICHE),
                detailRows = iconRows(info, UnitedSquad.DETAIL),
                tokenRow = true,
                charge = pilotCharge,
                force = tonumber(pilot.force) or 0,
                owner = pilotName,
                style = style,
                outline = outline,
                outlineSize = UnitedSquad.FICHE.shipOutlineSize,
            }),
            UnitedUpgradeFiches = upgradeFiches,
            dialSkin = dialSkinFor(pilot.faction, skin),
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
    local fr = lang ~= "ENG"
    local leaderName = localized(leader, "leadername", lang)
    local leaderAbility = UnitedSquad.cleanText(localized(leader, "leaderability", lang), lang)
    local leaderLines = { UnitedSquad.ficheTitle("Leader : " .. leaderName, style.accent,
        UnitedSquad.LEADER_FICHE.titleSize) }
    if #factions > 0 then
        table.insert(leaderLines, (fr and "Factions : " or "Factions: ") .. table.concat(factions, ", "))
    end
    table.insert(leaderLines, (fr and "Logistique : " or "Logistic: ") .. tostring(tonumber(leader.logistic) or 0)
        .. "  ·  " .. (fr and "Total escadron : " or "Squad total: ") .. tostring(fList.listCost) .. " pts")
    if leaderAbility ~= "" then
        table.insert(leaderLines, "")
        table.insert(leaderLines, leaderAbility)
    end
    fList.Leader = {
        name = leaderName,
        charge = leaderCharge,
        lang = lang,
        fiche = UnitedSquad.fiche("Leader : " .. leaderName, table.concat(leaderLines, "\n"), {
            description = leaderAbility,
            layout = UnitedSquad.LEADER_FICHE,
            tokenRow = true,
            charge = leaderCharge,
            owner = leaderName,
            style = style,
        }),
    }

    return fList, nil, warnings
end

return UnitedSquad
