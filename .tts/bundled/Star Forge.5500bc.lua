-- Bundled by luabundle {"rootModuleName":"Star Forge.5500bc.lua","version":"1.6.0"}
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
__bundle_register("Star Forge.5500bc.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.StarForge.StarForge")

end)
__bundle_register("Game.StarForge.StarForge", function(require, _LOADED, __bundle_register, __bundle_modules)
-- This is the Star Forge!
-- It will make what ever you desire!

-- StarForge.ttslua

if not self.hasTag("Star Forge") then
    printToAll("Only the Star Forge itself should run this script.")
    return
end

require("TTS_lib.Util.Table")
local SFScript   = require("Game.StarForge.StarForgeScriptManager")
local SFDeduper  = require("Game.StarForge.StarForgeDeduper")
local SFTester   = require("Test.DataPadTest")
local SFVector   = require("Test.HotAC.ApproachVectorTest")
local BagHandler = require("Game.Component.Spawner.BagHandler")

--[[
## Star Forge

Utility Object to aid in Game Mod Script Updates. Locating and "sourcing" Objects.
- This should replace the Accessories Bag or at least provide a Facade in front of it
- Extract and lay out all scripted objects
    - Possibly be sensitive to HotAC vs Standard Layout vs Epic Layout
    - Reset each script back to itself to force an update.
    - Keep track of where each object came from to survive a save and reload.

### Steps:

1. **Extract All Objects**:
    - Trigger a context menu to "Take Everything Out," which will:
    1. Lay out all scripted objects.

    2. Keep track of which Bag each object came from, as they need to be returned to their original bag.
    3. If the object is a multi-state object:
        - Keep track of the initial state (baseState).
        - Clone the object for each state and stack them vertically.
        - This allows VSCode to update the alternative state's scripts.

2. **Save and Reload**:
    1. Save the game via TTS UI.
    2. Load the game via TTS UI.
    3. Send all scripts from VSCode.

3. **Put Everything Away**:
    - Trigger a context menu to "Put Everything Away," which will:
    - For each object that was taken out:
        1. Reset the bag it came from.
        2. Put the object back.
        3. If the object is the initial state of a multi-state object:
            - Traverse all initial state's copies and have them:
                - Change the baseState object to match their state.
                - Set the baseState's script for that state to the new one from the extra state object.
                - Destroy the extra state object.
            - Set the initial state object back to its baseState.
        4. Put the initial state object back in the bag it came from.

- Assess each Container as a possible source of objects.
    - Point out when there are duplicate sources for an object.
    - Front all containers/dispensers as a registry for objects
    - Not all Bags have names
    - Not all Objects in Bags have names
    - Multi-State Objects need
        - each of their names and
        - a way to recognize which one to morph to
    - names may include: Bag name, Object Contents name, or NickName

### Requirements
- Each object to be produced needs a unique name.
]]
local StarForge = {
    factories = {},
    lastLayout = 1
}

local bagGuids = {
    'a3690e', -- Extra Assets 15 items
    '203cb8', -- ObstacleBag 31 items
    'f0e7b9', -- Dice Bag 10 items
    '53ad3d', -- Accessories 81 items
}

local layoutController_GUID = "b3992e"

function onSave()
    local saveData = {}
    saveData.lastLayout = getCurrentLayout()
    saveData.objects = SFScript.objects
    saveData.hidden = self.getVar("hidden")
    return JSON.encode(saveData)
end

function onLoad(saveData)
    if saveData ~= "" then
        local loadData = JSON.decode(saveData)
        if loadData and loadData.lastLayout ~= nil then
            StarForge.lastLayout = loadData.lastLayout
        else
            StarForge.lastLayout = getCurrentLayout()
        end
        if loadData and loadData.objects ~= nil then
            SFScript.objects = loadData.objects
        end
        self.setVar("hidden", loadData.hidden or false)
    end
    if self.getVar("hidden") then
        hide()
    else
        show()
    end
    showMainMenu()
end

function setToLayout(layoutNumber)
    local layout = getObjectFromGUID(layoutController_GUID)
    if layout then
        StarForge.lastLayout = layout.call("setLayoutState", layoutNumber)
    else
        printToAll("Error: Layout object not found.", Color.Orange)
    end
end

function getCurrentLayout()
    local layout = getObjectFromGUID(layoutController_GUID)
    if layout then
        return layout.call("getLayoutState", layoutNumber)
    else
        printToAll("Error: Layout object not found.", Color.Orange)
    end

    return -1
end

function show()
    local sPos = self.getPosition()
    self.setPosition({ sPos[1], 0.8, sPos[3] })
    self.setScale({ 2.10, 2.10, 2.10 })
    self.interactable = true
    self.tooltip = true
    self.lock()
    self.setVar("hidden", false)
    printToAll("Star Forge is active and online!", Color.Orange)
end

function hide()
    local sPos = self.getPosition()
    self.setPosition({ sPos[1], -3, sPos[3] })
    self.setScale({ 0.0001, 0.0001, 0.0001 })
    self.interactable = false
    self.tooltip = false
    self.lock()
    if not self.getVar("hidden") then
        printToAll("Star Forge is going offline!", Color.Orange)
    end
    self.setVar("hidden", true)
end

local function colorText(text, color)
    return "[" .. color:toHex() .. "]" .. text .. "[-]"
end

MultiStateExp = function()
    -- local bag = getObjectFromGUID("224816") -- Charge Token
    -- local bag = getObjectFromGUID("ae62df") -- Wing Tool
    -- local bag = getObjectFromGUID("07d45b") -- Shield
    local bag = getObjectFromGUID("8b1614") -- Gas Cloud
    if bag == nil then
        printToAll("Bag is nil")
        return
    end

    printToAll(colorText(bag.getName(), Color.Orange) .. " Bag type is " .. colorText(tostring(bag.type), Color.Blue))

    SFScript.takeObject(bag, "")
end

ListFactories = function()
    printToAll("StarForge: List Factories")
    if not StarForge.factories or next(StarForge.factories) == nil then
        printToAll("StarForge: no Factories registered")
        return
    end
    printToAll("StarForge Factories:")
    for object, factory in pairs(StarForge.factories) do
        printToAll("a function named: " .. factory.funcName)
        factory.func(object)
    end
    printToAll("End Factories:")
end

StarForge.RegisterFactory = function(factory, product)
    local previousFactory = StarForge.factories[product]
    if previousFactory ~= nil then
        printToAll("Replacing " .. previousFactory.getName() .. " with " .. factory.getName())
    end
    StarForge.factories[product] = factory
    return previousFactory
end

function NoOp(obj)
end

handlers = function()
    local typeHandlers = {
        Generic = NoOp,
        Figurine = NoOp,
        Dice = NoOp,
        Coin = NoOp,
        Board = NoOp,
        Chip = NoOp,
        Bag = NoOp,
        Infinite = NoOp
    }
    return typeHandlers
end


factory = function(dispenser, func, funcName)
    local factory = {}
    factory.dispenser = dispenser
    factory.func = printInfiniteBag
    factory.funcName = 'printInfiniteBag'
    return factory
end

extractProducts = function(dispenser)
    local names = {}
    local call_back = function(obj)
        print(tostring(obj))
        table.insert(names, "dispenser: " .. tostring(dispenser.getName()))
        table.insert(names, "name: " .. tostring(obj.getName()))
    end
    local position = { 0, 2, 0 }
    interrogateContainer(dispenser, position, call_back)
    return names
end

interrogateContainer = function(dispenser, position, callback)
    dispenser.takeObject({
        -- guid = itemGuid,
        smooth = true,
        position = position,
        callback_function = function(obj)
            -- Handle the object after it's taken from the bag
            -- if dispenser.type == "InfiniteBag" then
            callback(obj)
            -- else
            --     local clone = obj.clone({ position = position })     -- Clone it to the desired position
            --     factory.putObject(obj)                               -- Put the original back into the bag
            --     if callback then
            -- callback(clone)
            --     end
            -- end
        end
    })
end

function printInfiniteBag(obj)
    printToAll(tostring(obj) .. " is a Infinite Bag", Color.Green)
end

function printBag(obj)
    printToAll(tostring(obj) .. " is a Bag", Color.Yellow)
end

-- Method to get an object from a factory (Bag or InfiniteBag)
function StarForge.getObjectFromFactory(factoryName, objectName, position, callback)
    local factory = self.getFactory(factoryName)
    if not factory then
        print("Factory not found: " .. factoryName)
        return
    end

    local items = factory.getObjects() -- Retrieve a list of all items in the bag
    local itemGuid = nil               -- This will store the GUID of the requested object

    -- Search through the items to find the requested object
    for _, item in ipairs(items) do
        if item.name == objectName then
            itemGuid = item.guid
            break
        end
    end

    if itemGuid then
        factory.takeObject({
            guid = itemGuid,
            smooth = true,
            position = position,
            callback_function = function(obj)
                -- Handle the object after it's taken from the bag
                if factory.type == "InfiniteBag" then
                    obj.setPosition(position)
                else
                    local clone = obj.clone({ position = position }) -- Clone it to the desired position
                    factory.putObject(obj)                           -- Put the original back into the bag
                    if callback then
                        callback(clone)
                    end
                end
            end
        })
    else
        print("Object not found in factory: " .. objectName)
    end
end

function StarForge.createObject(name, options)
    options = options or {}
    local bag = StarForge.factories[name]
    if bag then
        local params = {
            position = options.position or (bag.getPosition() + Vector(0, 2, 0)),
            rotation = options.rotation,
            smooth = options.smooth or false,
            callback_function = options.callback_function
        }
        local obj = bag.takeObject(params)
        if options.clone then
            return obj.clone({ position = params.position })
        else
            return obj
        end
    else
        print("Error: No registered factory with name: " .. name)
        return nil
    end
end

-- Utility function to check if a table contains a value
function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function getInfiniteBagProductName(asset_bag)
    local name = asset_bag.getName()
    local product = asset_bag.takeObject()

    if asset_bag then
        for _, containedObject in ipairs(asset_bag.getObjects()) do
            asset = asset_bag.takeObject({
                index = containedObject.index,
                position = self.getPosition() + Vector(10, 2, 0),
                rotation = self.getRotation() + Vector(180, 0, 0),
            })
            assetClone = asset.clone()
            asset_bag.putObject(assetClone)
            break
        end
    end
end

function watchaGot(bag)
    if bag.type == "InfiniteBag" then
        return tookAnObject(bag)
    elseif bag.type == "Bag" then
        return whatsInTheBag(bag)
    end
    printToAll("Not a Bag")
    return {}
end

function whatsInTheBag(mixedBag)
    if bag == nil then
        printToAll("How did we get a nil bag!?")
        return
    end
    local names = {}
    printToAll("bag.type: " .. bag.type)
    printToAll("function is " .. tostring(bag.getObjects))
    local result = bag.getObjects
    printToAll("result is " .. tostring(result))
    result = result()
    if result == nil then
        return
    end
    for _, product in ipairs(result) do
        local name = product.getName()
        if name ~= nil then
            table.insert(names, name)
        end
    end
    return names
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
                index = i - 1, -- Adjust index to current position in the array
                smooth = false
            })
        end
    end
