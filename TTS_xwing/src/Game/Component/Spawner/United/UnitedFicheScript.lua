-- X-Wing United : script posé sur chaque fiche (leader ou pilote).
--
-- La fiche est un bloc TTS standard (BlockSquare) teinté en sombre, dont la
-- taille est ajustée au texte, avec le texte affiché dessus en UI XML.
-- Ce module renvoie le script sous forme de texte (setLuaScript).
--
-- Réglages utiles (dans la table "fiche" fournie par UnitedSquad.lua) :
--   widthPx / heightPx : taille du panneau en pixels d'UI
--   k                  : unités de table par pixel d'UI (taille du texte)
--   flip               : true pour retourner le texte de 180°

return [==[
fiche = nil

local THICKNESS = 0.06 -- épaisseur de la fiche (unités de table)

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
    self.setColorTint({ 0.06, 0.08, 0.09 })

    -- L'UI suit l'échelle (non uniforme) de l'objet : on la compense pour
    -- que le texte garde ses proportions.
    local ax = 100 * fiche.k / sx
    local ay = 100 * fiche.k / sz
    local z = -(unit[2] * 50 + 1 / sy)
    local rotZ = fiche.flip and 180 or 0

    local xml = string.format(
        '<Panel id="Fiche" width="%d" height="%d" position="0 0 %.3f" rotation="180 180 %d" scale="%.5f %.5f 1" '
        .. 'color="#101418F2" outline="#D9A61A" outlineSize="3 3">'
        .. '<Text id="FicheText" rectAlignment="UpperLeft" alignment="UpperLeft" offsetXY="14 -12" '
        .. 'width="%d" height="%d" fontSize="%d" color="#FFFFFF" horizontalOverflow="Wrap" '
        .. 'verticalOverflow="Overflow"></Text></Panel>',
        fiche.widthPx, fiche.heightPx, z, rotZ, ax, ay,
        fiche.widthPx - 28, fiche.heightPx - 20, fiche.fontSize)
    self.UI.setXml(xml)
    Wait.frames(function()
        Wait.condition(function()
            self.UI.setValue("FicheText", fiche.text)
        end, function()
            return not self.UI.loading
        end)
    end, 2)
end

-- Appelé par le Spawner une fois l'objet apparu (échelle 1 à ce moment-là)
function setFiche(params)
    fiche = params
    if fiche.unit == nil then
        local size = self.getBoundsNormalized().size
        fiche.unit = { size.x, size.y, size.z }
    end
    self.setName(fiche.title or "")
    -- Infobulle au survol : effet de l'amélioration, capacité du leader...
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
