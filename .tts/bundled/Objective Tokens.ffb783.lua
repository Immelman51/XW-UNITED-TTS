-- Bundled by luabundle {"rootModuleName":"Objective Tokens.ffb783.lua","version":"1.6.0"}
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
__bundle_register("Objective Tokens.ffb783.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Marker.Scenario.ObjectiveBag")

end)
__bundle_register("Marker.Scenario.ObjectiveBag", function(require, _LOADED, __bundle_register, __bundle_modules)
function onLoad()
    self.addContextMenuItem("Place Objective", placeCenterObjective, false)
end

function placeCenterObjective()
    self.takeObject({
        position          = { -20.51, 1.1, 0.00 },
        rotation          = { 180.00, 0.0, 0.00 },
        flip              = false,
        smooth            = true,
        callback_function = function(obj)
            obj.addTag("CenterObjective")
            obj.setLock(true)
        end
    })
end

end)
return __bundle_require("Objective Tokens.ffb783.lua")