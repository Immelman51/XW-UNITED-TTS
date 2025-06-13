-- Bundled by luabundle {"rootModuleName":"Deck Holder.252512.lua","version":"1.6.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(nil)
__bundle_register("Deck Holder.252512.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.Table.DeckHolder")

end)
__bundle_register("Game.Table.DeckHolder", function(require, _LOADED, __bundle_register, __bundle_modules)
__XW_LayoutHandlers = {
    show = 'Enable',
    hide = 'Disable'
}

state = {
    active = true,
    deck = nil
}

function Enable()
    state.active = true
    function DelayedDrawCoroutine()
        repeat
            coroutine.yield(0)
        until (not self.isSmoothMoving()) and self.resting
        if state.deck then
            SnapDeck(state.deck)
        else
            DrawDeck()
        end
        return 1
    end

    startLuaCoroutine(self, 'DelayedDrawCoroutine')
end

function Disable()
    state.active = false
    if state.deck then
        state.deck.destruct()
    end
    state.deck = nil
    self.clearButtons()
end

function DrawDeck()
    local targetPos = self.getPosition()
    targetPos.y = targetPos.y + 0.3
    local targetRot = self.getRotation()
    targetRot.x = targetRot.x + 180
    local newDeck = deckSource.takeObject({
        position = targetPos,
        rotation = self.getRotation()
    })
    SnapDeck(newDeck)
end

function SnapDeck(deck)
    local sPos = self.getPosition()
    local sRot = self.getRotation()
    deck.setPositionSmooth({ sPos[1], sPos[2] + 0.3, sPos[3] }, false, true)
    deck.setRotationSmooth({ sRot[1] + 180, sRot[2], sRot[3] }, false, true)
    state.deck = deck
    deck.randomize()
end

function onObjectDestroyed(obj)
    if (not state.active) or (not state.deck) then return end
    if state.deck == obj then
        state.deck = nil
    end
end

function onObjectDropped(_, obj)
    if (not state.active) or state.deck then return end
    if obj.tag ~= 'Deck' then return end
    local dx, dy = self.getPosition()[1] - obj.getPosition()[1], self.getPosition()[3] - obj.getPosition()[3]
    if math.abs(dx) < 1 and math.abs(dy) < 1 then
        SnapDeck(obj)
    end
end

function onLoad(saveState)
    deckSource = getObjectFromGUID('b3ae5f') or error('Deck Holder: no deck source found!')
    if saveState and saveState ~= nil then
        local loadState = JSON.decode(saveState)
        state.active = loadState.active
        if loadState.deckGUID then
            state.deck = getObjectFromGUID(loadState.deckGUID)
            state.deck.randomize()
        end
    end
    self.tooltip = false
end

function onSave()
    local sState = { active = state.active }
    if state.deck then
        sState.deckGUID = state.deck.getGUID()
    end
    return JSON.encode(sState)
end

end)
return __bundle_require("Deck Holder.252512.lua")