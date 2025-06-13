-- Bundled by luabundle {"rootModuleName":"Layout Controller.b3992e.lua","version":"1.6.0"}
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
__bundle_register("Layout Controller.b3992e.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Layouts.LayoutController")


end)
__bundle_register("Layouts.LayoutController", function(require, _LOADED, __bundle_register, __bundle_modules)
require("TTS_Lib.Util.Math")
require("TTS_Lib.Util.Table")
require("TTS_Lib.Util.String")

local Vect = require("TTS_Lib.Vector.Vector")
local ObjType = require("TTS_Lib.ObjType.ObjType")

ObjType.AddType('dialBag', function(obj) return (obj.tag == 'Infinite') end)

Layout = require("Layouts.LayoutElements")
Layout.layouts = {}

Layout.AddLayout = function(layoutTable)
    table.insert(Layout.layouts, layoutTable)
end

Layout.AddLayout(require("Layouts.Standard"))
Layout.AddLayout(require("Layouts.Epic"))
Layout.AddLayout(require("Layouts.HotAC"))

self.setPosition({ 0, 3, 0 })

state = {
    active = true,
    index = 1,
    dialZones = {},
    tempObjs = {}
}

Layout.AddTempObj = function(obj)
    state.tempObjs[obj.getGUID()] = true
end

Layout.ClearTempObjs = function()
    for guid in pairs(state.tempObjs) do
        local obj = getObjectFromGUID(guid)
        if obj then obj.destruct() end
    end
end

Layout.NearLocal = function(zone, pos)
    local posAdj = Vect.ScaleEach(Vect.Sub(pos, { 0, zone.getPosition()[2], zone.getScale()[3] / 2 }),
        Vect.Inverse(zone.getScale()))
    posAdj[1] = posAdj[1] + 0.5 * math.sgn(posAdj[1])
    return posAdj
end

Layout.NearGlobal = function(zone, pos)
    local posAdj = Vect.ScaleEach(Vect.Sub(pos, { 0, zone.getPosition()[2], zone.getScale()[3] / 2 }),
        Vect.Inverse(zone.getScale()))
    posAdj[1] = posAdj[1] + 0.5 * math.sgn(posAdj[1])
    return zone.positionToWorld(Vect.ScaleEach(posAdj, { -1, 1, 1 }))
end

Layout.extIndex = 1

Layout.required = {}
function onObjectDestroyed(obj)
    if state.active and Layout.required[obj] then
        --broadcastToAll('An object that was part of layout system was destroyed, disabling layouts', {1, 0.4, 0})
        broadcastToAll('You\'re breaking the game, please don\'t', { 1, 0.4, 0 })
        state.active = false
    end
    if state.dialZones[obj.getGUID()] then
        state.dialZones[obj.getGUID()] = nil
        SaveState()
    end
end

Layout.RequireFromGUID = function(guid)
    local obj = (getObjectFromGUID(guid) or error('Layout.RequireFromGUID: object with \'' .. guid .. '\' GUID not found'))
    Layout.required[obj] = true
    return obj
end

Layout.GetTableRef = function()
    local hits = Physics.cast({
        origin = { 0, 0, 0 },
        direction = { 0, -1, 0 },
        type = 3,
        size = { 1, 1, 1 },
        orientation = { 0, 0, 0 },
        debug = false
    })
    for _, hitData in pairs(hits) do
        if hitData.hit_object.type == 'Surface' then
            return hitData.hit_object
        end
    end
    error('Layout.GetTableRef: No surface found')
end


Layout.Hide = function(obj)
    obj.highlightOff()
    obj.lock()
    obj.tooltip = false
    obj.interactable = false
    obj.setPositionSmooth({ 0, -5, 0 }, false, true)
    local handlers = obj.getTable('__XW_LayoutHandlers') or {}
    if handlers.hide then
        obj.call(handlers.hide)
    end
    obj.setScale(Vect.Scale(obj.getScale(), 0.1))
end

Layout.Put = function(obj, data)
    obj.setLock(data.lock ~= false)
    local int = data.int
    if int == nil then int = true end
    obj.interactable = int
    obj.tooltip = int
    obj.setPositionSmooth(data.pos, false, true)
    obj.setRotationSmooth(data.rot, false, true)
    obj.setScale(data.scale)
    if data.set then
        data.set(obj)
    end
    local handlers = obj.getTable('__XW_LayoutHandlers') or {}
    if handlers.show then
        obj.call(handlers.show)
    end
end

Layout.GetMats = function()
    local mats = {}
    for _, obj in pairs(getAllObjects()) do
        if obj.getVar('__XW_Mat') then
            local lay, ID = obj.getVar('__XW_MatLayout'), obj.getVar('__XW_MatID')
            if not mats[lay] then
                mats[lay] = {}
            end
            mats[lay][ID] = obj
        end
    end
    return mats
end

function setLayoutState(index)
    local prev = state.index
    if state.index ~= index then
        Layout.Switch(index)
    end
    return prev
end

function getLayoutState(index)
    return state.index
end

function Layout.Switch(newIndex)
    self.clearButtons()
    if not state.active then
        broadcastToAll('Layout system disabled', { 1, 0.2, 0 })
        return
    end
    --table.print(Layout.layouts)
    local lay = Layout.layouts[newIndex]
    --print('Switch to ' .. lay.name)
    local tabRef = Layout.GetTableRef()
    local cust = tabRef.getCustomObject()
    cust.image = lay.tableImage
    tabRef.setCustomObject(cust)
    tabRef.reload()
    for name, el in pairs(Layout.elements) do
        if lay.elements[name] then
            el.highlightOn({ 0, 0, 1 }, 2)
            Layout.Put(el, lay.elements[name])
        else
            Layout.Hide(el)
        end
    end

    local matData = Layout.GetMats()
    for layout, mats in pairs(matData) do
        if layout ~= lay.name then
            for _, mat in pairs(mats) do
                Layout.Hide(mat)
            end
        else
            for id, mat in pairs(mats) do
                if lay.mats[id] then
                    Layout.Put(mat, lay.mats[id])
                else
                    Layout.Hide(mat)
                end
            end
        end
    end
    Layout.CreateControls(newIndex)
    function setHandsDelayed()
        for _ = 1, 10 do
            coroutine.yield()
        end
        for color, data in pairs(lay.hands) do
            Player[color].setHandTransform({
                position = data.pos,
                rotation = data.rot,
                scale    = data.scale,
            })
        end
        return 1
    end

    self.setTable("elements", Layout.elements)
    startLuaCoroutine(self, 'setHandsDelayed')
    state.index = newIndex
    SaveState()
end

Layout.CreateControls = function(index)
    local lay = Layout.layouts[index]
    for _, button in pairs(lay.controls) do
        self.createButton(button)
    end
end

function onChat(message, player)
    --[[
    if message == 'std' then
        Layout.Switch(1)
    end
    if message == 'ep' then
        Layout.Switch(2)
    end
    --]]
end

function onLoad(saveState)
    local load = JSON.decode(saveState)
    state.active = load.active or state.active
    state.index = load.index
    Layout.FillElements()
    Layout.CreateControls(load.index)
    local sPos = self.getPosition()
    self.setPosition({ sPos[1], 0, sPos[3] })
    self.interactable = false
    self.tooltip = false
    self.lock()

    for _, layoutElement in pairs(getObjectsWithTag('TempLayoutElement')) do
        destroyObject(layoutElement)
    end

    --addContextMenuItem("Standard setup", function() Layout.Switch(1) end, false)
    --addContextMenuItem("Epic setup", function() Layout.Switch(2) end, false)
    --addContextMenuItem("HotAC setup", function() Layout.Switch(3) end, false)
end

function onSave()
    return JSON.encode(state)
end

function SaveState()
    self.script_state = JSON.encode(state)
end

return Layout

end)
__bundle_register("Layouts.HotAC", function(require, _LOADED, __bundle_register, __bundle_modules)
local Vect = require("TTS_Lib.Vector.Vector")

local hotac = {}
do
    hotac.name         = 'HotAC'
    hotac.tableImage   = 'https://github.com/JohnnyCheese/TTS_X-Wing2.0/blob/master/assets/HotAC/Table/table.jpg?raw=true'
    hotac.elements     = {
        ['Damage Decks']           = { pos = { 1.89 + 38, 1.06, -0.06 }, rot = { 0.00, 45.01, 0.00 }, scale = { 1.00, 0.95, 1.00 } },
        ['Huge Ship Damage Decks'] = { pos = { 2.49 + 38, 1.00, -1.95 }, rot = { 0.00, 45.01, 0.00 }, scale = { 0.44, 0.42, 0.44 } },
        ['Tractor Beam']           = { pos = { -1.36 + 38, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Reinforce']              = { pos = { 1.36 + 38, 1.06, -9.56 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Calculate']              = { pos = { -1.28 + 38, 1.06, -9.53 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Ion']                    = { pos = { -1.40 + 38, 1.07, 8.12 }, rot = { 0.00, 180.03, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Stress']                 = { pos = { -1.39 + 38, 1.07, 10.20 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Deplete']                = { pos = { 1.45 + 38, 1.07, 5.87 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Strain']                 = { pos = { 1.43 + 38, 1.07, 10.16 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Evade']                  = { pos = { 1.40 + 38, 1.06, -7.02 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['X-Wing Attack Die']      = { pos = { 0.00 + 38, 1.08, -1.67 }, rot = { 0.00, 90.00, 90.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['X-Wing Defense Die']     = { pos = { 0.00 + 38, 1.08, 1.53 }, rot = { 90.00, 90.00, 0.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['Attack Dice changer']    = { pos = { 0.03 + 38, 1.01, -1.72 }, rot = { 0.00, 315.55, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Defence Dice changer']   = { pos = { -0.03 + 38, 1.01, 1.49 }, rot = { 0.00, 137.13, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Target Locks']           = { pos = { -1.93 + 38, 1.06, -0.06 }, rot = { 0.00, 180.00, 180.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Focus']                  = { pos = { -1.32 + 38, 1.06, -7.07 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Shield']                 = { pos = { 1.46 + 38, 1.06, 3.81 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Energy']                 = { pos = { 2.91 + 38, 1.01, 1.60 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 0.38, 0.38 } },
        ['Force']                  = { pos = { -1.44 + 38, 1.06, 6.01 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Charge']                 = { pos = { -1.45 + 38, 1.06, 3.81 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Critical Hit']           = { pos = { 1.43 + 38, 1.07, 8.12 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.84, 1.08, 0.84 } },
        ['Cloak']                  = { pos = { 1.36 + 38, 1.07, -4.37 }, rot = { 0.00, 270.00, 0.00 }, scale = { 1.00, 1.00, 1.00 } },
        ['Fuse']                   = { pos = { -1.31 + 38, 1.05, -4.36 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.93, 0.93, 0.93 } },
        ['Disarm']                 = { pos = { 1.34 + 38, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Jam']                    = { pos = { -0.14 + 38, 1.06, -14.66 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['All mines tokens']       = { pos = { 1.36 + 38, 0.96, 12.54 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.30, 0.92, 0.30 } },
        ['Bomb drop tokens']       = { pos = { 0.02 + 38, 1.05, 14.70 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.93, 1.19, 0.93 } },
        ['All bomb tokens']        = { pos = { -1.35 + 38, 0.96, 12.53 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.57, 0.83, 0.57 } },
        ['Remotes']                = { pos = { -2.39 + 38, 1.06, 15.55 }, rot = { 0.00, 270.00, 0.00 }, scale = { 0.95, 1.71, 0.95 } },
        ['Spare parts']            = { pos = { 2.35 + 38, 1.03, 15.59 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.80, 1.42, 0.80 } },
        ['1 Straight Templates']   = { pos = { -39.00, 0.96, -2.25 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Straight Templates']   = { pos = { -41.00, 0.96, -3.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Straight Templates']   = { pos = { -39.00, 0.96, 0.80 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['4 Straight Templates']   = { pos = { -41.00, 0.96, 1.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['5 Straight Templates']   = { pos = { -40.00, 0.96, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Bank Templates']       = { pos = { -39.50, 1.05, -7.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Bank Templates']       = { pos = { -40.12, 1.05, -8.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Bank Templates']       = { pos = { -40.75, 1.05, -9.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Turn Templates']       = { pos = { -39.20, 0.96, 7.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Turn Templates']       = { pos = { -39.70, 1.00, 8.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Turn Templates']       = { pos = { -40.20, 0.96, 9.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['Core Set Asteroids']     = { pos = { -46.10, 0.99, -7.09 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.70, 0.53, 0.70 } },
        ['TFA Set Asteroids']      = { pos = { -45.97, 0.97, -4.02 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 1.65, 0.38 } },
        ['Debris Fields']          = { pos = { -46.24, -0.27, -0.32 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.50, 1.90, 0.50 } },
        ['Gas Clouds']             = { pos = { -46.23, 0.96, 4.25 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.64, 1.14, 0.64 } },
        ['POM Set Obstacles']      = { pos = { -46.21, 0.97, 8.74 }, rot = { 0.00, 0.00, 0.00 }, scale = { 2.42, 1.14, 2.42 } },
        ['Range 1 Rulers']         = { pos = { -42.00, 1.00, -4.10 }, rot = { 0.00, 269.99, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-2 Rulers']       = { pos = { -42.00, 1.00, 2.40 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-3 Rulers']       = { pos = { -41.00, 1.00, 0.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-5 Rulers']       = { pos = { -43.00, 1.00, 0.00 }, rot = { 0.00, 0.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Deck Holder 1']          = { pos = { -38.50, 0.90, -14.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Deck Holder 2']          = { pos = { -38.50, 0.90, 14.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Mine Rules']             = { pos = { 50.00, 1.00, 34.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Emplacement Rules 1']    = { pos = { 50.00, 1.00, 23.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Emplacement Rules 2']    = { pos = { 50.00, 1.00, 12.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Emplacement Rules 3']    = { pos = { 50.00, 1.00, 1.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Other Rules']            = { pos = { 50.00, 1.00, -9.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Obstacle Rules']         = { pos = { 50.00, 1.00, -20.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.58, 1.00, 3.58 } },
        ['Turn Tracker']           = { pos = { -2.00, 0.96, 27.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.655, 1.00, 0.80 } },
        ['Turn Marker']            = { pos = { -41.50, 1.12, 27.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.67, 1.00, 0.67 } },
        ['End Marker']             = { pos = { 37.00, 1.00, 27.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.97, 1.00, 0.97 } },
        ['Zone Extension 1']       = { pos = { -49.00, 0.65, 56.00 }, rot = { 0.00, 0.00, 180.00 }, scale = { 1.89, 0.5, 4.0 }, int = false },
        ['Zone Extension 2']       = { pos = { 20.25, 0.65, 56.00 }, rot = { 0.00, 0.00, 180.00 }, scale = { 1.89, 0.5, 4.0 }, int = false },
        ['Zone Extension 3']       = { pos = { -49.00, 0.65, -42.50 }, rot = { 0.00, 0.00, 180.00 }, scale = { 1.89, 0.5, 1.23 }, int = false },
        ['Zone Extension 4']       = { pos = { 20.25, 0.65, -42.50 }, rot = { 0.00, 0.00, 180.00 }, scale = { 1.89, 0.5, 1.23 }, int = false },
        ['Imp AI Sheet Bag']       = { pos = { 42.00, 0.78, 35.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 1.0, 1.0, 1.0 } },
        ['Rebel AI Sheet Bag']     = { pos = { 42.00, 0.78, 27.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 1.0, 1.0, 1.0 } },
        ['Scum AI Sheet Bag']      = { pos = { 42.00, 0.78, 19.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 1.0, 1.0, 1.0 } },
        ['Board Edge L']           = { pos = { -19.55, 0.8, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge R']           = { pos = { 13.55, 0.8, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge T']           = { pos = { -3.00, 0.8, 16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },
        ['Board Edge B']           = { pos = { -3.00, 0.8, -16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },
        ['IN 1']                   = { pos = { 42.50, 1.0, -15.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 2']                   = { pos = { 42.50, 1.0, -13.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 3']                   = { pos = { 42.50, 1.0, -11.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 4']                   = { pos = { 42.50, 1.0, -9.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 5']                   = { pos = { 42.50, 1.0, -7.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 6']                   = { pos = { 42.50, 1.0, -5.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['IN 7']                   = { pos = { 42.50, 1.0, -3.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Player 1 Seat']          = { pos = { -42.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
        ['Player 2 Seat']          = { pos = { -25.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
        ['Player 3 Seat']          = { pos = { -8.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
        ['Player 4 Seat']          = { pos = { 8.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
        ['Player 5 Seat']          = { pos = { 25.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
        ['Player 6 Seat']          = { pos = { 42.50, 0.97, -39.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.00, 1.00, 5.00 } },
    }
    local zonePos      = { 5, 2.5, 32 }
    local zoneScale    = { 100, 4, 12 }
    local assignOffset = { -5, 1, 2 }
    local stuffCenter  = { 0, 0, 18.5 }
    local stuffSize    = { 108, 1, 37 }
    local function opposite(data)
        return Vect.ScaleEach(data, { 1, 1, -1 })
    end
    local function left(data)
        return Vect.ScaleEach(data, { -1, 1, 1 })
    end
    hotac.hands = {
        ['Purple'] = { pos = { 42.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Green']  = { pos = { 8.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Orange'] = { pos = { -25.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Teal']   = { pos = { 80.00, 5.00, -15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Red']    = { pos = { -42.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Blue']   = { pos = { 25.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Yellow'] = { pos = { -8.50, 5.00, -50.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['Brown']  = { pos = { 80.00, 5.00, 15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Pink']   = { pos = { 80.00, 5.00, 5.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['White']  = { pos = { 80.00, 5.00, -5.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
    }
    hotac.mats = {
        ['Main'] = { pos = { -3.00, 1, 0.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.63, 1.20, 1.63 }, int = false },
    }
    function HotacChangeMat()
        local mat = Layout.GetMats()[hotac.name].Main
        mat.call('NextImage')
    end

    function HotacChangeMatPrev()
        local mat = Layout.GetMats()[hotac.name].Main
        mat.call('PrevImage')
    end

    function HotacToggleRulers()
        local mat = Layout.GetMats()[hotac.name].Main
        mat.call('ToggleRulers')
    end

    function StandardLayout()
        Layout.Switch(1)
    end

    local bWidth = 2200
    local bHeight = 500
    local bFontSize = 230
    hotac.controls = {
        {
            position = { 50.5, 1, 2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'HotacChangeMat',
            label = 'NEXT PLAYMAT'
        },
        {
            position = { 50.5, 1, -2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'HotacChangeMatPrev',
            label = 'PREV PLAYMAT'
        },
        {
            position = { 49, 1, 0 },
            rotation = { 0, 90, 0 },
            click_function = 'HotacToggleRulers',
            label = 'TOGGLE RULERS'
        },
        {
            position = { 80, 1, -35 },
            rotation = { 0, 180, 0 },
            click_function = 'StandardLayout',
            label = 'STANDARD MODE'
        },
    }


    for _, button in ipairs(hotac.controls) do
        button.width = bWidth
        button.height = bHeight
        button.font_size = bFontSize
        button.function_owner = self
    end
end

return hotac

end)
__bundle_register("TTS_Lib.Vector.Vector", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_lib
--
-- Library for all vector-related operations
-- Description and usage in README.md in this lib folder in repository
-- ~~~~~~

-- TODO: Many of these now have TTS equivalents.
-- TODO: e.g. Vector.__add(vec1, vec2)

local Vect = {}

require("TTS_Lib.Util.Math")

-- Sum of two vectors (of any size)
Vect.Sum = function(vec1, vec2)
    assert(type(vec1) == 'table', 'Vect.Sum: arg#1 not a table!')
    assert(type(vec2) == 'table', 'Vect.Sum: arg#2 not a table!')
    local out = {}
    local k = 1
    while vec1[k] ~= nil and vec2[k] ~= nil do
        out[k] = vec1[k] + vec2[k]
        k = k + 1
    end
    return out
end

-- Inverse of a vector
Vect.Inverse = function(vector)
    assert(type(vector) == 'table', 'Vect.Inverse: arg#1 not a table!')
    local out = {}
    local k = 1
    while vector[k] ~= nil do
        out[k] = 1 / vector[k]
        k = k + 1
    end
    return out
end

-- Multiply each element of a vector by a factor
Vect.Scale = function(vector, factor)
    assert(type(vector) == 'table', 'Vect.Scale: arg#1 not a table!')
    assert(type(factor) == 'number', 'Vect.Scale: arg#2 not a number!')
    local out = {}
    local k = 1
    while vector[k] ~= nil do
        out[k] = vector[k] * factor
        k = k + 1
    end
    return out
end

-- Multiply each element of a vector by an element from factor vector
-- (element-wise vector multiplication)
Vect.ScaleEach = function(vector, factorVec)
    assert(type(vector) == 'table', 'Vect.ScaleEach: arg#1 not a table!')
    assert(type(factorVec) == 'table', 'Vect.ScaleEach: arg#2 not a table!')
    local out = {}
    local k = 1
    while vector[k] ~= nil and factorVec[k] ~= nil do
        out[k] = vector[k] * factorVec[k]
        k = k + 1
    end
    return out
end


-- Length of  vector on X-Z plane (ignoring height)
Vect.Length = function(vector)
    assert(type(vector) == 'table', 'Vect.Length: arg#1 not a table!')
    return math.sqrt(vector[1] * vector[1] + vector[3] * vector[3])
end

-- Rotation of a 3D vector over its second element axis, arg in radians
-- Elements past 3rd are copied
Vect.RotateRad = function(vector, radRotation)
    assert(type(vector) == 'table', 'Vect.RotateRad: arg#1 not a table!')
    assert(type(radRotation) == 'number', 'Vect.RotateRad: arg#2 not a number!')
    local newX = math.cos(radRotation) * vector[1] + math.sin(radRotation) * vector[3]
    local newZ = math.sin(radRotation) * vector[1] * -1 + math.cos(radRotation) * vector[3]
    local out = { newX, vector[2], newZ }
    local k = 4
    while vector[k] ~= nil do
        table.insert(out, vector[k])
        k = k + 1
    end
    return out
end

-- Distance between two points
-- Points as vectors or objects (their positions)
Vect.Distance = function(pos1, pos2)
    assert(type(pos1) == 'table' or type(pos1) == 'userdata', 'Vect.Distance: arg#1 not a table/object!')
    assert(type(pos2) == 'table' or type(pos2) == 'userdata', 'Vect.Distance: arg#2 not a table/object!')
    if type(pos1) == 'userdata' then
        pos1 = pos1.getPosition()
    end
    if type(pos2) == 'userdata' then
        pos2 = pos2.getPosition()
    end
    return Vect.Length(Vect.Between(pos1, pos2))
end

-- Print vector elements
Vect.Print = function(vec, name)
    assert(type(vec) == 'table', 'Vect.Print: arg#1 not a table!')
    local out = '['
    if name then
        out = name .. ' => ' .. out
    end
    local k = 1
    while vec[k] ~= nil do
        out = out .. math.round(vec[k], 3) .. ' : '
        k = k + 1
    end
    out = out:sub(1, -3) .. ']'
    print(out)
end

-- Dot product
Vect.DotProd = function(vec1, vec2)
    assert(type(vec1) == 'table', 'Vect.DotProd: arg#1 not a table!')
    assert(type(vec2) == 'table', 'Vect.DotProd: arg#2 not a table!')
    local sum = 0
    local k = 1
    while vec1[k] ~= nil and vec2[k] ~= nil do
        sum = sum + vec1[k] * vec2[k]
        k = k + 1
    end
    return sum
end

-- Element-by-element comparison
-- Fails if length uneven
Vect.Compare = function(vec1, vec2)
    assert(type(vec1) == 'table', 'Vect.Compare: arg#1 not a table!')
    assert(type(vec2) == 'table', 'Vect.Compare: arg#2 not a table!')
    if #vec1 ~= #vec2 then
        return false
    end
    local k = 1
    while vec1[k] ~= nil and vec2[k] ~= nil do
        if vec1[k] ~= vec2[k] then
            return false
        end
        k = k + 1
    end
    return true
end

-- Euclidean norm
Vect.Norm = function(vec)
    local selfDot = Vect.DotProd(vec, vec)
    return math.sqrt(selfDot)
end

-- Convert a vector to unit vector in the same direction
-- Return zero vector for zero vector
Vect.ToUnit = function(vec)
    if Vect.Norm(vec) == 0 then
        return vec
    end
    return Vect.Scale(vec, 1 / Vect.Norm(vec))
end

-- Angle between vectors in radians
-- If second argument not provided, calculate typical angle (from [1, 0, 0, ...] )
Vect.Angle = function(vec1, vec2)
    if vec2 == nil then
        vec2 = { 1 }
        for k = 2, #vec1, 1 do
            table.insert(vec2, 0)
        end
    end
    return math.acos(Vect.DotProd(vec1, vec2) / (Vect.Norm(vec1) * Vect.Norm(vec2)))
end

-- Angle between vectors in radians, in plane
-- If second argument not provided, calculate typical angle (from [1, 0, 0, ...] )
Vect.Angle2D = function(vec1, vec2)
    if vec2 == nil then
        vec2 = { 1 }
        for k = 2, #vec1, 1 do
            table.insert(vec2, 0)
        end
    end
    return (math.atan2(vec2[3], vec2[1]) - math.atan2(vec1[3], vec1[1]))
end

-- Same as Vect.Angle but in degrees
Vect.AngleDeg = function(vec1, vec2)
    return math.deg(Vect.Angle(vec1, vec2))
end

-- Same as Vect.Angle2D but in degrees
Vect.AngleDeg2D = function(vec1, vec2)
    return math.deg(Vect.Angle2D(vec1, vec2))
end

-- Vector pointing from one position to another
Vect.Between = function(fromVec, toVec)
    return Vect.Sum(toVec, Vect.Scale(fromVec, -1))
end

-- Vector pointing between two points
Vect.Middle = function(p1, p2)
    return Vect.Sum(p1, Vect.Scale(Vect.Between(p1, p2), 0.5))
end

-- Subtract vector from another
Vect.Sub = function(vec1, vec2)
    return Vect.Sum(vec1, Vect.Scale(vec2, -1))
end

-- Opposite of a vector
Vect.Opposite = function(vector)
    return Vect.Scale(vector, -1)
end

-- Rotation of a 3D vector over its second element axis, arg in degrees
-- Elements past 3rd are copied
Vect.RotateDeg = function(vector, degRotation)
    local radRotation = math.rad(degRotation)
    return Vect.RotateRad(vector, radRotation)
end

-- Scale the vector to have set length
-- Negative "length" - opposite of set length
Vect.SetLength = function(vector, len)
    return Vect.Scale(vector, len / Vect.Length(vector))
end

return Vect

end)
__bundle_register("TTS_Lib.Util.Math", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Round to decPlaces decimal places
-- if decPlaces nil round to nearest integer
if not math.round then
    math.round = function(arg, decPlaces)
        decPlaces = decPlaces or 0
        if decPlaces == 0 then
            return math.floor(arg + 0.5)
        end
        local mult = 10 ^ decPlaces
        return math.floor(arg * mult + 0.5) / mult
    end
end

-- Return value limited by min and max bounds
if not math.clamp then
    math.clamp = function(var, min, max)
        return (var < min and min) or (var > max and max) or var
    end
end

-- Sign function, zero for zero
if not math.sgn then
    math.sgn = function(arg)
        return arg < 0 and -1 or arg > 0 and 1 or 0
    end
end

return math

end)
__bundle_register("Layouts.Epic", function(require, _LOADED, __bundle_register, __bundle_modules)
local Vect = require("TTS_Lib.Vector.Vector")

local epic = {}
do
    epic.name          = 'Epic'
    epic.tableImage    = 'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/textures/tableEpic.jpg'
    epic.elements      = {
        ['Damage Decks']           = { pos = { 1.89 + 38, 1.06, -0.06 }, rot = { 0.00, 45.01, 0.00 }, scale = { 1.00, 0.95, 1.00 } },
        ['Huge Ship Damage Decks'] = { pos = { 2.49 + 38, 1.00, -1.95 }, rot = { 0.00, 45.01, 0.00 }, scale = { 0.44, 0.42, 0.44 } },
        ['Tractor Beam']           = { pos = { -1.36 + 38, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Reinforce']              = { pos = { 1.36 + 38, 1.06, -9.56 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Calculate']              = { pos = { -1.28 + 38, 1.06, -9.53 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Ion']                    = { pos = { -1.40 + 38, 1.07, 8.12 }, rot = { 0.00, 180.03, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Stress']                 = { pos = { -1.39 + 38, 1.07, 10.20 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Deplete']                = { pos = { 1.45 + 38, 1.07, 5.87 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Strain']                 = { pos = { 1.43 + 38, 1.07, 10.16 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Evade']                  = { pos = { 1.40 + 38, 1.06, -7.02 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['X-Wing Attack Die']      = { pos = { 0.00 + 38, 1.08, -1.67 }, rot = { 0.00, 90.00, 90.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['X-Wing Defense Die']     = { pos = { 0.00 + 38, 1.08, 1.53 }, rot = { 90.00, 90.00, 0.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['Attack Dice changer']    = { pos = { 0.03 + 38, 1.01, -1.72 }, rot = { 0.00, 315.55, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Defence Dice changer']   = { pos = { -0.03 + 38, 1.01, 1.49 }, rot = { 0.00, 137.13, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Target Locks']           = { pos = { -1.93 + 38, 1.06, -0.06 }, rot = { 0.00, 180.00, 180.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Focus']                  = { pos = { -1.32 + 38, 1.06, -7.07 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Shield']                 = { pos = { 1.46 + 38, 1.06, 3.81 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Energy']                 = { pos = { 2.91 + 38, 1.01, 1.60 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 0.38, 0.38 } },
        ['Force']                  = { pos = { -1.44 + 38, 1.06, 6.01 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Charge']                 = { pos = { -1.45 + 38, 1.06, 3.81 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Critical Hit']           = { pos = { 1.43 + 38, 1.07, 8.12 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.84, 1.08, 0.84 } },
        ['Cloak']                  = { pos = { 1.36 + 38, 1.07, -4.37 }, rot = { 0.00, 270.00, 0.00 }, scale = { 1.00, 1.00, 1.00 } },
        ['Fuse']                   = { pos = { -1.31 + 38, 1.05, -4.36 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.93, 0.93, 0.93 } },
        ['Disarm']                 = { pos = { 1.34 + 38, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Jam']                    = { pos = { -0.14 + 38, 1.06, -14.66 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['All mines tokens']       = { pos = { 1.36 + 38, 0.96, 12.54 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.30, 0.92, 0.30 } },
        ['Bomb drop tokens']       = { pos = { 0.02 + 38, 1.05, 14.70 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.93, 1.19, 0.93 } },
        ['All bomb tokens']        = { pos = { -1.35 + 38, 0.96, 12.53 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.57, 0.83, 0.57 } },
        ['Remotes']                = { pos = { -2.39 + 38, 1.06, 15.55 }, rot = { 0.00, 270.00, 0.00 }, scale = { 0.95, 1.71, 0.95 } },
        ['Spare parts']            = { pos = { 2.35 + 38, 1.03, 15.59 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.80, 1.42, 0.80 } },
        ['1 Straight Templates']   = { pos = { -39.00, 0.96, -2.25 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Straight Templates']   = { pos = { -41.00, 0.96, -3.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Straight Templates']   = { pos = { -39.00, 0.96, 0.80 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['4 Straight Templates']   = { pos = { -41.00, 0.96, 1.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['5 Straight Templates']   = { pos = { -40.00, 0.96, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Bank Templates']       = { pos = { -39.50, 1.05, -7.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Bank Templates']       = { pos = { -40.12, 1.05, -8.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Bank Templates']       = { pos = { -40.75, 1.05, -9.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Turn Templates']       = { pos = { -39.20, 0.96, 7.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Turn Templates']       = { pos = { -39.70, 1.00, 8.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Turn Templates']       = { pos = { -40.20, 0.96, 9.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['Core Set Asteroids']     = { pos = { -46.10, 0.99, -7.09 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.70, 0.53, 0.70 } },
        ['TFA Set Asteroids']      = { pos = { -45.97, 0.97, -4.02 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 1.65, 0.38 } },
        ['Debris Fields']          = { pos = { -46.24, -0.27, -0.32 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.50, 1.90, 0.50 } },
        ['Gas Clouds']             = { pos = { -46.23, 0.96, 4.25 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.64, 1.14, 0.64 } },
        ['POM Set Obstacles']      = { pos = { -46.21, 0.97, 8.74 }, rot = { 0.00, 0.00, 0.00 }, scale = { 2.42, 1.14, 2.42 } },
        ['Range 1 Rulers']         = { pos = { -42.00, 1.00, -4.10 }, rot = { 0.00, 269.99, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-2 Rulers']       = { pos = { -42.00, 1.00, 2.40 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-3 Rulers']       = { pos = { -41.00, 1.00, 0.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-5 Rulers']       = { pos = { -43.00, 1.00, 0.00 }, rot = { 0.00, 0.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Deck Holder 1']          = { pos = { -38.50, 0.90, -14.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Deck Holder 2']          = { pos = { -38.50, 0.90, 14.50 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Board Edge L']           = { pos = { -37.07, 0.8, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge R']           = { pos = { 31.06, 0.80, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge T']           = { pos = { -3, 0.8, 16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 34.00 }, int = false },
        ['Board Edge B']           = { pos = { -3, 0.8, -16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 34.00 }, int = false },
    }
    local zonePos      = { 5, 2.5, 32 }
    local zoneScale    = { 100, 4, 12 }
    local assignOffset = { -5, 1, 2 }
    local stuffCenter  = { 0, 0, 18.5 }
    local stuffSize    = { 108, 1, 37 }
    local function opposite(data)
        return Vect.ScaleEach(data, { 1, 1, -1 })
    end
    local function left(data)
        return Vect.ScaleEach(data, { -1, 1, 1 })
    end
    epic.hands = {
        ['Purple'] = { pos = { -48.00, 5.00, -15.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Green']  = { pos = { -52.00, 5.00, -5.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Orange'] = { pos = { -48.00, 5.00, 5.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Teal']   = { pos = { 52.00, 5.00, -15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Red']    = { pos = { 0.00, 5.00, -40.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Blue']   = { pos = { 0.00, 5.00, 40.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Yellow'] = { pos = { -52.00, 5.00, 15.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['Brown']  = { pos = { 48.00, 5.00, 15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Pink']   = { pos = { 52.00, 5.00, 5.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['White']  = { pos = { 48.00, 5.00, -5.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
    }
    epic.mats = {
        ['Main'] = { pos = { -3.00, 1, 0.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.38, 1.20, 1.63 }, int = false },
    }
    function EpicChangeMat()
        local mat = Layout.GetMats()[epic.name].Main
        mat.call('NextImage')
    end

    function EpicChangeMatPrev()
        local mat = Layout.GetMats()[epic.name].Main
        mat.call('PrevImage')
    end

    function EpicToggleRulers()
        local mat = Layout.GetMats()[epic.name].Main
        mat.call('ToggleRulers')
    end

    function StandardLayout()
        Layout.Switch(1)
    end

    function HotacLayout()
        Layout.Switch(3)
    end

    local bWidth = 2200
    local bHeight = 500
    local bFontSize = 230
    epic.controls = {
        {
            position = { 50.5, 1, 2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'EpicChangeMat',
            label = 'NEXT PLAYMAT'
        },
        {
            position = { 50.5, 1, -2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'EpicChangeMatPrev',
            label = 'PREV PLAYMAT'
        },
        {
            position = { 49, 1, 0 },
            rotation = { 0, 90, 0 },
            click_function = 'EpicToggleRulers',
            label = 'TOGGLE RULERS'
        },
        {
            position = { 52, 1, 0 },
            rotation = { 0, 90, 0 },
            click_function = 'StandardLayout',
            label = 'STANDARD LAYOUT'
        },
        {
            position = { 80, 1, -35 },
            rotation = { 0, 180, 0 },
            click_function = 'HotacLayout',
            label = 'HOTAC MODE'
        },
    }


    for _, button in ipairs(epic.controls) do
        button.width = bWidth
        button.height = bHeight
        button.font_size = bFontSize
        button.function_owner = self
    end
end

return epic

end)
__bundle_register("Layouts.Standard", function(require, _LOADED, __bundle_register, __bundle_modules)
local Vect = require("TTS_Lib.Vector.Vector")

local standard = {}
do
    standard.name       = 'Standard'
    standard.tableImage = 'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/textures/table.jpg'
    standard.elements   = {
        ['Damage Decks']            = { pos = { 1.89, 1.06, -0.06 }, rot = { 0.00, 45.01, 0.00 }, scale = { 1.00, 0.95, 1.00 } },
        ['Huge Ship Damage Decks']  = { pos = { 2.49, 1.00, -1.95 }, rot = { 0.00, 45.01, 0.00 }, scale = { 0.44, 0.42, 0.44 } },
        ['Tractor Beam']            = { pos = { -1.36, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Reinforce']               = { pos = { 1.36, 1.06, -9.56 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Calculate']               = { pos = { -1.28, 1.06, -9.53 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Ion']                     = { pos = { -1.40, 1.07, 8.12 }, rot = { 0.00, 180.03, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Stress']                  = { pos = { -1.39, 1.07, 10.20 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Deplete']                 = { pos = { 1.45, 1.07, 5.87 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Strain']                  = { pos = { 1.43, 1.07, 10.16 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.08, 1.08, 1.08 } },
        ['Evade']                   = { pos = { 1.40, 1.06, -7.02 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['X-Wing Attack Die']       = { pos = { 0.00, 1.08, -1.67 }, rot = { 0.00, 90.00, 90.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['X-Wing Defense Die']      = { pos = { 0.00, 1.08, 1.53 }, rot = { 90.00, 90.00, 0.00 }, scale = { 3.00, 3.00, 3.00 } },
        ['Attack Dice changer']     = { pos = { 0.03, 1.01, -1.72 }, rot = { 0.00, 315.55, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Defence Dice changer']    = { pos = { -0.03, 1.01, 1.49 }, rot = { 0.00, 137.13, 0.00 }, scale = { 2.50, 0.10, 2.50 } },
        ['Target Locks']            = { pos = { -1.93, 1.06, -0.06 }, rot = { 0.00, 180.00, 180.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Focus']                   = { pos = { -1.32, 1.06, -7.07 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Shield']                  = { pos = { 1.46, 1.06, 3.81 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Energy']                  = { pos = { 2.91, 1.01, 1.60 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 0.38, 0.38 } },
        ['Force']                   = { pos = { -1.44, 1.06, 6.01 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Charge']                  = { pos = { -1.45, 1.06, 3.81 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Critical Hit']            = { pos = { 1.43, 1.07, 8.12 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.84, 1.08, 0.84 } },
        ['Cloak']                   = { pos = { 1.36, 1.07, -4.37 }, rot = { 0.00, 270.00, 0.00 }, scale = { 1.00, 1.00, 1.00 } },
        ['Fuse']                    = { pos = { -1.31, 1.05, -4.36 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.93, 0.93, 0.93 } },
        ['Disarm']                  = { pos = { 1.34, 1.06, -12.2 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['Jam']                     = { pos = { 0, 1.06, -14.66 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.95, 0.95, 0.95 } },
        ['All mines tokens']        = { pos = { 1.36, 0.96, 12.54 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.30, 0.92, 0.30 } },
        ['Bomb drop tokens']        = { pos = { 0.02, 1.05, 14.70 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.93, 1.19, 0.93 } },
        ['All bomb tokens']         = { pos = { -1.35, 0.96, 12.53 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.57, 0.83, 0.57 } },
        ['Remotes']                 = { pos = { -2.39, 1.06, 15.55 }, rot = { 0.00, 270.00, 0.00 }, scale = { 0.95, 1.71, 0.95 } },
        ['Spare parts']             = { pos = { 2.35, 1.03, 15.59 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.80, 1.42, 0.80 } },

        ['Board Edge L']            = { pos = { -37.33, 0.80, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge R']            = { pos = { -3.71, 0.80, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge T']            = { pos = { -20.50, 0.80, 16.81 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },
        ['Board Edge B']            = { pos = { -20.50, 0.8, -16.81 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },

        ['1 Straight Templates']    = { pos = { -40.30, 0.96, -2.25 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Straight Templates']    = { pos = { -41.90, 0.96, -3.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Straight Templates']    = { pos = { -40.30, 0.96, 0.80 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['4 Straight Templates']    = { pos = { -41.90, 0.96, 1.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['5 Straight Templates']    = { pos = { -41.10, 0.96, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Bank Templates']        = { pos = { -40.00, 1.05, -7.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Bank Templates']        = { pos = { -40.62, 1.05, -8.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Bank Templates']        = { pos = { -41.25, 1.05, -9.50 }, rot = { 0.00, 270.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Turn Templates']        = { pos = { -39.70, 0.96, 7.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Turn Templates']        = { pos = { -40.20, 1.00, 8.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Turn Templates']        = { pos = { -40.70, 0.96, 9.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['Core Set Asteroids']      = { pos = { -46.10, 0.99, -7.09 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.70, 0.53, 0.70 } },
        ['TFA Set Asteroids']       = { pos = { -45.97, 0.97, -4.02 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 1.65, 0.38 } },
        ['Debris Fields']           = { pos = { -46.24, -0.27, -0.32 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.50, 1.90, 0.50 } },
        ['Gas Clouds']              = { pos = { -46.23, 0.96, 4.25 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.64, 1.14, 0.64 } },
        ['POM Set Obstacles']       = { pos = { -46.21, 0.97, 8.74 }, rot = { 0.00, 0.00, 0.00 }, scale = { 2.42, 1.14, 2.42 } },
        ['Range 1 Rulers']          = { pos = { -43.50, 1.00, -4.10 }, rot = { 0.00, 270.00, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-2 Rulers']        = { pos = { -43.50, 1.00, 2.40 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-3 Rulers']        = { pos = { -42.70, 1.00, 0.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['First player coin']       = { pos = { -2.52, 0.96, -15.59 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.40, 0.86, 0.40 }, lock = false },
        ['Game Console']            = { pos = { -38.22, 1.61, 0.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['1 Straight Templates 2']  = { pos = { 38.00, 0.97, 2.25 }, rot = { 0.00, 180.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Straight Templates 2']  = { pos = { 40.00, 0.97, -3.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Straight Templates 2']  = { pos = { 38.00, 0.97, -0.80 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['4 Straight Templates 2']  = { pos = { 40.00, 0.97, 1.50 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['5 Straight Templates 2']  = { pos = { 39.00, 0.97, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Bank Templates 2']      = { pos = { 39.50, 1.06, -7.50 }, rot = { 0.00, 225.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Bank Templates 2']      = { pos = { 40.12, 1.06, -8.50 }, rot = { 0.00, 225.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Bank Templates 2']      = { pos = { 40.75, 1.06, -9.50 }, rot = { 0.00, 225.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['1 Turn Templates 2']      = { pos = { 39.20, 0.96, 7.50 }, rot = { 0.00, 90.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['2 Turn Templates 2']      = { pos = { 39.70, 0.98, 8.50 }, rot = { 0.00, 90.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['3 Turn Templates 2']      = { pos = { 40.20, 0.97, 9.50 }, rot = { 0.00, 90.00, 0.00 }, scale = { 3.63, 3.63, 3.63 } },
        ['Core Set Asteroids 2']    = { pos = { 46.10, 0.99, -7.09 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.70, 0.53, 0.70 } },
        ['TFA Set Asteroids 2']     = { pos = { 45.97, 0.97, -4.02 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.38, 1.65, 0.38 } },
        ['Debris Fields 2']         = { pos = { 46.24, -0.27, -0.32 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.50, 1.90, 0.50 } },
        ['Gas Clouds 2']            = { pos = { 46.23, 0.96, 4.25 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.64, 1.14, 0.64 } },
        ['POM Set Obstacles 2']     = { pos = { 46.21, 0.97, 8.74 }, rot = { 0.00, 0.00, 0.00 }, scale = { 2.42, 1.14, 2.42 } },

        ['Range 1 Rulers 2']        = { pos = { 42.00, 1.00, 4.10 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-2 Rulers 2']      = { pos = { 42.00, 1.00, -2.40 }, rot = { 0.00, 270.01, 0.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['Range 1-3 Rulers 2']      = { pos = { 41.00, 1.00, 0.00 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.63, 0.63, 0.63 } },
        ['First player coin 2']     = { pos = { 2.52, 0.96, -15.59 }, rot = { 0.00, 270.00, 180.00 }, scale = { 0.40, 0.86, 0.40 }, lock = false },
        ['Board Edge L 2']          = { pos = { 37.07, 0.8, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge R 2']          = { pos = { 3.96, 0.8, 0.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.5, 0.5, 16.75 }, int = false },
        ['Board Edge T 2']          = { pos = { 20.50, 0.8, 16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },
        ['Board Edge B 2']          = { pos = { 20.50, 0.8, -16.55 }, rot = { 0.00, 90.00, 0.00 }, scale = { 0.5, 0.5, 16.50 }, int = false },

        ['Deck Holder 1']           = { pos = { -40.00, 0.90, -15.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Deck Holder 2']           = { pos = { -40.00, 0.90, 15.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Deck Holder 3']           = { pos = { 40.00, 0.90, 15.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },
        ['Deck Holder 4']           = { pos = { 40.00, 0.90, -15.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 0.65, 0.65, 0.65 } },


    }
    local assignOffset  = { -5, 1, 2 }
    local zonePos       = { 22.5, 2.5, -32 }
    local zoneScale     = { 44.9, 4, 12 }
    local stuffCenter   = { 27, 0, -18.5 }
    local stuffSize     = { 54, 1, 37 }
    local function left(data)
        return Vect.ScaleEach(data, { -1, 1, 1 })
    end
    local function opposite(data)
        return Vect.ScaleEach(data, { 1, 1, -1 })
    end
    standard.hands = {
        ['Red']    = { pos = { -22.50, 5.00, -40.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Blue']   = { pos = { -22.50, 5.00, 40.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Orange'] = { pos = { 22.50, 5.00, 40.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Purple'] = { pos = { 22.50, 5.00, -40.00 }, rot = { 0.00, 0.00, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Teal']   = { pos = { -50.00, 5.00, -15.00 }, rot = { 0.00, 90.28, 0.00 }, scale = { 5.00, 5.00, 1.00 } },
        ['Green']  = { pos = { -52.00, 5.00, 0.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['Yellow'] = { pos = { -50.00, 5.00, 15.00 }, rot = { 0.00, 90.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['Brown']  = { pos = { 50.00, 5.00, 15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['Pink']   = { pos = { 52.00, 5.00, 0.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
        ['White']  = { pos = { 50.00, 5.00, -15.00 }, rot = { 0.00, 270.00, 0.00 }, scale = { 5.01, 5.00, 1.00 } },
    }
    standard.mats = {
        ['Red-Blue'] = { pos = { -20.5142, 1, 0.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.655, 1.2, 1.655 }, int = false },
        ['Purple-Orange'] = { pos = { 20.5142, 1, 0.00 }, rot = { 0.00, 180.00, 0.00 }, scale = { 1.27, 1.2, 1.27 }, int = false },
    }
    function StandardCallMat(matName, callFcn)
        local mat = Layout.GetMats()[standard.name][matName]
        mat.call(callFcn)
    end

    function StandardChangeMatGR()
        StandardCallMat('Red-Blue', 'NextImage')
    end

    function StandardChangeMatTB()
        StandardCallMat('Purple-Orange', 'NextImage')
    end

    function StandardChangeMatGRPrev()
        StandardCallMat('Red-Blue', 'PrevImage')
    end

    function StandardChangeMatTBPrev()
        StandardCallMat('Purple-Orange', 'PrevImage')
    end

    function StandardToggleRulersGR()
        StandardCallMat('Red-Blue', 'ToggleRulers')
    end

    function StandardToggleRulersTB()
        StandardCallMat('Purple-Orange', 'ToggleRulers')
    end

    function EpicLayout()
        Layout.Switch(2)
    end

    local bWidth = 2200
    local bHeight = 500
    local bFontSize = 230
    standard.controls = {
        {
            position = { 50.5, 1, 2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'StandardChangeMatGR',
            label = 'NEXT PLAYMAT'
        },
        {
            position = { 50.5, 1, -2.5 },
            rotation = { 0, 90, 0 },
            click_function = 'StandardChangeMatGRPrev',
            label = 'PREV PLAYMAT'
        },
        {
            position = { -50.5, 1, -2.5 },
            rotation = { 0, -90, 0 },
            click_function = 'StandardChangeMatTB',
            label = 'NEXT PLAYMAT'
        },
        {
            position = { -50.5, 1, 2.5 },
            rotation = { 0, -90, 0 },
            click_function = 'StandardChangeMatTBPrev',
            label = 'PREV PLAYMAT'
        },
        {
            position = { 49, 1, 0 },
            rotation = { 0, 90, 0 },
            click_function = 'StandardToggleRulersGR',
            label = 'TOGGLE RULERS'
        },
        {
            position = { -49, 1, 0 },
            rotation = { 0, -90, 0 },
            click_function = 'StandardToggleRulersTB',
            label = 'TOGGLE RULERS'
        },
        {
            position = { 52, 1, 0 },
            rotation = { 0, 90, 0 },
            click_function = 'EpicLayout',
            label = 'EPIC LAYOUT'
        },
        {
            position = { 80, 1, -35 },
            rotation = { 0, 180, 0 },
            click_function = 'HotacLayout',
            label = 'HOTAC MODE'
        },
    }
    for _, button in ipairs(standard.controls) do
        button.width = bWidth
        button.height = bHeight
        button.font_size = bFontSize
        button.function_owner = self
    end
end

return standard

end)
__bundle_register("Layouts.LayoutElements", function(require, _LOADED, __bundle_register, __bundle_modules)
Layout = {}
Layout.FillElements = function()
    if state.active then
        Layout.elements = {
            ['Damage Decks']            = Layout.RequireFromGUID('b3ae5f'),
            ['Huge Ship Damage Decks']  = Layout.RequireFromGUID('2bca1d'),
            ['Tractor Beam']            = Layout.RequireFromGUID('e1c2fa'),
            ['Reinforce']               = Layout.RequireFromGUID('8d45a9'),
            ['Calculate']               = Layout.RequireFromGUID('eaca1b'),
            ['Ion']                     = Layout.RequireFromGUID('3d8a79'),
            ['Stress']                  = Layout.RequireFromGUID('9851b8'),
            ['Strain']                  = Layout.RequireFromGUID('2abb81'),
            ['Deplete']                 = Layout.RequireFromGUID('b75e09'),
            ['Evade']                   = Layout.RequireFromGUID('9611d6'),
            ['X-Wing Attack Die']       = Layout.RequireFromGUID('8a49f4'),
            ['X-Wing Defense Die']      = Layout.RequireFromGUID('edbe72'),
            ['Attack Dice changer']     = Layout.RequireFromGUID('e51a16'),
            ['Defence Dice changer']    = Layout.RequireFromGUID('d9a9fa'),
            ['Target Locks']            = Layout.RequireFromGUID('765252'),
            ['Focus']                   = Layout.RequireFromGUID('339681'),
            ['Shield']                  = Layout.RequireFromGUID('07d45b'),
            ['Force']                   = Layout.RequireFromGUID('ebb247'),
            ['Energy']                  = Layout.RequireFromGUID('717749'),
            ['Charge']                  = Layout.RequireFromGUID('224816'),
            ['Critical Hit']            = Layout.RequireFromGUID('aae8f1'),
            ['Fuse']                    = Layout.RequireFromGUID('568727'),
            ['Cloak']                   = Layout.RequireFromGUID('2d8850'),
            ['Disarm']                  = Layout.RequireFromGUID('95141a'),
            ['Jam']                     = Layout.RequireFromGUID('5806cd'),
            ['All mines tokens']        = Layout.RequireFromGUID('688e04'),
            ['Bomb drop tokens']        = Layout.RequireFromGUID('64f4d8'),
            ['All bomb tokens']         = Layout.RequireFromGUID('e76065'),
            ['Remotes']                 = Layout.RequireFromGUID('3279a8'),
            ['Spare parts']             = Layout.RequireFromGUID('8c8331'),
            ['First player coin']       = Layout.RequireFromGUID('f5a488'),
            ['1 Straight Templates']    = Layout.RequireFromGUID('637ad7'),
            ['2 Straight Templates']    = Layout.RequireFromGUID('ef77a3'),
            ['3 Straight Templates']    = Layout.RequireFromGUID('d81b3d'),
            ['4 Straight Templates']    = Layout.RequireFromGUID('191bcf'),
            ['5 Straight Templates']    = Layout.RequireFromGUID('0facc3'),
            ['1 Bank Templates']        = Layout.RequireFromGUID('0e80e3'),
            ['2 Bank Templates']        = Layout.RequireFromGUID('5ff1ea'),
            ['3 Bank Templates']        = Layout.RequireFromGUID('5e6a99'),
            ['1 Turn Templates']        = Layout.RequireFromGUID('4edff9'),
            ['2 Turn Templates']        = Layout.RequireFromGUID('8aec47'),
            ['3 Turn Templates']        = Layout.RequireFromGUID('747d61'),
            ['Range 1 Rulers']          = Layout.RequireFromGUID('bf91d5'),
            ['Range 1-2 Rulers']        = Layout.RequireFromGUID('0f08d4'),
            ['Range 1-3 Rulers']        = Layout.RequireFromGUID('4f88fa'),
            ['Range 1-5 Rulers']        = Layout.RequireFromGUID('3d90c5'),
            ['Core Set Asteroids']      = Layout.RequireFromGUID('521a6a'),
            ['TFA Set Asteroids']       = Layout.RequireFromGUID('3bac58'),
            ['Debris Fields']           = Layout.RequireFromGUID('065d51'),
            ['Gas Clouds']              = Layout.RequireFromGUID('8b1614'),
            ['POM Set Obstacles']       = Layout.RequireFromGUID('2bb60c'),
            ['Board Edge L']            = Layout.RequireFromGUID('ce0e09'),
            ['Board Edge R']            = Layout.RequireFromGUID('e77d03'),
            ['Board Edge T']            = Layout.RequireFromGUID('85f1b7'),
            ['Board Edge B']            = Layout.RequireFromGUID('9500ad'),
            ['First player coin 2']     = Layout.RequireFromGUID('a50db2'),
            ['1 Straight Templates 2']  = Layout.RequireFromGUID('7e4108'),
            ['2 Straight Templates 2']  = Layout.RequireFromGUID('51ebe0'),
            ['3 Straight Templates 2']  = Layout.RequireFromGUID('1dc80f'),
            ['4 Straight Templates 2']  = Layout.RequireFromGUID('98b1bf'),
            ['5 Straight Templates 2']  = Layout.RequireFromGUID('9ae5cb'),
            ['1 Bank Templates 2']      = Layout.RequireFromGUID('26957c'),
            ['2 Bank Templates 2']      = Layout.RequireFromGUID('405ab7'),
            ['3 Bank Templates 2']      = Layout.RequireFromGUID('00e7dc'),
            ['1 Turn Templates 2']      = Layout.RequireFromGUID('4d5ffb'),
            ['2 Turn Templates 2']      = Layout.RequireFromGUID('2980ac'),
            ['3 Turn Templates 2']      = Layout.RequireFromGUID('aa6531'),
            ['Core Set Asteroids 2']    = Layout.RequireFromGUID('c19b69'),
            ['TFA Set Asteroids 2']     = Layout.RequireFromGUID('bd3d1a'),
            ['Debris Fields 2']         = Layout.RequireFromGUID('b8caf9'),
            ['Gas Clouds 2']            = Layout.RequireFromGUID('c70f83'),
            ['POM Set Obstacles 2']     = Layout.RequireFromGUID('50b26f'),
            ['Range 1 Rulers 2']        = Layout.RequireFromGUID('68df70'),
            ['Range 1-2 Rulers 2']      = Layout.RequireFromGUID('7e3b54'),
            ['Range 1-3 Rulers 2']      = Layout.RequireFromGUID('a4e041'),
            ['Board Edge L 2']          = Layout.RequireFromGUID('81ace1'),
            ['Board Edge R 2']          = Layout.RequireFromGUID('83cbc5'),
            ['Board Edge T 2']          = Layout.RequireFromGUID('287b6c'),
            ['Board Edge B 2']          = Layout.RequireFromGUID('42a219'),
            ['Game Console']             = Layout.RequireFromGUID('c9a2a0'),

            ['Deck Holder 1']           = Layout.RequireFromGUID('16e138'),
            ['Deck Holder 2']           = Layout.RequireFromGUID('d43c5c'),
            ['Deck Holder 3']           = Layout.RequireFromGUID('37932a'),
            ['Deck Holder 4']           = Layout.RequireFromGUID('252512'),

            ['Mine Rules']              = Layout.RequireFromGUID('ed1a41'),
            ['Emplacement Rules 1']     = Layout.RequireFromGUID('463dd8'),
            ['Emplacement Rules 2']     = Layout.RequireFromGUID('0ab824'),
            ['Emplacement Rules 3']     = Layout.RequireFromGUID('05d16e'),
            ['Other Rules']             = Layout.RequireFromGUID('9c1c58'),
            ['Obstacle Rules']          = Layout.RequireFromGUID('ac9104'),
            ['Turn Tracker']            = Layout.RequireFromGUID('83259b'),
            ['Turn Marker']             = Layout.RequireFromGUID('ad6b64'),
            ['End Marker']              = Layout.RequireFromGUID('9b8faf'),
            ['Zone Extension 1']        = Layout.RequireFromGUID('e76836'),
            ['Zone Extension 2']        = Layout.RequireFromGUID('b5f9c9'),
            ['Zone Extension 3']        = Layout.RequireFromGUID('5a92c4'),
            ['Zone Extension 4']        = Layout.RequireFromGUID('c9a7f6'),
            ['Imp AI Sheet Bag']        = Layout.RequireFromGUID('0c4ffb'),
            ['Rebel AI Sheet Bag']      = Layout.RequireFromGUID('6c59d6'),
            ['Scum AI Sheet Bag']       = Layout.RequireFromGUID('f8a85b'),
            ['IN 1']                    = Layout.RequireFromGUID('9d500c'),
            ['IN 2']                    = Layout.RequireFromGUID('61784f'),
            ['IN 3']                    = Layout.RequireFromGUID('7d52df'),
            ['IN 4']                    = Layout.RequireFromGUID('940e76'),
            ['IN 5']                    = Layout.RequireFromGUID('961d4e'),
            ['IN 6']                    = Layout.RequireFromGUID('fea3d1'),
            ['IN 7']                    = Layout.RequireFromGUID('637366'),
            ['Player 1 Seat']           = Layout.RequireFromGUID('c43087'),
            ['Player 2 Seat']           = Layout.RequireFromGUID('af6cec'),
            ['Player 3 Seat']           = Layout.RequireFromGUID('58600e'),
            ['Player 4 Seat']           = Layout.RequireFromGUID('e9b60d'),
            ['Player 5 Seat']           = Layout.RequireFromGUID('f645b4'),
            ['Player 6 Seat']           = Layout.RequireFromGUID('bef52a'),
        }
    end
end

return Layout

end)
__bundle_register("TTS_Lib.ObjType.ObjType", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_lib
--
-- Package for easy object "type" definitions and searching nearby things
-- Description and usage in README.md in this lib folder in repository
-- ~~~~~~

local Vect = require("TTS_Lib.Vector.Vector")
local ObjType = {
    types = {}
}

-- Add a type definition
ObjType.AddType = function(typeName, fcn)
    ObjType.types[typeName] = fcn
end
ObjType.AddType('any', function() return true end)

-- Return true if object matches type
ObjType.IsOfType = function(obj, typeName)
    if not typeName or not ObjType.types[typeName] then
        error('ObjType.IsOfType: queried type \'' .. typeName .. '\' not defined')
    end
    return ObjType.types[typeName](obj)
end
-- Return a table of all type this object matches
ObjType.GetTypes = function(obj)
    local types = {}
    for type, typeFcn in pairs(ObjType.types) do
        if typeFcn(obj) then
            types[type] = true
        end
    end
    return types
end

-- Cast a regular sphere and return hit objects
ObjType.SphereCast = function(center, distance)
    local hits = Physics.cast({
        origin = Vect.Sum(center, { 0, -1.1 * distance, 0 }),
        direction = { 0, distance / 500, 0 },
        type = 2,
        size = { distance * 2, distance * 2, distance * 2 },
        debug = false
    })
    local nearData = {}
    for k, hitData in pairs(hits) do
        table.insert(nearData, hitData.hit_object)
        --table.insert(nearData, {obj = hitData.hit_object, dist=Vect.Distance(hitData.point, center)})
    end
    return nearData
end
-- Cast a box of given size and orientation and return hit objects
ObjType.BoxCast = function(center, orientation, size)
    local hits = Physics.cast({
        origin = Vect.Sum(center, { 0, -1.1 * size[2], 0 }),
        direction = { 0, size[2] / 200, 0 },
        type = 3,
        size = size,
        orientation = orientation,
        debug = false
    })
    local nearData = {}
    for k, hitData in pairs(hits) do
        table.insert(nearData, hitData.hit_object)
        --table.insert(nearData, {obj = hitData.hit_object, dist=Vect.Distance(hitData.point, center)})
    end
    return nearData
end

-- Get the object matching provided type, nearest to position/object in some radius
-- Args:
--      centerPosObj    <- Center position (vector) or object
--      maxDist         <- Max distance to check in
--      objType         <- Required type of the nearest object
--      excl            <- Table of objects excluded from search
-- Return: nearestObject, distance
ObjType.GetNearestOfType = function(centerPosObj, maxDist, objType, excl)
    local centerPos = centerPosObj
    if type(centerPosObj) == 'userdata' then
        excl[centerPosObj] = true
        centerPos = centerPosObj.getPosition()
    end
    local nearOfType = ObjType.GetNearOfType(centerPos, objType, maxDist, excl)
    return table.min(nearOfType, function(obj) return Vect.Distance(cenerPos, obj) end)
end

-- Get all objects in given radius matching given type
-- Args identical like in ObjType.GetNearestOfType
-- Return: table of objects
ObjType.GetNearOfType = function(centerPosObj, maxDist, objType, excl)
    excl = excl or {}
    for k, v in ipairs(excl) do
        excl[v] = true
        excl[k] = nil
    end
    maxDist = maxDist or 100
    assert(type(objType) == 'string', 'Obj.GetNearOfType: search type not provided')
    local centerPos = centerPosObj
    if type(centerPosObj) == 'userdata' then
        excl[centerPosObj] = true
        centerPos = centerPosObj.getPosition()
    end
    local nearData = ObjType.SphereCast(centerPos, maxDist)
    nearData = table.sieve(nearData, function(obj) return (not excl[obj] and ObjType.IsOfType(obj, objType)) end)
    return nearData
end

-- Get the all objects inside a box matching given type
-- Args:
--      centerPosObj    <- Center position (vector) or object
--      orient          <- Box orientation (vector)
--      size            <- Box size (vector)
--      objType         <- Required type of the nearest object
--      excl            <- Table of objects excluded from search
-- Return: table of objects
ObjType.GetBoxOfType = function(centerPosObj, orient, size, objType, excl)
    excl = excl or {}
    for k, v in ipairs(excl) do
        excl[v] = true
        excl[k] = nil
    end
    assert(type(objType) == 'string', 'Obj.GetNearOfType: search type not provided')
    local centerPos = centerPosObj
    if type(centerPosObj) == 'userdata' then
        excl[centerPosObj] = true
        centerPos = centerPosObj.getPosition()
    end
    local boxData = ObjType.BoxCast(centerPos, orient, size)
    boxData = table.sieve(boxData, function(obj) return (not excl[obj] and ObjType.IsOfType(obj, objType)) end)
    return boxData
end

return ObjType

end)
__bundle_register("TTS_Lib.Util.String", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Check if string begins with the argument (no regex)
if not string.beginswith then
    string.beginswith = function(str, prefix)
        return (str:sub(1, prefix:len()) == prefix)
    end
    string.startswith = string.beginswith
end

-- Check if the string ends with the argument (no regex)
if not string.endswith then
    string.endswith = function(str, prefix)
        return (str:sub(-1 * prefix:len(), -1) == prefix)
    end
end

-- Check if string contains argument anywhere in it (no regex)
if not string.contains then
    string.contains = function(str, query)
        return (str:find(query, 1, true) ~= nil)
    end
end

return string

end)
__bundle_register("TTS_Lib.Util.Table", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Check if table is empty
if not table.empty then
    table.empty = function(tab)
        return (next(tab or {}) == nil)
    end
end

-- Utility function to check if a table contains an object based on a comparison function
if not table.contains then
    table.contains = function(tbl, object, compareFunc)
        compareFunc = compareFunc or function(obj1, obj2)
            return obj1.guid == obj2.guid
        end

        for _, obj in ipairs(tbl) do
            if compareFunc(obj, object) then
                return true
            end
        end
        return false
    end
end


-- Mash together two tables
if not table.join then
    table.join = function(tab1, tab2)
        local out = {}
        for k = 1, #tab1 do
            out[k] = tab1[k]
        end
        local off = #tab1
        for k = 1, #tab2 do
            out[k + off] = tab2[k]
        end
        return out
    end
end

if not table.join_sparse then
    table.join_sparse = function(tab1, tab2)
        local out = {}
        for k, val in pairs(tab1) do
            out[k] = val
        end
        for k, val in pairs(tab2) do
            out[k] = val
        end
        return out
    end
end

-- Shallow table copy
-- Does not include metatables
if not table.shallowcopy then
    table.shallowcopy = function(orig)
        local orig_type = type(orig)
        local copy = nil
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in pairs(orig) do
                copy[orig_key] = orig_value
            end
        else
            copy = orig
        end
        return copy
    end
end

-- Deep table copy
-- Includes metatables, avoids __pairs, recursive
if not table.deepcopy then
    table.deepcopy = function(orig)
        local orig_type = type(orig)
        local copy = nil
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
            end
            if getmetatable(orig) then
                setmetatable(copy, table.deepcopy(getmetatable(orig)))
            end
        else
            copy = orig
        end
        return copy
    end
end

-- Elements count
-- Unlike #table, also counts non-number keyed values
if not table.size then
    table.size = function(tab)
        local count = 0
        for _ in pairs(tab) do
            count = count + 1
        end
        return count
    end
end

-- Return the element that return minimal value from eval function
-- Only iterates through numeric keys part
if not table.min then
    table.min = function(tab, eval)
        if not tab[1] then return end
        local min = { el = tab[1], val = eval(tab[1]) }
        for k = 2, #tab do
            local val = eval(tab[k])
            if val < min.val then
                min.val = val
                min.el = tab[k]
            end
        end
        return min.el, min.val
    end
end

-- Same as table.min, but takes the maximum
if not table.max then
    table.max = function(tab, eval)
        local function invEval(el)
            return -1 * eval(el)
        end
        local el, min = table.min(tab, invEval)
        return el, -1 * min
    end
end

-- Return those values in tab that return true from valid function
if not table.sieve then
    table.sieve = function(tab, valid)
        local passed = {}
        local rejected = {}
        for k, v in ipairs(tab) do
            if valid(v) then
                if type(k) == 'number' then
                    table.insert(passed, v)
                else
                    passed[k] = v
                end
            else
                if type(k) == 'number' then
                    table.insert(rejected, v)
                else
                    rejected[k] = v
                end
            end
        end
        return passed, rejected
    end
end

-- Try to find en element in the table, return key if found, nil otherwise
if not table.find then
    table.find = function(tab, el)
        for k, v in pairs(tab) do
            if v == el then
                return k
            end
        end
    end
end

-- Shallow table print
if not table.print then
    table.print = function(tab, prefix)
        prefix = prefix or 'Table'
        print(prefix .. ':')
        local function stringify(v)
            local str = tostring(v)
            if type(v) == 'string' then
                str = '\'' .. str .. '\''
            end
            return str
        end
        for k, v in pairs(tab) do
            print('   [' .. stringify(k) .. '] -> ' .. stringify(v))
        end
        print('')
    end
end

-- Deep table print (sensitive to cycles!)
if not table.print_r then
    table.print_r = function(tab, prefix, indent)
        prefix = prefix or 'Table'
        local indent = indent or 1
        print(prefix .. ':')
        local function stringify(v)
            local str = tostring(v)
            if type(v) == 'string' then
                str = '\'' .. str .. '\''
            end
            return str
        end
        local indentStr = string.rep('    ', indent)
        for k, v in pairs(tab) do
            print(indentStr .. '[' .. stringify(k) .. '] -> ' .. stringify(v))
            if type(v) == 'table' then
                table.print_r(v, indentStr .. stringify(v), indent + 1)
            end
        end
        if indent == 1 then
            print('')
        end
    end
end

-- Apply a function on each table element
if not table.process then
    table.process = function(tab, fcn)
        local out = {}
        for k, v in pairs(tab) do
            out[k] = fcn(v)
        end
        return out
    end
end

-- Returns a copy of a table with the elements in a random order.
if not table.shuffle then
    table.shuffle = function(tab)
        local shuffled_table = {}
        for i = 1, #tab do
            shuffled_table[i] = tab[i]
        end
        for i = #shuffled_table, 2, -1 do
            local j = math.random(i)
            shuffled_table[i], shuffled_table[j] = shuffled_table[j], shuffled_table[i]
        end
        return shuffled_table
    end
end

if not table.index_of then
    table.index_of = function(tab, el)
        for i, v in ipairs(tab) do
            if v == el then
                return i
            end
        end
        return nil
    end
end

return table

end)
return __bundle_require("Layout Controller.b3992e.lua")