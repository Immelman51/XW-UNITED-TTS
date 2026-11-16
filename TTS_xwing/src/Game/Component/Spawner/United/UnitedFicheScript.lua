-- X-Wing United : script posé sur chaque fiche (leader, pilote, amélioration).
--
-- La fiche est un bloc TTS standard (BlockSquare) teinté, dont la taille est
-- ajustée au texte, avec le texte affiché dessus en UI XML.
-- Ce module renvoie le script sous forme de texte (setLuaScript).
--
-- Réglages utiles (dans la table "fiche" fournie par UnitedSquad.lua) :
--   widthPx / heightPx : taille du panneau en pixels d'UI
--   k                  : unités de table par pixel d'UI (taille du texte)
--   flip               : true pour retourner le texte de 180°
--   bgColor / textColor / outlineColor / outlineSize : apparence (voir
--   UnitedSquad.STYLE)
--   description        : texte affiché en grand à l'écran par un clic sur la fiche

return [==[
fiche = nil

local THICKNESS = 0.06    -- épaisseur de la fiche (unités de table)

local DEFAULT_BG = "#101418"
local DEFAULT_TEXT = "#FFFFFF"
local DEFAULT_OUTLINE = "#D9A61A"

local function hexToColor(hex)
    hex = string.gsub(hex or DEFAULT_BG, "#", "")
    local r = tonumber(string.sub(hex, 1, 2), 16) or 16
    local g = tonumber(string.sub(hex, 3, 4), 16) or 20
    local b = tonumber(string.sub(hex, 5, 6), 16) or 24
    return { r / 255, g / 255, b / 255 }
end

local function escapeXml(text)
    return (string.gsub(string.gsub(string.gsub(tostring(text), "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- Rangées de pictogrammes sous le texte (caractéristiques, actions) :
-- voir UnitedSquad.iconRows
local function iconRowsXml()
    local out = {}
    local y = fiche.textPx or 0
    for _, row in ipairs(fiche.iconRows or {}) do
        local items = {}
        for _, item in ipairs(row.items or {}) do
            if item.image then
                table.insert(items, string.format(
                    '<Image image="%s" preferredWidth="%d" preferredHeight="%d" preserveAspect="true" '
                    .. 'raycastTarget="false"/>', item.image, item.w, item.h))
            elseif item.text then
                local text = escapeXml(item.text)
                table.insert(items, string.format(
                    '<Text preferredWidth="%d" preferredHeight="%d" fontSize="%d" fontStyle="%s" color="%s" '
                    .. 'alignment="MiddleCenter" raycastTarget="false">%s</Text>',
                    math.floor(#item.text * item.size * 0.62 + 6), row.height, item.size,
                    item.bold and "Bold" or "Normal", item.color or "#FFFFFF", text))
            elseif item.space then
                table.insert(items, string.format('<Panel preferredWidth="%d" preferredHeight="1" '
                    .. 'raycastTarget="false"/>', item.space))
            end
        end
        table.insert(out, string.format(
            '<HorizontalLayout rectAlignment="UpperLeft" offsetXY="14 -%d" width="%d" height="%d" spacing="0" '
            .. 'childAlignment="MiddleLeft" childForceExpandWidth="false" childForceExpandHeight="false" '
            .. 'raycastTarget="false">%s</HorizontalLayout>',
            y, fiche.widthPx - 28, row.height, table.concat(items)))
        y = y + row.height + 8
    end
    return table.concat(out)
end

local function applyFiche()
    if fiche == nil or fiche.unit == nil then
        return
    end
    local unit = fiche.unit
    local width = fiche.widthPx * fiche.k
    local height = fiche.heightPx * fiche.k
    local sx = width / unit[1]
    local sy = THICKNESS / unit[2]
    local sz = height / unit[3]
    self.setScale({ sx, sy, sz })
    local bg = fiche.bgColor or DEFAULT_BG
    local text = fiche.textColor or DEFAULT_TEXT
    local outline = fiche.outlineColor or DEFAULT_OUTLINE
    local outlineSize = fiche.outlineSize or 3
    self.setColorTint(hexToColor(bg))
    -- Pas d'infobulle native : la description s'affiche en grand par un clic
    self.tooltip = false

    -- Fond opaque : le contour est dessiné derrière le panneau et teinterait
    -- toute la fiche à travers un fond transparent.
    -- L'UI suit l'échelle (non uniforme) de l'objet : on la compense pour
    -- que le texte garde ses proportions.
    local ax = 100 * fiche.k / sx
    local ay = 100 * fiche.k / sz
    local z = -(unit[2] * 50 + 1 / sy)
    local rotZ = fiche.flip and 180 or 0

    local xml = string.format(
        '<Panel id="Fiche" width="%d" height="%d" position="0 0 %.3f" rotation="180 180 %d" scale="%.5f %.5f 1" '
        .. 'color="%sFF" outline="%s" outlineSize="%d %d" onClick="ficheClick">'
        .. '<Text id="FicheText" raycastTarget="false" rectAlignment="UpperLeft" alignment="UpperLeft" offsetXY="14 -12" '
        .. 'width="%d" height="%d" fontSize="%d" color="%s" horizontalOverflow="Wrap" '
        .. 'verticalOverflow="Overflow"></Text>%s</Panel>',
        fiche.widthPx, fiche.heightPx, z, rotZ, ax, ay,
        bg, outline, outlineSize, outlineSize,
        fiche.widthPx - 28, fiche.textPx or (fiche.heightPx - 20), fiche.fontSize, text, iconRowsXml())
    self.UI.setXml(xml)
    Wait.frames(function()
        Wait.condition(function()
            self.UI.setValue("FicheText", fiche.text)
        end, function()
            return not self.UI.loading
        end)
    end, 2)
end

-- Clic gauche : description en grand à l'écran du joueur qui a cliqué
-- (un second clic sur la même fiche la referme)
function ficheClick(player, value, id)
    if fiche == nil or player == nil or player.color == nil then
        return
    end
    if value ~= nil and value ~= "-1" then
        return
    end
    local description = fiche.description or ""
    if description == "" then
        return
    end
    Global.call("unitedShowDetail", {
        color = player.color,
        guid = self.getGUID(),
        title = fiche.title or "",
        text = description,
        bgColor = fiche.bgColor,
        textColor = fiche.textColor,
        outlineColor = fiche.outlineColor,
        accentColor = fiche.accentColor,
        rows = fiche.detailRows,
    })
end

-- Appelé par le Spawner une fois l'objet apparu (échelle 1 à ce moment-là)
function setFiche(params)
    fiche = params
    if fiche.unit == nil then
        local size = self.getBoundsNormalized().size
        fiche.unit = { size.x, size.y, size.z }
    end
    self.setName(fiche.title or "")
    -- Gardée pour la recherche / le menu ; l'infobulle native est coupée
    self.setDescription(fiche.description or "")
    applyFiche()
end

function onSave()
    if fiche == nil then
        return ""
    end
    return JSON.encode(fiche)
end

function onLoad(state)
    if state ~= nil and state ~= "" then
        fiche = JSON.decode(state)
        Wait.condition(applyFiche, function() return not self.spawning end)
    end
end
]==]
