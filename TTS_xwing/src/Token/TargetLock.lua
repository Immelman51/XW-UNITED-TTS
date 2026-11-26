-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_xwing
--
-- Target lock color and name script
-- ~~~~~~
local Dim = require("Dim")

-- Scripted token properties
__XW_Token = true
__XW_TokenIdle = true
__XW_TokenType = 'targetLock'

-- Was this lock tinted and named already?
set = false

-- Colors for tinting on pickup
colorTable = {}
colorTable['Red'] = { 1, 0, 0 }
colorTable['Brown'] = { 0.6, 0.4, 0 }
colorTable['White'] = { 1, 1, 1 }
colorTable['Pink'] = { 1, 0.4, 0.8 }
colorTable['Purple'] = { 0.8, 0, 0.8 }
colorTable['Blue'] = { 0, 0, 1 }
colorTable['Teal'] = { 0.2, 1, 0.8 }
colorTable['Green'] = { 0, 1, 0 }
colorTable['Yellow'] = { 1, 1, 0 }
colorTable['Orange'] = { 1, 0.4, 0 }
colorTable['Black'] = { 0.2, 0.2, 0.2 }

-- X-Wing United : tous les jetons lock sont bleus ; quand un lock est nommé
-- d'après un vaisseau, un second jeton blanc apparaît à côté. Seul ce jumeau
-- blanc porte le nom (texte noir) ; le jeton bleu reste sans nom affiché.
LOCK_COLOR = colorTable['Blue']
TWIN_COLOR = colorTable['White']
TWIN_TEXT_COLOR = '#000000'
-- Est-ce le jumeau blanc ?
twin = false
-- Écart entre le lock bleu et son jumeau blanc (mm)
TWIN_GAP_MM = 30

--[[
TODO: TargetLocks have an owner and an assigned ship. Perhaps we can handle these behaviors with tags?
]]
-- Save self state
function onSave()
    if set then
        local state = {
            set = set,
            twin = twin,
            text = self.UI.getAttribute("IdLabel", "text"),
        }
        return JSON.encode(state)
    end
end

-- Restore self state
function onLoad(save_state)
    if save_state ~= '' and save_state ~= 'null' and save_state ~= nil then
        local state = JSON.decode(save_state)
        set = state.set
        twin = state.twin or false
        if twin then
            self.UI.setAttribute("IdLabel", "color", TWIN_TEXT_COLOR)
        end
        if state.text then
            self.UI.setAttribute("IdLabel", "text", state.text)
        end
    end
    if not set then
        self.setColorTint(LOCK_COLOR)
    end
end

function onFlip(args)
    if set then
        local player = args.player
        local target = Global.call("getShipTokenIsAssignedTo", { token = self })
            if target then
            printToAll("[" .. Color.fromString(player.color):toHex() .. "]" .. player.steam_name .. " spent " .. self.getName() .. "s target lock on " .. target.getName() .. "[-]")
        else
            printToAll("[" .. Color.fromString(player.color):toHex() .. "]" .. player.steam_name .. " spent " .. self.getName() .. "s target lock[-]")
        end

        self.destruct()
    end
end

function onUpdate()
    if self.resting then
        if self.is_face_down then
            local current = self.getRotation()
            self.setRotationSmooth(vector(0, current.y, 0), false, true)
        end
    end
end

-- Set function for external calls
-- (X-Wing United : la couleur du joueur est ignorée, le lock reste bleu)
function manualSet(arg)
    set = true
    self.setColorTint(LOCK_COLOR)
end

-- Tint on pick up
function onPickedUp()
    if not set then
        self.setColorTint(LOCK_COLOR)
    end
end

-- Set name on drop near a ship or obstacle
function onDropped(player_color)
    local spos = self.getPosition()
    local nearest = nil
    local minDist = Dim.Convert_mm_igu(100)
    for _, object in pairs(getObjectsWithAnyTags({ 'Ship', 'Obstacle' })) do
        local pos = object.getPosition()
        local dist = math.sqrt(math.pow((spos[1] - pos[1]), 2) + math.pow((spos[3] - pos[3]), 2))
        if dist < minDist then
            nearest = object
            minDist = dist
        end
    end

    if not set then
        if nearest ~= nil and nearest.hasTag('Ship') then
            setOwner({ ship = nearest, player = player_color })
        end
    else -- Allready set, now Assign to target
        assignToShip({ ship = nearest })
    end
end

-- Sets the owner of the token. This is the ship responsible for the target
-- lock, and who it is named after. Externally accessible.
function setOwner(args)
    local ship = args.ship
    self.setName(ship.getName())
    printToAll('Target lock named for ' .. ship.getName(), { 0.2, 0.2, 1 })
    self.setColorTint(LOCK_COLOR)
    local displayName = true
    if args.player then
        displayName = Global.call("API_GetPlayerConfig", {
            player_color = args.player,
            param_name =
            "TargetLockDisplayName"
        }) == "true"
    end
    -- X-Wing United : le nom n'est jamais affiché sur le jeton bleu, seulement
    -- sur son jumeau blanc (si l'affichage du nom est activé).
    self.UI.setAttribute("IdLabel", "text", "")
    local text = displayName and getIdText(ship.getName()) or ""
    self.setRotationSmooth(ship.getRotation(), false, true)
    set = true
    spawnTwin(ship, text)
end

-- X-Wing United : crée le jumeau blanc du lock, au même nom.
-- On attend que le lock ait fini de bouger (il peut encore glisser depuis la
-- réserve). Placé à côté du lock, sauf si celui-ci a déjà été assigné à un
-- autre vaisseau (lock automatique de l'IA HotAC) : le jumeau va alors à côté
-- du vaisseau qui a pris le lock.
function spawnTwin(ship, text)
    local name = self.getName()
    local gap = Dim.Convert_mm_igu(TWIN_GAP_MM)
    Wait.condition(function()
        if self == nil or ship == nil then
            return
        end
        local right = ship.getTransformRight()
        local pos
        local assigned = Global.call("getShipTokenIsAssignedTo", { token = self })
        if assigned ~= nil and assigned ~= ship then
            local half = ship.getBoundsNormalized().size.x / 2
            pos = ship.getPosition() + right * (half + gap)
        else
            pos = self.getPosition() + right * gap
        end
        pos.y = pos.y + 0.3
        local twin = self.clone({ position = pos })
        Wait.condition(function()
            twin.call('setAsTwin', { name = name, text = text, rot = ship.getRotation() })
        end, function() return twin ~= nil and not twin.spawning end, 5)
    end, function() return self == nil or not self.isSmoothMoving() end, 5)
end

-- Appelé sur le jumeau blanc juste après sa création. Externally accessible.
function setAsTwin(args)
    set = true
    twin = true
    self.setName(args.name)
    self.setDescription('')
    self.setColorTint(TWIN_COLOR)
    self.UI.setAttribute("IdLabel", "color", TWIN_TEXT_COLOR)
    self.UI.setAttribute("IdLabel", "text", args.text or "")
    if args.rot then
        self.setRotationSmooth(args.rot, false, true)
    end
end

-- Assigns the token to a ship. This is the ship being target locked, and which
-- the token sits beside. Externally accessible
function assignToShip(args)
    local ship = args.ship
    Global.call("API_AssignToken", { token = self, ship = ship })
end

function getIdText(fullName)
    trimmedname = fullName:match '^%s*"(.*%S)"' or fullName
    if #trimmedname < 20 then
        return trimmedname
    end
    initials = trimmedname:sub(1, 1)
    for m in string.gmatch(trimmedname, "%s(%w)") do
        initials = initials .. m
    end
    return initials
end
