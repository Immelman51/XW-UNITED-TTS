-- Bundled by luabundle {"rootModuleName":"Hyperspace marker.36ae82.lua","version":"1.6.0"}
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
__bundle_register("Hyperspace marker.36ae82.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Marker.HyperspaceBag")

end)
__bundle_register("Marker.HyperspaceBag", function(require, _LOADED, __bundle_register, __bundle_modules)
markers = nil
function onLoad()
    self.addContextMenuItem("Setup Aces High", toggleAcesHighSetup, false)
end

function toggleAcesHighSetup()
    if markers == nil then
        markers = {}
        self.takeObject({
            position          = { -15.25, 0.97, -4.90 },
            rotation          = { 0.00, 44.92, 0.00 },
            flip              = false,
            smooth            = false,
            callback_function = function(obj)
                obj.setLock(true)
                table.insert(markers, obj)
            end
        })
        local mark2 = self.takeObject({
            position          = { -32.36, 1.06, -11.83 },
            rotation          = { 0.00, 314.99, 180.00 },
            flip              = false,
            smooth            = false,
            callback_function = function(obj)
                obj.setLock(true)
                table.insert(markers, obj)
            end
        })
        local mark3 = self.takeObject({
            position          = { -25.21, 0.97, 4.80 },
            rotation          = { 0.00, 225.00, 0.00 },
            flip              = false,
            smooth            = false,
            callback_function = function(obj)
                obj = obj.setState(2)
                obj.setLock(true)
                table.insert(markers, obj)
            end
        })
        local mark4 = self.takeObject({
            position          = { -8.73, 1.06, 11.79 },
            rotation          = { 0.00, 134.98, 180.00 },
            flip              = false,
            smooth            = false,
            callback_function = function(obj)
                obj = obj.setState(2)
                obj.setLock(true)
                table.insert(markers, obj)
            end
        })
    else
        for _, marker in pairs(markers) do
            if marker ~= nil then
                marker.destruct()
            end
        end
        markers = nil
    end
end

end)
return __bundle_require("Hyperspace marker.36ae82.lua")