end

LaunchProbe = function()
    local myBagHandler = BagHandler:new('53ad3d')
    myBagHandler:takeItemByName("Probe", { position = { -30, 2, -20 } })
end

function HiddenBags(operation)
    for _, guid in ipairs(bagGuids) do
        local bag = getObjectFromGUID(guid)
        if bag ~= nil then
            bag.call(operation)
        end
    end

    local guids = {
        '2ef5bb', -- Relay (Mod Load Counter)
        '900937', -- MoveLUT
        'f8f07c', -- Dial Set source
        '3d63d2', -- dice Preload Green
        'be075b', -- dice Preload Red
    }

    for _, guid in ipairs(guids) do
        local obj = getObjectFromGUID(guid)
        local pos = obj.getPosition()
        if "submerge" == operation and pos.y > 0 then
            pos.y = -1 * pos.y
        elseif "surface" == operation and pos.y < 0 then
            pos.y = -1 * pos.y
        end
        obj.setPosition(pos)
    end

    local compositeBaseGUID = '8c3322'
    local obj = getObjectFromGUID(compositeBaseGUID)
    local pos = obj.getPosition()
    if "submerge" == operation then
        obj.setPosition(Vector(0, -3, 0))
    else
        obj.setPosition(Vector(0, 3, 0))
    end
end

-- Function to show a menu based on the menu name
function showMenu(menu)
    self.clearContextMenu()
    for _, item in ipairs(menus[menu]) do
        self.addContextMenuItem(item[1], item[2], false)
    end
end

function showMainMenu()
    setToLayout(StarForge.lastLayout)
    showMenu("main")
end

function showScriptingMenu()
    setToLayout(2) -- Epic Layout
    showMenu("scripting")
end

menus = {
    main = {
        { "Script Manager >", showScriptingMenu },
        { "Game Tester >",    function() showMenu("testing") end },
        { "Deduplicator >",   function() showMenu("deduper") end },
        { "Hidden Bags >",    function() showMenu("bags") end },
        { "Launch Probe",     LaunchProbe },
        { "List Factories",   ListFactories },
    },
    bags = {
        { "Surface Bags",   function() HiddenBags("surface") end },
        { "Submerge Bags",  function() HiddenBags("submerge") end },
        { "Back to Main >", showMainMenu },
    },
    scripting = {
        { "Multi-State Object",  MultiStateExp },
        { "Take Everything Out", SFScript.TakeEveryThingOut },
        { "Put Everything Away", SFScript.PutEverythingAway },
        { "Dump Products",       SFScript.dumpProducts },
        { "Back to Main >",      showMainMenu },
    },
    testing = {
        { "DataPad Spawn Test",   SFTester.runSmokeTest },
        { "Approach Vector Test", SFVector.runSmokeTest },
        { "Back to Main >",       showMainMenu },
    },
    deduper = {
        { "Scan For Duplicates", SFDeduper.ScanAllBags },
        { "Layout Duplicates",   SFDeduper.LayoutDuplicates },
        { "Back to Main >",      showMainMenu },
    },
}

