-- Bundled by luabundle {"rootModuleName":"Turn Marker.ad6b64.lua","version":"1.6.0"}
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
__bundle_register("Turn Marker.ad6b64.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.Mechanic.TurnMarker")

end)
__bundle_register("Game.Mechanic.TurnMarker", function(require, _LOADED, __bundle_register, __bundle_modules)
local turnCount = 0

function onDrop()
    turnCount     = turnCount + 1
    local message = "Beginning of Turn " .. turnCount .. "."
    if turnCount > 12 then
        message = message .. " Should you still be playing?"
    end
    printToAll(message, Color.Red)
end

function reset()
    turnCount = 0
end

function onLoad(save_state)
    self.addContextMenuItem("Reset Counter", reset)
    if save_state and save_state ~= "" then
        local loadedData = JSON.decode(save_state)
        if loadedData then
            turnCount = loadedData.turnCount
        end
    end
end

function onSave()
    saveData = {}
    saveData.turnCount = turnCount
    return JSON.encode(saveData)
end

end)
return __bundle_require("Turn Marker.ad6b64.lua")