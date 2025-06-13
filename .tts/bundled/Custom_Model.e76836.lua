-- Bundled by luabundle {"rootModuleName":"Custom Model.e76836.lua","version":"1.6.0"}
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
__bundle_register("Custom Model.e76836.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.Table.ZoneExtension")

end)
__bundle_register("Game.Table.ZoneExtension", function(require, _LOADED, __bundle_register, __bundle_modules)
state = {
    extended = false,
    parent = nil,
    child = nil
}

__XW_LayoutHandlers = { hide = 'DestroyChild' }

scaleConstant = { 0.0272, 0.5, 0.1025 }
extendDistance = 12

function FitToZone(arg)
    function DelayedFit()
        repeat
            coroutine.yield(0)
        until (not arg.zone.isSmoothMoving()) and arg.zone.resting
        local zoneScale = arg.zone.getScale()
        local targetScale = { zoneScale[1] * scaleConstant[1], scaleConstant[2], zoneScale[3] * scaleConstant[3] }
        local targetRot = arg.zone.getRotation()
        targetRot.z = targetRot.z + 180
        local targetPos = arg.zone.getPosition()
        targetPos.y = targetPos.y - 0.5 * zoneScale[2] + 0.15
        self.setRotation(targetRot)
        self.setScale(targetScale)
        self.setPosition(targetPos)
        state.extended = false
        state.parent = arg.zone
        if state.child then
            state.child.destruct()
            state.child = nil
        end
        return 1
    end

    startLuaCoroutine(self, 'DelayedFit')
end

function SpawnChild()
    if not state.parent then return end
    DestroyChild()
    state.child = state.parent.clone()
    local sPos = self.getPosition()
    sPos.y = sPos.y + 1.85
    state.child.setPosition(sPos)
    state.child.setValue(state.parent.getValue())
end

function DestroyChild()
    if state.child then
        state.child.destruct()
        state.child = nil
    end
end

function onLoad(saveState)
    if saveState ~= nil and saveState ~= '' then
        local load = JSON.decode(saveState)
        state.extended = load.extended
        state.parent = getObjectFromGUID(load.parent)
        state.child = getObjectFromGUID(load.child)
    end
    self.interactable = false
    self.tooltip = false
    self.lock()
end

function onSave()
    local save = {}
    save.extended = state.extended
    if state.parent then save.parent = state.parent.getGUID() end
    if state.child then save.child = state.child.getGUID() end
    return JSON.encode(save)
end

function retract()
    if state.extended then
        DestroyChild()
        local targetLocal = { 0, 0, extendDistance / self.getScale()[3] }
        self.setPosition(self.positionToWorld(targetLocal))
        state.extended = false
    end
end

function extend()
    if not state.extended then
        local targetLocal = { 0, 0, -1 * extendDistance / self.getScale()[3] }
        self.setPosition(self.positionToWorld(targetLocal))
        SpawnChild()
        state.extended = true
    end
end

function toggle()
    if state.extended then
        retract()
    else
        extend()
    end
end

end)
return __bundle_require("Custom Model.e76836.lua")