end)
__bundle_register("Game.Component.Spawner.BagHandler", function(require, _LOADED, __bundle_register, __bundle_modules)
BagHandler = {}

function BagHandler:new(bag_guid)
    local self = { bag_guid = bag_guid }
    setmetatable(self, { __index = BagHandler })

    self.bag = getObjectFromGUID(bag_guid)
    if not self.bag then
        error("Bag with GUID " .. tostring(bag_guid) .. " not found.")
    end

    return self
end

-- Private method: Generalized item retrieval with a criterion function
function BagHandler:_findAndTakeItem(criterion, parameters)
    local clonedBag = self.bag.clone({ position = { x = -38, y = 3, z = -21 } })

    local item = nil

    for _, objData in ipairs(clonedBag.getObjects()) do
        if criterion(objData) then
            parameters.guid = objData.guid
            item = clonedBag.takeObject(parameters)
            break
        end
    end
    clonedBag.destruct()

    return item
end

-- Take an item by GUID
function BagHandler:takeItemByGUID(item_guid, parameters)
    return self:_findAndTakeItem(
        function(objData) return objData.guid == item_guid end, parameters
    )
end

-- Take an item by name
function BagHandler:takeItemByName(item_name, parameters)
    return self:_findAndTakeItem(
        function(objData) return objData.name == item_name end, parameters
    )
end

-- Take an item by custom filter
function BagHandler:takeItemByFilter(filter_function, parameters)
    return self:_findAndTakeItem(filter_function, parameters)
end

return BagHandler

end)
__bundle_register("Test.HotAC.ApproachVectorTest", function(require, _LOADED, __bundle_register, __bundle_modules)
require("TTS_lib.Util.Table")
local MissionApproachVectors = require("Game.HotAC.Setup.MissionApproachVectors")

local SmokeTest = {}

SmokeTest.runSmokeTest = function()
    printToAll("Approach Vectors Test ...", { 0, 1, 0 })

    local approachVectors = {
        "L3", "L6", "T2.5", "T6.5", "R6", "R3"
    }

    local mission = MissionApproachVectors:new(approachVectors)

    -- Show all approach vectors
    -- mission:showAll()

    -- To remove all approach vectors
    -- mission:removeAll()

    -- To layout ships around the approach vectors
    -- mission:layoutShips(ships)

    printToAll("Approach Vectors Test Completed.", { 0, 1, 0 })
end

return SmokeTest

end)
__bundle_register("Game.HotAC.Setup.MissionApproachVectors", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApproachVector = require("Game.HotAC.Setup.ApproachVector")

MissionApproachVectors = {}
MissionApproachVectors.__index = MissionApproachVectors

-- Constructor for the ApproachVectorContainer class
function MissionApproachVectors:new(vectors)
    local self = setmetatable({}, MissionApproachVectors)
    self.vectors = {}
    if vectors ~= nil then
        for index = 1, #vectors, 1 do
            self:addVector(index, vectors[index])
        end
    end
    return self
end

-- Function to add an approach vector
function MissionApproachVectors:addVector(index, notation)
    local vector = ApproachVector:new(index, notation)
    table.insert(self.vectors, vector)
    vector:addApproachVector()
end

-- Function to show all approach vectors
function MissionApproachVectors:showAll()
    for _, vector in ipairs(self.vectors) do
        vector:addApproachVector()
    end
end

-- Function to remove all approach vectors
function MissionApproachVectors:removeAll()
    for _, vector in ipairs(self.vectors) do
        local obj = getObjectFromGUID(vector.objectGUID)
        if obj then
            obj.destruct()
        end
    end
    self.vectors = {}
end

-- Function to layout ships around all approach vectors
function MissionApproachVectors:layoutShips(index, ships)
    self.vectors[index]:layoutShips(ships)
end

return MissionApproachVectors

end)
__bundle_register("Game.HotAC.Setup.ApproachVector", function(require, _LOADED, __bundle_register, __bundle_modules)
local Transform = require("TTS_lib.Vector.Transform")
local Dim = require("Dim")

ApproachVector = {}
ApproachVector.__index = ApproachVector

local image_url =
"https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/HotAC/Table/Approach%20Vector.png"
local model_url =
"https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/HotAC/Table/Approach%20Vector.obj"

-- Constructor for the ApproachVectorArea class
function ApproachVector:new(index, notation)
    local self = setmetatable({}, ApproachVector)
    self.index = index
    self.notation = notation
    self.position, self.forward = self:calculatePositionAndForward(notation)
    self.transform = Transform:new(self.position, self.forward)
    self:createApproachVectorUI(index)
    return self
end

-- Function to calculate the position and forward vector based on the notation
function ApproachVector:calculatePositionAndForward(notation)
    local boardEdges = self:getBoardEdges()

    local edge, range = notation:match("([LTRB])(%d%.?%d?)")
    range = Dim.Convert_mm_igu(tonumber(range) * 100) -- Assuming 1 Range Unit = 100 mm

    local position, forward

    if edge == "T" then
        position = Vector(boardEdges["L"].x + range, 1, boardEdges["T"].z)
        forward = Vector(0, 0, -1)
    elseif edge == "B" then
        position = Vector(boardEdges["L"].x + range, 1, boardEdges["B"].z)
        forward = Vector(0, 0, 1)
    elseif edge == "L" then
        position = Vector(boardEdges["L"].x, 1, boardEdges["B"].z + range)
        forward = Vector(1, 0, 0)
    elseif edge == "R" then
        position = Vector(boardEdges["R"].x, 1, boardEdges["B"].z + range)
        forward = Vector(-1, 0, 0)
    else
        printToAll("Invalid notation: " .. notation, Color.Red)
    end

    return position, forward
end

-- Function to get the board edges from the layout
function ApproachVector:getBoardEdges()
    local hotacMatGUID = "79e109"
    local hotacMat = getObjectFromGUID(hotacMatGUID)
    if hotacMat then
        local bounds = hotacMat.getBounds()
        local halfSize = bounds.size * 0.5

        local boardEdges = {
            T = { x = bounds.center.x, z = bounds.center.z + halfSize.z },
            B = { x = bounds.center.x, z = bounds.center.z - halfSize.z },
            L = { x = bounds.center.x - halfSize.x, z = bounds.center.z },
            R = { x = bounds.center.x + halfSize.x, z = bounds.center.z }
        }

        return boardEdges
    else
        printToAll("Error: HotAC mat not found.", Color.Orange)
    end
end

-- Function to create the approach vector UI
function ApproachVector:createApproachVectorUI(index)
    local uiData = {
        tag = "Panel",
        attributes = {
            id = "approachVectorPanel" .. index,
            rectAlignment = "MiddleCenter",
            width = 0,
            height = 0,
            visibility = "approachVectorPanel"
        },
        children = {
            {
                tag = "Text",
                attributes = {
                    id = "approachVectorNumber" .. index,
                    text = tostring(index),
                    color = "#FFFFFF",
                    fontSize = "300",
                    alignment = "MiddleCenter"
                }
            }
        }
    }
    UI.setXmlTable({ uiData })
end

function ApproachVector:addApproachVector()
    self:addApproachVectorObject()
end

function ApproachVector:addApproachVectorCard()
    local targetForward = self.forward
    local currentForward = Vector(0, 0, -1)
    local angle = targetForward:angle(currentForward)
    local direction = currentForward:cross(targetForward)
    angle = direction * angle

    local card = {
        type = "Card",
        position = self.position,
        rotation = angle,
        scale = { 1, 1, 1 },
        sound = false,
        snap_to_grid = true,
        callback_function = function(obj)
            self:attachUIToVector(obj)
            local name = "Approach Vector #" .. self.index .. " [" .. self.notation .. "]"
            obj.setName(name)
        end
    }

    local cardData = {
        type = 0,
        face = image_url,
        back = image_url
    }

    local approachVector = spawnObject(card)
    approachVector.setCustomObject(cardData)
end

function ApproachVector:addApproachVectorObject()
    local targetForward = self.forward
    local currentForward = Vector(0, 0, -1)
    local angle = targetForward:angle(currentForward)
    local direction = currentForward:cross(targetForward)
    angle = direction * angle
    local pos = self.position
    pos.y = 1.1

    local object = {
        type = "Custom_Model",
        position = pos,
        rotation = angle,
        scale = { 1, 1, 1 },
        sound = false,
        snap_to_grid = true,
        callback_function = function(obj)
            self:attachUIToVector(obj)
            local name = "Approach Vector #" .. self.index .. " [" .. self.notation .. "]"
            obj.setName(name)
            if obj.is_face_down then
                printToAll("flipping: " .. obj.getName())
                obj.flip()
            end
        end
    }


    local customUI = {
        type = 0,
        mesh = model_url,
        diffuse = image_url,
        material = 3,
    }

    local approachVector = spawnObject(object)
    approachVector.setCustomObject(customUI)
end

function ApproachVector:addApproachVectorDie()
    local targetForward = self.forward
    local currentForward = Vector(0, 0, -1)
    local angle = targetForward:angle(currentForward)
    local direction = currentForward:cross(targetForward)
    angle = direction * angle

    local die4 = {
        type = "Die_4",
        position = self.position,
        rotation = { 0, 100 / 3, 0 },
        scale = { 1, 1, 1 },
        sound = false,
        snap_to_grid = true,
        callback_function = function(obj)
            self:attachUIToVector(obj)
            local name = "Approach Vector #" .. self.index .. " [" .. self.notation .. "]"
            obj.setName(name)
            obj.setValue(1)
            obj.setRotation(-1 * angle)
        end
    }

    local approachVector = spawnObject(die4)
end

function ApproachVector:attachUIToVector(obj)
    obj.UI.setXmlTable({
        {
            tag = "Text",
            attributes = {
                text = "Vector " .. tostring(self.index),
                color = "#FFFFFF",
                fontSize = "300",
                alignment = "MiddleCenter",
                rectAlignment = "MiddleCenter",
                width = 0,
                height = 0
            }
        }
    })
end

-- Function to layout ships around the approach vector area
function ApproachVector:layoutShips(ships)
    self.transform:translate(ships)
end

return ApproachVector

end)
__bundle_register("Dim", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_xwing
--
-- X-Wing related measurements for TTS
-- ~~~~~~

local Dim = {}

-- adjusted length = 40mm = 1.4536igu
-- 1mm = 0.03634igu
Dim.mm_igu_ratio = 0.03637

-- 40mm = 1.445igu
-- (s1 length / small base size)

-- 1mm = 0.036125igu
--mm_igu_ratio = 0.036125

-- Millimeter dimensions of ship bases
Dim.mm_smallBase = 40
Dim.mm_mediumBase = 60
Dim.mm_largeBase = 80

Dim.mm_baseSize = {
    small = 40,
    medium = 60,
    large = 80,
    huge = 80,
    smallBase = 40,
    mediumBase = 60,
    largeBase = 80,
    hugeBase = 80,
    objective = 36,
}

----------------------------------------
-- Standard X-Wing Maneuver Templates --
----------------------------------------

Dim.XWingTemplates = {
    straight = { 40, 80, 120, 160, 200 }, -- Speed to millimeters
    turn = { 35, 62.5, 90 },              -- Turn Middle Radius (mm)
    bank = { 80, 130, 180 },              -- Bank Middle Radius (mm)
}

-- Millimeter dimensions for cards
Dim.mm_upgrade_width = 41
Dim.mm_upgrade_height = 63
Dim.mm_pilot_width = 63.5
Dim.mm_pilot_height = 88

Dim.mm_ship_scale = vector(0.629, 0.629, 0.629)

Dim.mm_cardSize = {
    upgrade = { width = 41, height = 63 },
    pilot = { width = 63.5, height = 88 }
}

-- Millimeter dimension for dial cards
Dim.mm_dialSize = 54

-- Convert argument from MILLIMETERS to IN-GAME UNITS
function Dim.Convert_mm_igu(millimeters)
    return millimeters * Dim.mm_igu_ratio
end

-- Convert argument from IN-GAME UNITS to MILLIMETERS
function Dim.Convert_igu_mm(in_game_units)
    return in_game_units / Dim.mm_igu_ratio
end

return Dim

end)
__bundle_register("TTS_lib.Vector.Transform", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Define a class for Transform
local Transform = {}
Transform.__index = Transform

-- Constructor
function Transform:new(targetPosition, targetForward)
    local self = setmetatable({}, Transform)
    self.targetPosition = targetPosition
    self.targetForward = targetForward:normalize()
    return self
end

-- Method to calculate the centroid of a group of objects
function Transform:calculateCentroid(objects)
    local sum = Vector(0, 0, 0)
    for _, obj in ipairs(objects) do
        sum:add(obj.getPosition())
    end
    return sum:scale(1.0 / #objects)
end

-- Method to calculate the rotation angle between two forward vectors
function Transform:calculateRotationAngle(currentForward, targetForward)
    local angle = targetForward:angle(currentForward)

    -- Determine the sign of the angle based on the cross product
    local crossProduct = targetForward:cross(currentForward)
    if crossProduct.y < 0 then
        angle = -angle
    end

    return angle
end

-- Method to rotate a point around the Y-axis by a given angle
function Transform:rotateAroundY(point, origin, angle)
    local pos = point - origin
    pos:rotateOver('y', angle)
    return pos + origin
end

-- Method to apply the transformation to a single object
function Transform:applyToObject(object, centroid, rotationAngle)
    local currentPos = object.getPosition()

    -- Rotate the object around the centroid
    local rotatedPos = self:rotateAroundY(currentPos, centroid, rotationAngle)

    -- Calculate translation
    local translation = self.targetPosition - centroid

    -- Apply translation
    local newPos = rotatedPos + translation
    object.setPositionSmooth(newPos)

    -- Apply rotation
    local currentRotation = object.getRotation()
    local newRot = {
        x = currentRotation.x,
        y = (currentRotation.y + rotationAngle) % 360,
        z = currentRotation.z,
    }
    object.setRotationSmooth(newRot)
end

-- Public method to apply the transformation to a single object or a table of objects
function Transform:translate(objects)
    local objectList = objects
    if type(objects) ~= "table" then
        objectList = { objects }
    end

    local centroid = self:calculateCentroid(objectList)
    local currentForward = objectList[1]:getTransformForward():normalize()
    local rotationAngle = self:calculateRotationAngle(currentForward, self.targetForward)

    for _, obj in ipairs(objectList) do
        self:applyToObject(obj, centroid, rotationAngle)
    end
end

return Transform

end)
__bundle_register("TTS_lib.Util.Table", function(require, _LOADED, __bundle_register, __bundle_modules)
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
__bundle_register("Test.DataPadTest", function(require, _LOADED, __bundle_register, __bundle_modules)
require("TTS_lib.Util.Table")
local Sequence = require("TTS_lib.Sequence.Sequence")
local PlayerArea = require("Player.PlayerArea")

local DataPadTest = {}

DataPadTest.runSmokeTest = function()
    local bluePlayerArea = PlayerArea:new(Player["Blue"])
    local redPlayerArea = PlayerArea:new(Player["Red"])

    local seq = Sequence:new(true)

    seq:addTask(printToAll, "Starting Smoke Test...", { 0, 1, 0 })
    DataPadTest.spawnImperialShips(seq, bluePlayerArea)
    DataPadTest.spawnRebelShips(seq, redPlayerArea)
    seq:addTask(printToAll, "Smoke Test Completed.", { 0, 1, 0 })

    seq:start()
end

function DataPadTest.spawnImperialShips(seq, playerArea)
    local dataPad = getObjectFromGUID("a4dbbf")
    if dataPad == nil then
        printToAll("Didn't find DataPad", { 0, 1, 0 })
        return
    end
    local player_color = playerArea.player.color

    seq:clickButton(dataPad, 'Spawn List', player_color, false)
    seq:clickButton(dataPad, 'XWA Points', player_color, false)
    seq:clickButton(dataPad, 'Builder', player_color, false)
    seq:clickButton(dataPad, 'Imperial', player_color, false)
    seq:clickButton(dataPad, 'Add Ship', player_color, false)
    seq:clickButton(dataPad, 'TIE/ln Fighter', player_color, false)
    seq:clickButton(dataPad, '"Howlrunner"%s*%(%d+%)', player_color, false)
    seq:clickButton(dataPad, 'Add Ship', player_color, false)
    seq:clickButton(dataPad, 'TIE Advanced x1', player_color, false)
    seq:clickButton(dataPad, 'Darth Vader%s*%(%d+%)', player_color, false)
    seq:clickButton(dataPad, 'Spawn List', player_color, false)
    seq:waitFrames(120)
    seq:physicsCast(dataPad.getTable('data_pad_spawn_area'), moveableFilter)
    seq:waitCondition(function()
        seq.ctx.imperialSquadron = seq.result
        playerArea:translate(seq.ctx.imperialSquadron:getObjects())
    end, function()
        return seq.result:allAtRest()
    end)
    seq:waitCondition(function()
            local dials = seq.ctx.imperialSquadron:filter(function(obj)
                return obj.getName() == "Unassigned Dial"
            end)
            DataPadTest.dropDials(dials, playerArea)
        end,
        function()
            return seq.ctx.imperialSquadron:allAtRest()
        end)
end

function DataPadTest.spawnRebelShips(seq, playerArea)
    local dataPad = getObjectFromGUID("a4dbbf")
    if dataPad == nil then
        printToAll("Didn't find DataPad", { 0, 1, 0 })
        return
    end
    local player_color = playerArea.player.color

    seq:clickButton(dataPad, 'Spawn List', player_color, false)
    seq:clickButton(dataPad, 'XWA Points', player_color, false)
    seq:clickButton(dataPad, 'Builder', player_color, false)
    seq:clickButton(dataPad, 'Rebel', player_color, false)
    seq:clickButton(dataPad, 'Add Ship', player_color, false)
    seq:clickButton(dataPad, 'Y%-Wing', player_color, false)
    seq:clickButton(dataPad, 'Gray Squadron Bomber%s*%(%d+%)', player_color, false)
    seq:clickButton(dataPad, 'Add Ship', player_color, false)
    seq:clickButton(dataPad, 'X%-Wing', player_color, false)
    seq:clickButton(dataPad, 'Luke Skywalker%sRed Five%s*%(%d+%)', player_color, false)
    seq:clickButton(dataPad, 'Spawn & Move.List', player_color, false)
    seq:waitFrames(200)
    seq:physicsCast(playerArea:castParams(), function(obj)
        return obj.getName() == "Unassigned Dial"
    end)
    seq:waitCondition(function()
            DataPadTest.dropDials(seq.result, playerArea)
        end,
        function()
            return seq.result:allAtRest()
        end)
end

function moveableFilter(obj)
    return obj.locked == false and obj.interactable == true
end

function DataPadTest.dropDials(dials, playerArea)
    dials:forEach(function(dial)
        local shipPos = dial.getPosition() + 3 * playerArea.forward + Vector(0, 5, 0)
        dial.setPositionSmooth(shipPos, true, false)
        Wait.condition(function()
            DataPadTest.assignNearestShip(dial, playerArea.player.color)
        end, function()
            return dials:allAtRest()
        end)
    end)
end

function DataPadTest.assignNearestShip(dial, playerColor)
    local nearest = Global.call("API_FindNearestShip", { object = dial, max_distance = 80 })
    if nearest ~= nil then
        if playerColor == "White" then
            printToAll("Please, pick a color before assigning dials")
        else
            nearest.setVar('owningPlayer', playerColor)
            dial.setVar('playerColor', playerColor)
            dial.setRotation(nearest.getRotation())
            dial.call("assignShip", { ship = nearest })
            dial.call("placeShip", { playerColor })
            Global.call("API_AssignDial", { dial = dial, ship = nearest, player = playerColor })
        end
    end
end

return DataPadTest

end)
__bundle_register("Player.PlayerArea", function(require, _LOADED, __bundle_register, __bundle_modules)
local Transform = require("TTS_lib.Vector.Transform")

PlayerArea = {}
PlayerArea.__index = PlayerArea

function PlayerArea:new(player, layout)
    local self = setmetatable({}, PlayerArea)
    self.player = player
    self.layout = self:layoutKey(layout or self:getCurrentLayout())
    self:calculateHandZoneInfo()
    return self
end

function PlayerArea:layoutKey(layout)
    local layouts = {
        [1] = 'Standard',
        [2] = 'Epic',
        [3] = 'HotAC'
    }

    if type(layout) == "number" then
        layout = layouts[layout]
    end

    return layout
end

function PlayerArea:calculateHandZoneInfo()
    local handTransform = self.player.getHandTransform()
    self.position = handTransform.position + handTransform.forward * self:getScalar()
    self.forward = handTransform.forward
    self.transform = Transform:new(self.position, handTransform.forward)
end

function PlayerArea:getCurrentLayout()
    local layoutController_GUID = "b3992e"
    local layout = getObjectFromGUID(layoutController_GUID)
    if layout then
        local currentLayout = layout.call("getLayoutState")
        return self:layoutKey(currentLayout)
    else
        printToAll("Error: Layout object not found.", Color.Orange)
    end
end

function PlayerArea:getScalar()
    local multipliers = {
        Standard = 18,
        Epic = 19.1,
        HotAC = 14.5
    }

    return multipliers[self.layout] or 18
end

function PlayerArea:translate(objects)
    self.transform:translate(objects)
end

function PlayerArea:castParams()
    return {
        origin = self.position,
        direction = self.forward:copy():rotateOver('y', 180),
        type = 3,
        size = Vector(14, 10, 5),
        orientation = Vector(-1, 0, 0),
        max_distance = 10,
        debug = true
    }
end

return PlayerArea

end)
__bundle_register("TTS_lib.Sequence.Sequence", function(require, _LOADED, __bundle_register, __bundle_modules)
--- @class Sequence
--- A modular framework for managing and executing sequences of tasks in Lua.
--- Provides functionality for step-by-step execution, waiting for conditions, and integration with plugins.
--- @field steps   table[] Holds the sequence of steps (functions) to execute.
--- @field result  any     The return value of the last task function or explicitly set by a step.
--- @field ctx     table   User-defined space for storing intermediate data between steps.
--- @field current number  Index of the current step in the sequence.
--- @field plugins table   Table of registered plugins.
local Sequence = {}
Sequence.__index = Sequence

--- Creates a new Sequence instance.
--- Optionally integrates default plugins if `autoUsePlugins` is true.
--- @param autoUsePlugins boolean: Whether to auto-use common plugins.
--- @return Sequence: A new Sequence instance.
function Sequence:new(autoUsePlugins)
    local seq = setmetatable({ steps = {}, result = nil, ctx = {}, current = 0, plugins = {} }, Sequence)

    if autoUsePlugins then
        -- Automatically registers commonly used plugins.
        seq:usePlugin("Click", require("TTS_lib.Sequence.ButtonClickPlugin"))
        seq:usePlugin("Cast", require("TTS_lib.Sequence.PhysicsCastPlugin"))
    end

    return seq
end

--- Adds a new step to the sequence.
--- Steps are functions that take the sequence instance (`seq`) as their first argument.
--- They are responsible for their own control flow, including assigning `seq.result` and calling `seq:next()`.
--- @param step function: The function to execute as a step.
--- @param ... any: Additional arguments to pass to the step.
function Sequence:addStep(step, ...)
    assert(type(step) == "function", "Expected a function for step, got " .. tostring(step))
    assert(getmetatable(self) == Sequence, "addStep must be called on a Sequence instance.")
    table.insert(self.steps, { func = step, args = { ... } }) -- Stores the step and its arguments.
end

--- Adds a task to the sequence that automatically progresses after execution.
--- Tasks differ from steps in that they do not take `seq` as an argument and automatically advance the sequence after execution.
--- Tasks return values that are automatically assigned to `seq.result`.
--- @param task function: The task function to execute.
--- @param ... any: Additional arguments to pass to the task.
function Sequence:addTask(task, ...)
    assert(type(task) == "function", "Expected a function for task, got " .. tostring(task))
    self:addStep(function(seq, ...)
        seq.result = task(...) -- Executes the task and assigns its return value to seq.result.
        seq:next()             -- Automatically progresses the sequence after the task completes.
    end, ...)
end

--- Advances the sequence to the next step.
--- Executes the current task or step, storing the result in `seq.result` if applicable.
--- Steps handle their own control flow explicitly, while tasks are automatically progressed.
--- @usage seq:next()
function Sequence:next()
    if self.current <= #self.steps then
        local step = self.steps[self.current]    -- Fetches the current step.
        self.current = self.current + 1          -- Moves to the next step.
        step.func(self, table.unpack(step.args)) -- Executes the step and stores the result.
    end
end

--- Starts the sequence from the beginning.
--- Resets the sequence and begins execution from the first step.
function Sequence:start()
    self.current = 1 -- Resets to the first step.
    self:next()      -- Starts execution.
end

--- Adds a step that waits for a condition to be met before progressing.
--- @param runFunc function | nil: A function to execute once the condition is met. (nilable)
--- @param conditionFunc function: The condition function to evaluate.
--- @param timeout number?: The maximum time to wait for the condition (optional).
--- @param timeoutFunc function?: A function to execute if the condition times out (optional).
function Sequence:waitCondition(runFunc, conditionFunc, timeout, timeoutFunc)
    self:addStep(function(seq)
        Wait.condition(function()
            if runFunc then
                runFunc() -- Executes a function once the condition is met.
            end
            seq:next()    -- Advances the sequence.
        end, conditionFunc, timeout, timeoutFunc)
    end)
end

--- Adds a step that waits for a specific number of frames before progressing.
--- Accepts either:
---   - A number (frames to wait), or
---   - A function (callback(seq) to execute after default frames).
--- @param arg1 number|function: Frames or callback function.
--- @param arg2 number?: Frames to wait if `arg1` is a callback.
function Sequence:waitFrames(arg1, arg2)
    local callback = nil
    local frames = nil

    if type(arg1) == "function" then
        callback = arg1
        frames = arg2 or 1 -- Default to 1 frame if no frames are specified
    elseif type(arg1) == "number" then
        callback = nil
        frames = arg1
    else
        error("Invalid argument for waitFrames: Expected number or function.")
    end

    self:addStep(function(seq)
        Wait.frames(function()
            if callback then
                callback(seq) -- Execute the user-defined function
            end
            seq:next() -- Proceed to the next step in the sequence
        end, frames)
    end)
end

--- Integrates a plugin with the sequence, making its methods callable within the sequence.
--- @param name string: The name of the plugin.
--- @param plugin table: A table containing plugin methods.
function Sequence:usePlugin(name, plugin)
    assert(type(plugin) == "table", "Plugin must be a table or a valid module name.")
    self.plugins[name] = plugin
    for method, func in pairs(plugin) do
        assert(type(method) == "string" and type(func) == "function", "Invalid plugin format.")
        -- Wraps plugin methods to integrate seamlessly into the sequence.
        self[method] = function(self, ...)
            self:addStep(func, ...)
        end
    end
end

--- A reusable no-operation sequence instance for testing or placeholders.
Sequence.NoSeq = Sequence:new(false)

return Sequence

end)
__bundle_register("TTS_lib.Sequence.PhysicsCastPlugin", function(require, _LOADED, __bundle_register, __bundle_modules)
local ObjectContainer = require("TTS_lib.Sequence.ObjectContainer")

---@class PhysicsCastPlugin
---A plugin for performing physics-based casting and filtering using ObjectContainer.
---Integrates with the Sequence framework to allow casting operations within sequences.
local PhysicsCastPlugin = {}

-- Define a static empty ObjectContainer instance
local Empty = ObjectContainer:new({})

--- Performs a physics cast and filters the results.
--- Results are stored in `seq.result` as an ObjectContainer.
--- @param seq Sequence: The current sequence instance.
--- @param castParams table: Parameters for the Physics.cast operation.
--- @param filterFunc? function: A filter function to determine which objects to include (optional).
function PhysicsCastPlugin.physicsCast(seq, castParams, filterFunc)
    assert(type(castParams) == "table", "castParams must be a table.")
    filterFunc = filterFunc or function() return true end -- Default no-op filter

    -- Use ObjectContainer for casting and fallback to the static empty instance
    seq.result = ObjectContainer:fromCast(castParams, filterFunc) or Empty
    seq:next() -- Advance the sequence
end

return PhysicsCastPlugin

end)
__bundle_register("TTS_lib.Sequence.ObjectContainer", function(require, _LOADED, __bundle_register, __bundle_modules)
local ObjectContainer = {}
ObjectContainer.__index = ObjectContainer

function ObjectContainer:new(objects)
    return setmetatable({ objects = objects or {} }, ObjectContainer)
end

function ObjectContainer:add(object)
    table.insert(self.objects, object)
end

function ObjectContainer:remove(object)
    for i, obj in ipairs(self.objects) do
        if obj == object then
            table.remove(self.objects, i)
            return
        end
    end
end

function ObjectContainer:getObjects()
    return self.objects
end

function ObjectContainer:filter(predicate)
    local filtered = {}
    for _, obj in ipairs(self.objects) do
        if predicate(obj) then
            table.insert(filtered, obj)
        end
    end
    return ObjectContainer:new(filtered)
end

function ObjectContainer:all(predicate)
    for _, obj in ipairs(self.objects) do
        if not predicate(obj) then
            return false
        end
    end
    return true
end

function ObjectContainer:allAtRest()
    return self:all(function(obj)
        return not obj.isSmoothMoving() and obj.resting and not obj.spawning
    end)
end

function ObjectContainer:move(offset)
    for _, obj in ipairs(self.objects) do
        local newPosition = obj.getPosition() + offset
        obj.setPositionSmooth(newPosition)
    end
end

function ObjectContainer:fromCast(castParams, filterFunc)
    assert(type(castParams) == "table", "castParams must be a table.")
    filterFunc = filterFunc or function() return true end

    local castResult = Physics.cast(castParams)
    local objects = {}
    for _, hit in ipairs(castResult) do
        local obj = hit.hit_object
        if filterFunc(obj) then
            table.insert(objects, obj)
        end
    end
    return ObjectContainer:new(objects)
end

function ObjectContainer:forEach(callback)
    for _, obj in ipairs(self.objects or {}) do
        callback(obj)
    end
end

function ObjectContainer:count()
    return #self.objects
end

-- Metamethod to automatically use tostring in string concatenation
function ObjectContainer:__tostring()
    local objectNames = {}
    for _, obj in ipairs(self.objects) do
        table.insert(objectNames, obj.getName and obj:getName() or tostring(obj))
    end
    return "ObjectContainer: [" .. table.concat(objectNames, ", ") .. "]"
end

-- Enable string concatenation with ObjectContainer
function ObjectContainer:__concat(other)
    return tostring(self) .. tostring(other)
end

return ObjectContainer

end)
__bundle_register("TTS_lib.Sequence.ButtonClickPlugin", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class ButtonClickPlugin
--- A plugin to simulate button clicks in Tabletop Simulator.
--- Allows for automated button interactions as part of a sequence.

--- Warning: Argument passing to a button's click_function is treated as a table of values.
--- This behavior differs from expected direct argument passing.
--- Some modification may be necessary to detect individual arguments versus a table of arguments.

local ButtonClickPlugin = {}

--- Simulates a button click on an object by searching for a button with a specific label pattern.
--- If a matching button is found, it triggers the button's `click_function` with the provided parameters.
--- @param seq Sequence The Sequence instance managing the flow of operations.
--- @param host_obj table The object hosting the buttons to be clicked.
--- @param label_pattern string The pattern to match against button labels.
--- @param player_color string The player's color initiating the click.
--- @param alternate_key boolean|nil Optional alternate key for the button click.
function ButtonClickPlugin.clickButton(seq, host_obj, label_pattern, player_color, alternate_key)
    assert(host_obj, "Host object is nil in clickButton().")
    assert(type(label_pattern) == "string", "Label pattern must be a string.")

    local function findButton(obj, pattern)
        for _, button in ipairs(obj.getButtons() or {}) do
            if string.match(button.label, pattern) then
                return button
            end
        end
        return nil
    end

    local button = nil

    Wait.condition(function()
        if button ~= nil then
            host_obj.call(button.click_function, { host_obj, player_color, alternate_key })
        end
        seq:next()
    end, function()
        button = findButton(host_obj, label_pattern)
        return button ~= nil and (not button.spawning)
    end, 4.0)
end

return ButtonClickPlugin

end)
__bundle_register("Game.StarForge.StarForgeDeduper", function(require, _LOADED, __bundle_register, __bundle_modules)
require("TTS_lib.Util.Table")
local SFLayout = require("Game.StarForge.StarForgeLayout")

local StarForgeDeduper = {
    allObjects = {},
    namedObjects = {},
    unNamedObjects = {},

    -- Add an object to the manager
    addObject = function(self, bag, object)
        local entry = {
            guid = object.guid,
            name = object.name,
            bagGUID = bag.getGUID(),
        }

        if entry.name and entry.name ~= "" then
            if self.namedObjects[entry.name] == nil then
                self.namedObjects[entry.name] = {}
            end
            table.insert(self.namedObjects[entry.name], entry)
        else
            printToAll("Another nameless object.")
            if not self.unNamedObjects[entry.guid] then
                self.unNamedObjects[entry.guid] = {}
            end
            table.insert(self.unNamedObjects[entry.guid], entry)
        end

        self.allObjects[entry.guid] = entry
    end,
    getDups = function(self)
        local dups = {}
        printToAll("looking for dups")
        for name, entries in pairs(self.namedObjects) do
            if #entries > 1 then
                printToAll(name .. " has duplicates", Color.Orange)
                dups[name] = entries
            end
        end
        return dups
    end
}

local scanInfiniteBag = function(infiniteBag)
    StarForgeDeduper.takeObject(infiniteBag, "", function(object)
        StarForgeDeduper:addObject(infiniteBag, object)
        infiniteBag.putObject(object)
    end)
end

local scanMixedBag = function(mixedBag)
    local items = mixedBag.getObjects()

    for _, item in ipairs(items) do
        StarForgeDeduper:addObject(mixedBag, item)
    end
end

StarForgeDeduper.takeObject = function(Bag, guid, callback)
    local guid = guid or ""
    local product = Bag.takeObject({
        position = SFLayout:nextPosition(),
        smooth = false,
        guid = guid,
        callback_function = function(object)
            if callback ~= nil then
                callback(object)
            end
        end
    })
end

StarForgeDeduper.ScanAllBags = function()
    print("Scan All Bags")
    local everything = getObjects()
    for _, object in ipairs(everything) do
        if object.type == "Infinite" then
            scanInfiniteBag(object)
        elseif object.type == "Bag" then
            scanMixedBag(object)
        end
    end
    print("Scan All Bags Done")
end

StarForgeDeduper.LayoutDuplicates = function()
    printToAll("Layout Duplicates")
    SFLayout:reset()
    printToAll("Layout reset")
    local duplicates = StarForgeDeduper:getDups()
    printToAll("we have " .. tostring(#duplicates) .. " duplicates")
    for name, entries in pairs(duplicates) do
        for index, dup in ipairs(entries) do
            local bag = getObjectFromGUID(dup.bagGUID)

            StarForgeDeduper.takeObject(bag, dup.guid)
        end
    end
    printToAll("Layout Duplicates Done")
end

return StarForgeDeduper

end)
__bundle_register("Game.StarForge.StarForgeLayout", function(require, _LOADED, __bundle_register, __bundle_modules)
-- StarForgeLayout.ttslua

StarForgeLayout = {
    epic = { x = -35, y = 2, z = -14 },
    start = { x = -35, y = 2, z = -14 },
    position = { x = 0, y = 0, z = 0 },
    count = 0,
    
    -- Calculate the next position based on count
    -- TODO: Could take the object to be placed and attempt to avoid collisions.
    nextPosition = function(self)
        self.count = self.count + 1
        self.position = {
            x = self.start.x + math.floor(self.count / 10) * 3.5,
            y = self.start.y,
            z = self.start.z + (self.count % 10) * 3
        }
        return self.position
    end,
    reset = function (self)
        self.count = 0
    end
}

return StarForgeLayout

end)
__bundle_register("Game.StarForge.StarForgeScriptManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- This is the Star Forge Script Manager!
-- It will update the behavior of Products.

-- StarForge.ttslua

require("TTS_lib.Util.Table")

--[[
## Star Forge

Utility Object to aid in Game Mod Script Updates. Locating and "sourcing" Objects.
- This should replace the Accessories Bag or at least provide a Facade in front of it
- Extract and lay out all scripted objects
    - Possibly be sensitive to HotAC vs Standard Layout vs Epic Layout
    - Reset each script back to itself to force an update.
    - Keep track of where each object came from to survive a save and reload.

### Steps:

1. **Extract All Objects**:
    - Trigger a context menu to "Take Everything Out," which will:
    1. Lay out all scripted objects.
    2. Keep track of which Bag each object came from, as they need to be returned to their original bag.
    3. If the object is a multi-state object:
        - Keep track of the initial state (baseState).
        - Clone the object for each state and stack them vertically.
        - This allows VSCode to update the alternative state's scripts.

2. **Save and Reload**:
    1. Save the game via TTS UI.
    2. Load the game via TTS UI.
    3. Send all scripts from VSCode.

3. **Put Everything Away**:
    - Trigger a context menu to "Put Everything Away," which will:
    - For each object that was taken out:
        1. Reset the bag it came from.
        2. Put the object back.
        3. If the object is the initial state of a multi-state object:
            - Traverse all initial state's copies and have them:
                - Change the baseState object to match their state.
                - Set the baseState's script for that state to the new one from the extra state object.
                - Destroy the extra state object.
            - Set the initial state object back to its baseState.
        4. Put the initial state object back in the bag it came from.
### Requirements
- Each object to be produced needs a unique name.
]]
local StarForgeScriptManager = {
    objects = {},

    -- Add an object to the manager
    addObject = function(self, bag, object)
        local entry = {
            guid = object.getGUID(),
            name = object.getName(),
            bagGUID = bag.getGUID(),
            stateId = object.getStateId(),
            states = {}, -- Table to hold states if it's a multi-state object
        }

        self.objects[object.getGUID()] = entry
    end,
    -- Add a state to an existing multi-state object
    addState = function(self, multiObject, stateClone)
        if multiObject == stateClone then
            return
        end

        table.insert(self.objects[multiObject.getGUID()].states, {
            stateId = stateClone.getStateId(),
            guid = stateClone.getGUID(),
            name = stateClone.getName()
        })
    end,
    reset = function(self)
        self.objects = {}
    end
}

local SFLayout = require("Game.StarForge.StarForgeLayout")

local layoutInfiniteBag = function(infiniteBag)
    StarForgeScriptManager.takeObject(infiniteBag, "")
end

local layoutMixedBag = function(mixedBag)
    local items = mixedBag.getObjects()

    for i = #items, 0, -1 do
        local item = items[i]
        if item and item.lua_script ~= "" then
            StarForgeScriptManager.takeObject(mixedBag, item.guid)
        end
    end
end

--[[
## Extract All Products
Scan all game objects
- if it's an Infinite Bag, find out of what and register the object in the bag.
- if it's an Mixed Bag, find out of what and register the objects in the bag.
- if the Objects are Multi-state, consider registering each state with a "<key>.#".
]]
StarForgeScriptManager.TakeEveryThingOut = function()
    StarForgeScriptManager:reset()
    printToAll("Extract All Products")
    local everything = getObjects()
    for _, object in ipairs(everything) do
        if object.type == "Infinite" then
            layoutInfiniteBag(object)
        elseif object.type == "Bag" then
            layoutMixedBag(object)
        end
    end
    printToAll("Extract All Products Done")
end

StarForgeScriptManager.takeObject = function(Bag, guid)
    local guid = guid or ""
    local product = Bag.takeObject({
        position = SFLayout:nextPosition(),
        smooth = false,
        guid = guid,
        -- callback_function = function(obj) printToAll("We have Call Back!", Color.Orange) end
    })

    StarForgeScriptManager:addObject(Bag, product)

    if product.getStateId() ~= -1 then
        stackMultiStateObjects(product)
    end
end

stackMultiStateObjects = function(multiObject)
    local pos = multiObject.getPosition()
    local allStates = multiObject.getStates()
    local lastObject = multiObject
    for _, state in ipairs(allStates) do
        Wait.condition(function()
            pos.y = pos.y + 1
            local dup = multiObject.clone({ position = pos })
            dup.setPosition(pos)
            dup.setLock(true)
            Wait.condition(function()
                dup = dup.setState(state.id)
                dup.setLock(true)
                lastObject = dup
                StarForgeScriptManager:addState(multiObject, lastObject)
            end, function()
                return not dup.spawning
            end)
        end, function()
            return not lastObject.spawning
        end)
    end
end

StarForgeScriptManager.dumpProducts = function()
    printToAll("Dump Products", Color.Orange)
    table.print_r(StarForgeScriptManager.objects)
    printToAll("Dump Products Done", Color.Orange)
end

function putObjectBackInBag(bag, product)
    if bag then
        if bag.type == "Infinite" then
            bag.reset()
        end
        if product and not product.isDestroyed() then
            if product.type == "Deck" and product.is_face_down == false then
                product.setRotation(product.getRotation() + Vector(0, 0, 180))
            end
            bag.putObject(product)
        end
    end
end

function copyStateScript(index, entry, multiObject, callback)
    if index == 0 then
        multiObject = multiObject.setState(entry.stateId)
        Wait.condition(function()
            callback(multiObject)
        end, function()
            return multiObject ~= nil and not multiObject.spawning
        end)
        return
    end
    local stateEntry = entry.states[index]
    multiObject = multiObject.setState(stateEntry.stateId)
    local stateCopy = getObjectFromGUID(stateEntry.guid)
    Wait.condition(function()
        local script = stateCopy.getLuaScript() or ""
        multiObject.setLuaScript(script)
        destroyObject(stateCopy)
        table.remove(entry.states, index)
        return copyStateScript(index - 1, entry, multiObject, callback)
    end, function()
        local isMultiObjectReady = multiObject ~= nil and not multiObject.spawning
        local isStateReady = stateCopy ~= nil and not stateCopy.spawning
        return isMultiObjectReady and isStateReady
    end)
end

StarForgeScriptManager.PutEverythingAway = function()
    printToAll("Put Everything Away", Color.Orange)
    local products = StarForgeScriptManager.objects -- #654
    for guid, entry in pairs(products) do
        local bag = getObjectFromGUID(entry.bagGUID)
        local product = getObjectFromGUID(entry.guid)
        if product ~= nil and product.getStateId() ~= -1 then
            copyStateScript(#entry.states, entry, product, function(obj)
                putObjectBackInBag(bag, obj)
            end)
        else
            Wait.condition(function()
                putObjectBackInBag(bag, product)
            end, function()
                local isBagReady = bag ~= nil and not bag.spawning
                local isProductReady = product ~= nil and not product.spawning
                return isBagReady and isProductReady
            end)
        end
    end
    printToAll("Everything Put Away", Color.Orange)
end

return StarForgeScriptManager

end)
return __bundle_require("Star Forge.5500bc.lua")