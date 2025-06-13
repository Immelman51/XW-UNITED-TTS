-- Bundled by luabundle {"rootModuleName":"Target Locks.765252.lua","version":"1.6.0"}
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
__bundle_register("Target Locks.765252.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Token.TargetLockBag")

end)
__bundle_register("Token.TargetLockBag", function(require, _LOADED, __bundle_register, __bundle_modules)
function onLoad(save_state)
    self.addContextMenuItem("Color by player color",
        function(player_color)
            Global.call("API_SetPlayerConfig",
                { player_color = player_color, param_name = "TargetLockColorMode", value = "PlayerColor" })
        end, false)
    self.addContextMenuItem("Color by ship color id",
        function(player_color)
            Global.call("API_SetPlayerConfig",
                { player_color = player_color, param_name = "TargetLockColorMode", value = "ShipColorId" })
        end, false)
    self.addContextMenuItem("Display name off",
        function(player_color)
            Global.call("API_SetPlayerConfig",
                { player_color = player_color, param_name = "TargetLockDisplayName", value = "false" })
        end, false)
    self.addContextMenuItem("Display name on",
        function(player_color)
            Global.call("API_SetPlayerConfig",
                { player_color = player_color, param_name = "TargetLockDisplayName", value = "true" })
        end, false)
end

end)
return __bundle_require("Target Locks.765252.lua")