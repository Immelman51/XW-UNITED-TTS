-- Bundled by luabundle {"rootModuleName":"dicePreloadGreen.3d63d2.lua","version":"1.6.0"}
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
__bundle_register("dicePreloadGreen.3d63d2.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.Component.Dice.PreloadGreenDie")

end)
__bundle_register("Game.Component.Dice.PreloadGreenDie", function(require, _LOADED, __bundle_register, __bundle_modules)
function onLoad()
    self.interactable = false
    self.tooltip = false
    self.lock()
    self.setPosition({0, -5, 1.5})
    self.setRotation({0, 0, 0})
end
end)
return __bundle_require("dicePreloadGreen.3d63d2.lua")