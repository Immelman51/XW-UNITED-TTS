-- Bundled by luabundle {"rootModuleName":"Extra Assets.a3690e.lua","version":"1.6.0"}
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
__bundle_register("Extra Assets.a3690e.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.Component.Support.Surface")

end)
__bundle_register("Game.Component.Support.Surface", function(require, _LOADED, __bundle_register, __bundle_modules)
local setting = false

function onLoad(save_state)
    if save_state and save_state ~= "" then
        local loadedData = JSON.decode(save_state)
        if loadedData then
            setting = loadedData.setting
        end
    end
    if setting == true then
        surface()
    else
        submerge()
    end
    setupContextMenu()
end

function onSave()
    saveData = {}
    saveData.setting = setting
    return JSON.encode(saveData)
end

function submerge()
    local sPos = self.getPosition()
    sPos.y = -3
    self.setPosition(sPos)
    self.interactable = false
    self.tooltip = false
    self.setLock(true)
end

function surface()
    local sPos = self.getPosition()
    sPos.y = 3
    self.setPosition(sPos)
    self.interactable = true
    self.tooltip = true
    self.setLock(true)
end

function setupContextMenu()
    self.addContextMenuItem("Dump Scripted Items", emptyBag)
    self.addContextMenuItem("Submerge", submerge)
end

function emptyBag()
    local items = self.getObjects()
    local position = self.getPosition()

    position.x = position.x + 10
    position.z = position.z - 15
    local count = 0
    
    for i = #items, 1, -1 do
        local item = items[i]
        if item.lua_script ~= "" then
            count = count + 1
            local spreadPos = {
                x = position.x + math.floor(count / 3) * 3.5,
                y = position.y + 1,
                z = position.z + (count % 3) * 3
            }
            
            self.takeObject({
                position = spreadPos,
                index = i - 1,  -- Adjust index to current position in the array
                smooth = false
            })
        end
    end
end
end)
return __bundle_require("Extra Assets.a3690e.lua")