-- Bundled by luabundle {"rootModuleName":"Critical Hit Tokens.aae8f1.lua","version":"1.6.0"}
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
__bundle_register("Critical Hit Tokens.aae8f1.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Marker.CriticalDamageMarkerBag")

end)
__bundle_register("Marker.CriticalDamageMarkerBag", function(require, _LOADED, __bundle_register, __bundle_modules)
-------------------------------------------------------------
--- Original Script and Art by Joshmoe554---------------------
-------------------------------------------------------------

-- Check if this is a crit token and destroy it.  Nice way to return
-- tokens that have been updated since leaving the container.
function onCollisionEnter(collisionInfo)
    local obj = collisionInfo.collision_object
    local dmgToken = obj.getVar("IsCritToken")

    if dmgToken ~= nil then
        obj.destruct()
    end
end

end)
return __bundle_require("Critical Hit Tokens.aae8f1.lua")