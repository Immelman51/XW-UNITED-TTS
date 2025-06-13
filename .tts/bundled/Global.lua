-- Bundled by luabundle {"rootModuleName":"Global.-1.lua","version":"1.6.0"}
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
__bundle_register("Global.-1.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Global")
end)
__bundle_register("Global", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: https://github.com/tjakubo2/TTS_xwing
--
-- Based on a work of: Flolania, Hera Vertigo
-- ~~~~~~

-- ~~~~~~
-- Code contributions
--  - Characted width data: Indimeco
--  - https://github.com/Indimeco/Tabletop-Simulator-Misc
-- ~~~~~~

-- Should the code execute print functions or skip them?
-- This should be set to false on every release
print_debug = false
cast_debug = false

Accessories_Bag_GUID = '53ad3d'
CompositeBase_GUID = '8c3322'
Fuse_Bag_GUID = '568727'
Obstacle_Bag_GUID = '203cb8'
Straight_1_Bag_GUID = '637ad7'

TTS_print = print
function print(...)
    if print_debug == true then
        TTS_print(table.unpack({ ... }))
    end
end

function getSelectingPlayers(obj)
    local selectingPlayers = {}
    for _, p in ipairs(Player.getPlayers() or {}) do
        for _, o in ipairs(p.getSelectedObjects() or {}) do
            if o == obj then
                table.insert(selectingPlayers, p)
                break
            end
        end
    end
    return selectingPlayers
end

require("vscode/console")

function submerge(object, originalPos)
    if originalPos.y < 0 then
        object.setPosition(originalPos)
        object.setLock(true)
    end
end

function surface(object)
    local originalPos = object.getPosition()
    if originalPos.y < 0 then
        local sPos = originalPos:copy()
        sPos.y = -sPos.y
        object.setPosition(sPos)
        object.setLock(true)
    end
    return originalPos
end

function showMe(arg)
    local guid = type(arg) == "table" and arg[1] or arg
    local object = getObjectFromGUID(guid)
    if object == nil then
        print("Object not found.")
        return
    end
    local origPos = surface(object)
    local origColor = object.getColorTint()
    -- Highlight the object by changing its color tint
    object.setColorTint({ r = 1, g = 0, b = 0 }) -- Set to red for visibility

    -- Move the camera to focus on the object
    -- Adjusting the parameters might be necessary based on your specific use case
    local position = object.getPosition()
    position.y = position.y + 5 -- Raise the camera slightly above the object
    for _, player in ipairs(Player.getPlayers()) do
        player.lookAt({
            position = position,
            pitch = 60,   -- Angle of the camera looking down at the object
            distance = 10 -- Distance from the object (adjust as needed)
        })
    end

    -- Optionally, reset the color after a delay
    Wait.time(function()
        object.setColorTint(origColor) -- Reset to white or original color
        submerge(object, origPos)
    end, 5)                            -- Delay in seconds before the color reset happens
end

-- Standard libraries extentions
require("TTS_Lib.Util.Math")
require("TTS_Lib.Util.Table")
require("TTS_Lib.Util.String")

-- Vector manipulation
local Vect = require("TTS_Lib.Vector.Vector")

-- Standard event handling
local EventSub = require("TTS_Lib.EventSub.EventSub")

-- Object type abstraction
ObjType = require("TTS_Lib.ObjType.ObjType")

-- Save/load management
local SaveManager = require("TTS_Lib.SaveManager.SaveManager")

-- Component sizes, unit conversion methods
local Dim = require("Dim")

-- AI behaviour sets
local BehaviourDB = require("Game.HotAC.AI.BehaviourDB")

-- Dice control and dice_statistics
local DiceControlModule = require("Game.Component.Dice.DiceControl")

-- Arc checks
ArcCheck = require("Game.Mechanic.ArcCheck")
ArcCheck.Initialize()
CheckArc = ArcCheck.CheckArc

-- Ship proxy
local ShipProxyModule = require("Ship.ShipProxy")

-- Ship verification
local ShipVerification = require("Ship.ShipVerification")

-- ContextGui
local ContextGui = require("Player.ContextGui")

-- ConfigManager
local ConfigManager = require("Player.ConfigManager")

HotkeyModule = require("Player.HotkeyManager")
PlayerEventModule = require("Player.PlayerActionModule")
DialManagerModule = require("Dial.DialManager")
ShipProximityHider = require("Ship.ShipProximityHider")
StreamManagerModule = require("Player.StreamManager")
--StreamManagerModule.SetUI(self)
--StreamManagerModule.AddPresentation("Purple", "left")
--StreamManagerModule.AddPresentation("Blue", "right")

local GlobalGuiControl = require("Player.GlobalGuiControl")
local MoveData = require("Game.Mechanic.Movement.MoveData")
local AnnModule = require("Player.Announcements")
Maneuver = require("Game.Mechanic.Movement.Maneuver")
Relocator = Maneuver:new()

-- Modules API, must be loaded last
require("API")

function onSave()
    return SaveManager.onSave()
end

--------
-- MISC FUNCTIONS

-- Dumbest TTS issue ever workaround
function TTS_Serialize(pos)
    return { pos[1], pos[2], pos[3] }
end

ObjType.AddType('ship', function(obj)
    return (obj ~= nil) and (((obj.tag == 'Figurine') and (obj.getVar('__XW_Ship') == true)) or obj.hasTag('Ship'))
end)
ObjType.AddType('token', function(obj)
    return (obj.tag == 'Chip' or obj.tag == 'Coin' or (obj.getVar('__XW_Token') and obj.getVar('__XW_TokenIdle')))
end)
ObjType.AddType('dial', function(obj)
    return (obj.tag == 'Card' and XW_cmd.CheckCommand(obj.getDescription()) == 'move')
end)


-- Dud function for info buttons and not yet written sections where Lua complains about no code
function dummy()
    return
end

-- END MISC FUNCTIONS
--------


--------
-- COMMAND HANDLING MODULE
-- Sanitizes input (more like ignores anything not explicitly allowed)
-- Allows other modules to add available commands and passes their execution where they belong

XW_cmd = {}
XW_cmd.commandLUT = {}

-- Table of valid commands: their patterns and general types
XW_cmd.ValidCommands = {}

-- Add given regen expression as a valid command for processing
XW_cmd.AddCommand = function(cmdRegex, type)
    -- When adding available commands, assert beggining and end of string automatically
    if cmdRegex:sub(1, 1) ~= '^' then
        cmdRegex = '^' .. cmdRegex
    end
    if cmdRegex:sub(-1, -1) ~= '$' then
        cmdRegex = cmdRegex .. '$'
    end
    table.insert(XW_cmd.ValidCommands, { string.lower(cmdRegex), type })
end

-- Check if command is registered as valid
-- If it is return its type identifier, if not return nil
XW_cmd.CheckCommand = function(cmd)
    -- Trim whitespaces
    cmd = string.lower(cmd:match("^%s*(.-)%s*$"))
    local type = nil
    if XW_cmd.commandLUT[cmd] then
        return XW_cmd.commandLUT[cmd]
    end
    -- Resolve command type
    for k, pat in pairs(XW_cmd.ValidCommands) do
        if cmd:match(pat[1]) ~= nil then
            type = pat[2]
            break
        end
    end
    XW_cmd.commandLUT[cmd] = type
    return type
end

-- (special function)
-- Purge all save data (everything that goes to onSave)
XW_cmd.AddCommand('purgeSave', 'special')
XW_cmd.PurgeSave = function()
    MoveModule.moveHistory = {}
end

-- (special function)
-- Print ship hitory
XW_cmd.AddCommand('hist', 'special')
XW_cmd.ShowHist = function(ship)
    MoveModule.PrintHistory(ship)
end

-- (special function)
-- Check for typical issues with a ship
XW_cmd.AddCommand('diag', 'special')
XW_cmd.Diagnose = function(ship)
    -- Check and unlock XW_cmd lock if it's on
    local issueFound = false
    if ObjType.IsOfType(ship, 'ship') ~= true then
        return
    end
    if XW_cmd.isReady(ship) ~= true then
        XW_cmd.SetReady(ship)
        printToAll(ship.getName() .. '\'s deadlock resolved', { 0.1, 0.1, 1 })
        issueFound = true
    end
    -- Delete lingering buttons
    if ship.getButtons() ~= nil then
        ship.clearButtons()
        printToAll(ship.getName() .. '\'s lingering buttons deleted', { 0.1, 0.1, 1 })
        issueFound = true
    end
    -- If ship has unrecognized model and said that before, remind
    if ship.getVar('missingModelWarned') == true then
        printToAll(
            'I hope you do remember that I told you about ' ..
            ship.getName() .. '\'s model being unrecognized when it was first moved/used', { 0.1, 0.1, 1 })
        issueFound = true
    end
    -- No issues found
    if issueFound ~= true then
        printToAll(ship.getName() .. ' looks OK', { 0.1, 1, 0.1 })
    end
end

-- Process provided command on a provided object
-- Return true if command has been executed/started
-- Return false if object cannot process commands right now or command was invalid
XW_cmd.Process = function(obj, cmd)
    -- Trim whitespaces
    cmd = cmd:match("^%s*(.-)%s*$")

    -- Resolve command type
    local type = XW_cmd.CheckCommand(cmd)

    -- Process special commands without taking lock into consideration
    if type == nil then
        return false
    elseif type == 'special' then
        if cmd == 'diag' then
            XW_cmd.Diagnose(obj)
        elseif cmd == 'purgeSave' then
            XW_cmd.PurgeSave()
        elseif cmd == 'hist' then
            XW_cmd.ShowHist(obj)
        end
    end

    -- Return if not ready, else process
    if XW_cmd.isReady(obj) ~= true then
        return false
    end

    if type == 'demoMove' then
        MoveModule.DemoMove(cmd:sub(3, -1), obj)
    elseif type == 'move' or type == 'actionMove' then
        local info = MoveData.DecodeInfo(cmd, obj)
        MoveModule.PerformMove(cmd, obj)
    elseif type == 'historyHandle' then
        if cmd == 'q' or cmd == 'undo' then
            MoveModule.UndoMove(obj)
        elseif cmd == 'z' or cmd == 'redo' then
            MoveModule.RedoMove(obj)
        elseif cmd == 'keep' then
            MoveModule.SaveStateToHistory(obj, false)
        elseif cmd:sub(1, 8) == 'restore#' then
            local keyNum = tonumber(cmd:sub(9, -1))
            MoveModule.Restore(obj, keyNum)
        end
    elseif type == 'dialHandle' then
        if cmd == 'sd' then
            DialModule.SaveNearby(obj)
        elseif cmd == 'rd' then
            DialModule.RemoveSet(obj)
        end
    elseif type == 'rulerHandle' then
        RulerModule.ToggleRuler(obj, string.upper(cmd))
    elseif type == 'action' then
        DialModule.PerformAction(obj, cmd)
    elseif type == 'bombDrop' then
        BombModule.ToggleDrop(obj, cmd)
    elseif type == 'StrikeAI' then
        AIModule.EnableStrikeAI(obj, cmd)
    elseif type == 'AI' then
        AIModule.EnableAI(obj, cmd)
    elseif type == 'rotate' then
        DialModule.RotateArc(obj, cmd)
    elseif type == 'turretarc' then
        DialModule.TurretArc(obj, cmd)
    elseif type == 'fixedarc' then
        DialModule.FixedArc(obj, cmd)
    elseif type == 'renameShip' then
        if obj.getVar('SetName') then
            obj.call('SetName', { name = cmd:match("name%s*(.*)") })
        end
    elseif type == 'changeInitiative' then
        if obj.getVar('SetInitiative') then
            obj.call('SetInitiative', { init = cmd:sub(5, -1) })
        end
    end
    obj.setDescription('')
    return true
end

-- Is object not processing some commands right now?
XW_cmd.isReady = function(obj)
    return (obj.getVar('cmdBusy') ~= true)
end

-- Flag the object as processing commands to ignore any in the meantime
XW_cmd.SetBusy = function(obj)
    if XW_cmd.isReady(obj) ~= true then
        print('Nested process on ' .. obj.getName())
    end
    obj.setVar('cmdBusy', true)
end

-- Flag the object as ready to process next command
XW_cmd.SetReady = function(obj)
    if XW_cmd.isReady(obj) == true then
        print('Double ready on ' .. obj.getName())
    end
    obj.setVar('cmdBusy', false)
end

--------
-- MOVEMENT DATA MODULE
-- Stores and processes data about moves
-- NOT aware of any ship position, operation solely on relative movements
-- Used for feeding data about a move to a higher level movement module
-- Exclusively uses milimeters and degrees for values, needs external conversion

-- Possible commands supported by this module
XW_cmd.AddCommand('[sk][012345][r]?', 'move')    -- Straights/Koiograns + stationary moves
XW_cmd.AddCommand('b[rle][0123][strz]?', 'move') -- Banks + segnor and reverse versions
XW_cmd.AddCommand('t[rle][01234][srfbtz]?[t]?', 'move')

XW_cmd.AddCommand('r[rle][123]?', 'actionMove')         --New Roll Done
XW_cmd.AddCommand('v[rle][fb][123]?', 'actionMove')     --New ViperRoll
XW_cmd.AddCommand('vt[rle][fb][123]?', 'actionMove')    -- New viper roll using turn template
XW_cmd.AddCommand('c[srle][123]?', 'actionMove')        --New Cloak side
XW_cmd.AddCommand('e[srle][fbrle][123]?', 'actionMove') --New Echo Cloack


XW_cmd.AddCommand('x[rle][fb]?', 'actionMove')  -- Barrel rolls
XW_cmd.AddCommand('s[12345]b', 'actionMove')    -- Boost straights
XW_cmd.AddCommand('b[rle][123]b', 'actionMove') -- Boost banks
XW_cmd.AddCommand('t[rle][123]b', 'actionMove') -- Boost turns
XW_cmd.AddCommand('a[12]', 'actionMove')        -- Adjusts

--XW_cmd.AddCommand('c[srle]', 'actionMove')      -- Decloaks side middle + straight
--XW_cmd.AddCommand('c[rle][fb]', 'actionMove')   -- Decloaks side forward + backward
--XW_cmd.AddCommand('ch[rle][fb]', 'actionMove')  -- Echo's bullshit
--XW_cmd.AddCommand('chs[rle]', 'actionMove')     -- Echo's bullshit, part 2
--XW_cmd.AddCommand('vr[rle][fb]', 'actionMove')  -- StarViper Mk.II rolls

XW_cmd.AddCommand('name[ *]*[-a-zA-Z" %d]*', 'renameShip')
XW_cmd.AddCommand('init[ ]?[01234567]', 'changeInitiative')

-- AI Module:
test_AI = false
AIModule = {}

-- 2000mm is the length between opposite corners of an epic table.
AIModule.max_distance = 2000

-- Information about the most recently executed maneuver by an AI ship. This is
-- stored just before we move the ship, and it used when the ship comes to rest
-- and the callback is fired. Yes, this is a bit of a hack, and yes, I'd love to
-- do it a better way.
AIModule.current_move = {}
AIModule.current_move.in_progress = false
AIModule.current_move.Reset = function()
    AIModule.current_move.take_action = false
    AIModule.current_move.move_code = nil
    AIModule.current_move.collision = false
    AIModule.current_move.difficulty = nil
    AIModule.current_move.obstacle = false
    AIModule.current_move.stress_count = 0
    AIModule.current_move.is_ionised = false
    AIModule.current_move.target = nil
    AIModule.current_move.probes = {}
    AIModule.current_move.action_stack = {}
    AIModule.current_move.actions = {}
end
AIModule.current_move.Reset()



-- Possible commands supported by the AI module
XW_cmd.AddCommand('ai', 'AI')                    -- Enables the AI on the selected ship
XW_cmd.AddCommand('[sS]trike[ ]*.*', 'StrikeAI') -- List of Strike AI Targets

-- Description function to add the AI functions to a ship
AIModule.EnableAI = function(ship, command)
    if not ship.getVar('isAi') then
        ship.setVar('isAi', true)
        ship.AddContextMenuItem("AI move and action",
            function(argument)
                Global.call("PerformAIManeuver", { ['ship'] = ship, ['take_action'] = true })
            end, false)
        ship.AddContextMenuItem("AI move only",
            function(argument)
                Global.call("PerformAIManeuver", { ['ship'] = ship, ['take_action'] = false })
            end, false)
    end
end

-- This function is intended to parse a comma-separated list of targets'
-- name or guid and update the ship's Strike Targets table to store those strings.
AIModule.EnableStrikeAI = function(ship, cmd)
    --  cmd = "strike guid1,guid2,name3,name4"
    AIModule.EnableAI(ship, 'AI')
    local pattern = '[sS]trike[ ]*(.*)' -- Captures the list after 'strike '

    local targetsString = cmd:match(pattern)
    if targetsString then
        local targets = {}
        for arg in targetsString:gmatch("([^,]+)") do
            -- Split by comma
            local target = arg:match("^%s*(.-)%s*$") -- Trim spaces from each target
            if target ~= "" then
                -- Ensure no empty strings are added
                table.insert(targets, target)
            end
        end

        print("target list: " .. table.concat(targets, ", ")) -- Output for verification

        -- Check if any valid targets were added
        if #targets > 0 then
            ship.setTable('StrikeTargets', targets)
            print("Strike Targets set for " .. ship.getName() .. ": " .. table.concat(targets, ", "))
        else
            print("No valid targets specified for " .. ship.getName())
            ship.setTable('StrikeTargets', nil)
        end
    else
        printToAll("Invalid format or no targets specified.", Color.Orange)
        ship.setTable('StrikeTargets', nil)
    end
end

-- Sanity check, make sure that all the moves for this ship are actually
-- possible. It won't fix every issue but it'll find most typos. This is not
-- called except when debugging.
AIModule.ValidateMoveTables = function(ship)
    local ship_id = ship.getTable('Data')['shipId']
    local behaviour = BehaviourDB.GetRuleSet().GetShipBehaviour(ship)

    for arc, range_tables in pairs(behaviour.move_table) do
        for range, move_table in pairs(range_tables) do
            for roll, move_code in pairs(move_table) do
                if AIModule.GetMoveDifficulty(ship, move_code) == nil then
                    print("Couldn't find maneuver " ..
                        move_code ..
                        " from ship " ..
                        tostring(ship_id) ..
                        "'s move table. Arc: " .. arc .. ", range: " .. range .. ", roll: " .. tostring(roll))
                end
            end
        end
    end
end

--[[ AI target selection

Target selection is the simplest of the AI submodules. It consists of a set of
functions for different selection types, each of which takes the querying ship
and returns a target ship. There are also some helper methods for filtering
targets by various metrics.
]]

-- Target selection functions. These take a ship, and return a target ship
AIModule.TargetSelectionFunctions = {}
AIModule.TargetSelectionFunctions.ClosestInArc = function(ship)
    local targets = AIModule.GetSortedTargetsInArc(ship)

    -- Get the first ship as it's already been sorted by distance
    for i, target in pairs(targets) do
        return target.ship
    end

    return nil
end

AIModule.TargetSelectionFunctions.Closest = function(ship)
    local potential_targets = ArcCheck.GetPotentialTargets(ship, AIModule.max_distance)

    local closest_distance = nil
    local closest_target = nil
    for i, target in pairs(potential_targets) do
        local distance = Vect.Length(ship.getPosition() - target.GetPosition())
        if closest_distance == nil or distance < closest_distance then
            closest_distance = distance
            closest_target = target
        end
    end

    return closest_target
end

AIModule.TargetSelectionFunctions.LockedInRange = function(ship)
    local potential_targets = AIModule.GetSortedTargetsInArc(ship, 'all')
    potential_targets = table.sieve(potential_targets, AIModule.FilterInRange)

    local closest_distance = nil
    local closest_target = nil
    for i, target in pairs(potential_targets) do
        -- Is this ship locked by us?
        if AIModule.HasTargetLockOnShip(ship, target.ship) then
            local distance = Vect.Length(ship.getPosition() - target.ship.GetPosition())
            if closest_distance == nil or distance < closest_distance then
                closest_distance = distance
                closest_target = target.ship
            end
        end
    end

    return closest_target
end

AIModule.TargetSelectionFunctions.ClosestInArcLowerInitiative = function(ship)
    local initiative = ship.getTable('Data')['initiative']
    local targets = AIModule.GetSortedTargetsInArc(ship)

    -- Get the first ship with a lower initiative as it's already been sorted by
    -- distance.
    for i, target in pairs(targets) do
        if (target.ship.getTable('Data')['initiative'] < initiative) then
            return target.ship
        end
    end

    return nil
end

-- Only choose ships that are in arc and between ranges 1-3
AIModule.FilterInArc = function(el)
    if el.in_arc == false then
        return false
    end

    return true;
end

-- Only choose ships that are between range one and three
AIModule.FilterInRange = function(el)
    if el.closest.range < 1 or el.closest.range > 3 then
        return false
    end

    return true;
end

-- Assumed to have been filtered first
AIModule.SortTargetsByAIDesirability = function(e1, e2)
    if e1.closest ~= nil and e2.closest ~= nil then
        if e1.closest.length < e2.closest.length then
            return true
        elseif e1.closest.length > e2.closest.length then
            return false
        end
    end

    return e1.ship.getGUID() > e2.ship.getGUID()
end

AIModule.GetSortedTargetsInArc = function(ship, arc)
    local targets = ArcCheck.GetTargetsInRelationToArc(ship, arc or 'front')
    targets = table.sieve(targets, AIModule.FilterInArc)
    targets = table.sieve(targets, AIModule.FilterInRange)
    table.sort(targets, AIModule.SortTargetsByAIDesirability)
    return targets
end

AIModule.HasTargetLockOnShip = function(locking_ship, locked_ship)
    local lock_tokens = locked_ship.call("GetTokens", { type = "targetLock" })
    for j, token in pairs(lock_tokens or {}) do
        if token.GetName() == locking_ship.GetName() then
            -- TODO: this really should be guid
            return true
        end
    end

    return false
end

AIModule.IsStrikeTarget = function(ship, target_ship)
    if (ship == nil or target_ship == nil) then
        return false;
    end

    -- Only Strike AI ships have Strike Targets defined
    local strikeTargets = ship.getTable('StrikeTargets') or {}

    local targetName = target_ship.getName()
    local targetGUID = target_ship.getGUID()

    -- Check if the target is in the list of strike targets by name or GUID
    for _, nameOrGUID in ipairs(strikeTargets) do
        if nameOrGUID == targetName or nameOrGUID == targetGUID then
            return true -- Found the designated strike target
        end
    end

    return false -- No match found
end

AIModule.IsStrikeShip = function(ship)
    local strikeTargets = ship.getTable('StrikeTargets')
    local isStrikeAI = strikeTargets ~= nil and next(strikeTargets) ~= nil
    return isStrikeAI
end

-- This function checks if a target lock action should be skipped based on Strike AI
AIModule.SkipTargetLock = function(locking_ship, target_ship)
    -- Only Strike AI ships have Strike Targets defined
    local isStrikeAI = AIModule.IsStrikeShip(locking_ship)

    -- Check whether the target is in the ship's list of designated strike targets
    local isStrikeAITarget = AIModule.IsStrikeTarget(locking_ship, target_ship)

    -- Skip target lock as it's not a designated strike target
    return isStrikeAI and not isStrikeAITarget
end

AIModule.TargetForStrikeAI = function(ship)
    local isStrikeAI = AIModule.IsStrikeShip(ship)
    if not isStrikeAI then
        -- only Strike AI ships run this targeting logic
        print("This is not a Strike AI Ship. Abort special targeting.")
        return nil
    end
    print("This is a Strike AI Ship. Using Strike targeting.")

    local strikeTargetNames = ship.getTable('StrikeTargets') or {}

    if #strikeTargetNames == 0 then
        print("No Strike targets defined for " .. ship.getName())
        return nil
    end

    -- Get potential_targets as a table with: distance, arc, and ship.
    local potential_targets = ArcCheck.GetTargetsInRelationToArc(ship, "all", nil, 9, false)

    -- Extract from potential targets only those listed as Strike Targets
    local strike_targets = {}
    for _, target in ipairs(potential_targets) do
        if (AIModule.IsStrikeTarget(ship, target.ship)) then
            -- Give preference to an already locked target
            if (AIModule.HasTargetLockOnShip(ship, target.ship)) then
                return target.ship
            end
            table.insert(strike_targets, target)
        end
    end

    -- Sort the Strike Targets by distance to the Strike AI ship
    table.sort(strike_targets, AIModule.SortTargetsByAIDesirability)

    -- Return the closest Strike Target, if any
    if #strike_targets > 0 then
        return strike_targets[1].ship
    end
    return nil
end


--[[ AI maneuver selection

The maneuver selection is the main submodule of the AI, as well as the one that
ties most of the others together. It is home to one of the entry points,
"PerformAIManever". The main function, AIModule.PerformManeuver, uses the
target selection functions to pick a target, then plots a maneuver based on
the move tables in BehaviourDB.ttslua. It also cover stress, ion, and obstacle
avoidance.

Worth noting is that due to having to wait for ships to finish moving, part of
the functionality of AIModule.PerformManeuver had to be split out to a callback
function, AIModule.ManeuverPostShipRest. This handles everything after the
maneuver is executed, including calling the action submodule.

It also includes various helper functions for searching through and transforming
manveuvers.
]]
function PerformAIManeuver(args)
    local ship = args.ship
    local take_action = args.take_action

    AIModule.PerformManeuver(ship, take_action)
end

AIModule.PerformManeuver = function(ship, take_action)
    if AIModule.current_move.in_progress then
        printToAll("Can't perform AI maneuver while another ship is moving.", color(1.0, 1.0, 0.2, 0.9))
        return
    end

    --AIModule.ValidateMoveTables(ship)
    AIModule.current_move.Reset()
    AIModule.current_move.stress_count = TokenModule.GetShipTokenCount(ship, "Stress")
    AIModule.current_move.take_action = take_action
    local stress = AIModule.current_move.stress_count > 0

    local rule_set = BehaviourDB.GetRuleSet()

    local ship_id = ship.getTable('Data')['shipId']
    local ship_behaviour = rule_set.GetShipBehaviour(ship)

    if ship_behaviour ~= nil then
        printToAll('Performing AI routine for ' .. ship.GetName(), color(1.0, 1.0, 0.2, 0.9))
        local move_code = nil

        -- Find this ship's target.
        local target_ship = AIModule.TargetForStrikeAI(ship)
        if (target_ship == nil) then
            for _, target_selection_function in ipairs(ship_behaviour.target_selection) do
                target_ship = AIModule.TargetSelectionFunctions[target_selection_function](ship)
                if target_ship ~= nil then
                    break
                end
            end
        end
        AIModule.current_move.target = target_ship

        -- Check if we're ionised.
        local is_ionised = AIModule.IsIonised(ship)
        AIModule.current_move.is_ionised = is_ionised

        if target_ship == nil then
            -- TODO: This is undefined behaviour, and highly unlikely to happen.
            -- Should it default to a 2 straight?
            printToAll('Failed to find target')
        elseif is_ionised == true then
            move_code = 's1'
            printToAll('Ionised, skipping movement selection')
        else
            -- Find out the arc that the target is in.
            local target_arc = nil
            local arc_parts = nil

            local ship_size = ship.getTable("Data").Size or 'small'
            if rule_set.usesBullseyeArc then
                -- First do a check to see if the ship is in our bullseye.
                -- Move the bullseye position ahead because it's in the middle of
                -- range ruler rather than one end. Could this be moved into the
                -- GetBullseyeTargets function?
                local bullseye_position = vector(ArcCheck.bullseye_data.pos[ship_size][1],
                    ArcCheck.bullseye_data.pos[ship_size][2],
                    ArcCheck.bullseye_data.pos[ship_size][3] + Dim.Convert_mm_igu(AIModule.max_distance / 2) -
                    (ArcCheck.bullseye_data.size[3] / 2))
                local bullseye_targets = ArcCheck.GetBullseyeTargets(ship, bullseye_position, AIModule.max_distance)
                for i, bullseye_target in pairs(bullseye_targets) do
                    if bullseye_target == target_ship then
                        target_arc = 'bullseye'
                        arc_parts = { 'front' }
                        break
                    end
                end
            end

            if target_arc == nil then
                -- We have our target ship. Now we do some vector maths to get
                -- the angle pointing from our ship to the target ship.
                local ship_facing = Vect.RotateDeg({ 0, 0, -1 }, ship.GetRotation().y)
                local ship_to_target = target_ship.GetPosition() - ship.getPosition()
                local angle_to_target = Vect.AngleDeg(ship_facing, ship_to_target)

                -- angleToTarget is normalised between 0 and 180, to work out if
                -- if it's pointing to our left or our right we need to get the
                -- dot product of the shipToTarget vector and the tangent to our
                -- facing.
                local ship_facing_tangent = { ship_facing[3], 0, -ship_facing[1] }
                local tangent_dot_product = Vect.DotProd(ship_to_target, ship_facing_tangent)
                if tangent_dot_product < 0 then
                    angle_to_target = angle_to_target * -1
                end

                arc_result = rule_set.degreesToArc(angle_to_target)
                target_arc = arc_result.target_arc
                arc_parts = arc_result.arc_parts
            end

            -- Find the range bracket - one of closing, fleeing, distant, or
            -- stress.
            local range_bracket = nil
            if stress then
                range_bracket = 'stress'
                printToAll(' Selected target: ' ..
                    target_ship.getName() .. ', in the ' .. target_arc .. ' arc, while stressed.')
            else
                local target_range = nil
                -- Find the range, if we haven't got it already.
                -- TODO: If a ship is at range 0, then treat it as range 1 and
                -- behind our ship. (pg 19, "Touching")
                if target_range == nil then
                    -- TODO: Wrap up this code in a re-useable function
                    local own_line_segments = {}
                    for i, arc in ipairs(arc_parts) do
                        local segments = ArcCheck.GetOwnArcLineSegments(ship,
                            ArcCheck.arc_line_segments[ship_size][arc]["segments"])
                        for k, segment in ipairs(segments) do
                            table.insert(own_line_segments, segment)
                        end
                    end

                    local target_line_segments = {}
                    for i, arc in ipairs(arc_parts) do
                        local segments = ArcCheck.GetTargetLineSegmentsInArc(ship, target_ship,
                            ArcCheck.arc_line_segments[ship_size][arc]["degrees"])
                        for k, segment in ipairs(segments) do
                            table.insert(target_line_segments, segment)
                        end
                    end

                    if #target_line_segments ~= 0 then
                        local closest = nil
                        closest, _ = ArcCheck.GetDistanceBetweenLineSegments(own_line_segments, target_line_segments)
                        target_range = closest.range
                    end
                end

                -- If we're at range 2, then we need to check if the target is
                -- moving towards us (closing) or moving away from us (fleeing)
                target_closing = nil
                closing_text = '.'
                if target_range == 2 then
                    local target_ship_facing = Vect.RotateDeg({ 0, 0, -1 }, target_ship.GetRotation().y)
                    local target_to_ship = ship.getPosition() - target_ship.GetPosition()
                    local angle_to_ship = Vect.AngleDeg(target_ship_facing, target_to_ship)

                    if (angle_to_ship < 90) then
                        target_closing = true
                        closing_text = ' and closing.'
                    else
                        target_closing = false
                        closing_text = ' and fleeing.'
                    end
                end

                printToAll(' Selected target: ' ..
                    target_ship.getName() ..
                    ', in the ' .. target_arc .. ' arc at range ' .. tostring(target_range) .. closing_text)

                -- Get the move for our situation.
                -- Convert our target's range and facing into a range bracket.
                range_bracket = 'distant'
                if (target_range <= 1 or (target_range == 2 and target_closing == true)) then
                    range_bracket = 'near'
                elseif (target_range == 3 or (target_range == 2 and target_closing == false)) then
                    range_bracket = 'far'
                end
            end

            -- Check if we need to flip the facing and the final move.
            local flip_move = ship_behaviour.move_table[target_arc] == nil
            if (flip_move) then
                target_arc = rule_set.flipArc(target_arc)
            end

            -- Roll the d6, and keep substracting 1 until we find a move.
            local d6_roll = math.random(6)
            while move_code == nil and d6_roll > 0 do
                move_code = ship_behaviour.move_table[target_arc][range_bracket][d6_roll]
                d6_roll = d6_roll - 1
            end

            -- If we had to flip the arc, then also flip the resulting move.
            if (flip_move) then
                if string.find(move_code, 'l') then
                    move_code = string.gsub(move_code, 'l', 'r')
                elseif string.find(move_code, 'r') then
                    move_code = string.gsub(move_code, 'r', 'l')
                end
            end
        end

        AIModule.current_move.move_code = move_code

        if move_code ~= nil then
            -- Check for collisions.
            local move_info = MoveData.DecodeInfo(move_code, ship)
            local probe_data = MoveModule.MoveProbe.TryFullMove(move_info, ship, MoveModule.GetFullMove)
            AIModule.current_move.collision = probe_data.collObj ~= nil
            if probe_data.collObs ~= nil then
                printToAll(' Tried ' .. move_code .. ', hit an obstacle')
                AIModule.current_move.obstacle = true
                -- We've hit an obstacle! If we aren't ionised then We'll try to
                -- swerve.
                if is_ionised == false then
                    -- We pick up to two maneuvers that are the closest to our
                    -- current maneuver, and possible for our ship and stress
                    -- level. Whichever of these will get us closer to our
                    -- target is the one that we try. If that move avoids an
                    -- obstacle, then we choose it instead, otherwise we stick
                    -- with our original maneuver.
                    -- TODO: deal with reverse moves
                    local potential_swerve_moves = {}

                    local selected_swerve_move_code = nil
                    local non_colliding_move_codes = {}
                    if improved_ai then
                        selected_move_through_manouvre = nil
                        if move_info.type == 'straight' then
                            potential_swerve_moves = { 'bl' .. swerve_speed, 'br' .. swerve_speed }
                        elseif move_info.type == 'bank' then
                            potential_swerve_moves = { 't' .. string.sub(move_info.dir, 1, 1) .. swerve_speed, 's' ..
                            swerve_speed }
                        elseif move_info.type == 'turn' then
                            potential_swerve_moves = { 'b' .. string.sub(move_info.dir, 1, 1) .. swerve_speed }
                        end
                        local valid_moves = AIModule.TrySwerveOptions(ship, potential_swerve_moves, stress == false)

                        for _, valid_move in pairs(valid_moves) do
                            local swerve_probe_data = MoveModule.MoveProbe.TryFullMove(valid_move, ship,
                                MoveModule.GetFullMove)
                            if swerve_probe_data.collObs == nil then
                                table.insert(non_colliding_move_codes, swerve_move_info)
                            elseif swerve_probe_data then
                            end
                        end
                    else
                        local swerve_speed = tostring(math.max(1, math.min(3, move_info.speed)))
                        if move_info.type == 'straight' then
                            potential_swerve_moves = { 'bl' .. swerve_speed, 'br' .. swerve_speed }
                        elseif move_info.type == 'bank' then
                            potential_swerve_moves = { 't' .. string.sub(move_info.dir, 1, 1) .. swerve_speed, 's' ..
                            swerve_speed }
                        elseif move_info.type == 'turn' then
                            potential_swerve_moves = { 'b' .. string.sub(move_info.dir, 1, 1) .. swerve_speed }
                        end

                        local swerve_moves = {}
                        for _, potential_swerve_move_code in ipairs(potential_swerve_moves) do
                            -- If we can't do this move, then get the closest move that
                            -- we can do and try that instead. This may be multiple
                            -- moves, for example if a two-bank is impossible then we
                            -- may be able to try a one-bank and a three-bank. They're
                            -- both the same distance from the original so we'll try
                            -- both.
                            local nearest_move_codes = AIModule.GetNearestMoves(ship, potential_swerve_move_code,
                                stress == false)
                            for _, nearest_move_code in ipairs(nearest_move_codes) do
                                table.insert(swerve_moves, nearest_move_code)
                            end
                        end

                        -- Loop through all of the possible swerve moves, and find out
                        -- which one will get us the closest to our target. This is the
                        -- maneuver that we'll try again with.
                        local closest_swerve_move_code = nil
                        local closest_swerve_distance = nil
                        for _, swerve_move_code in ipairs(swerve_moves) do
                            local post_swerve = MoveModule.GetFullMove(swerve_move_code, ship)
                            local post_swerve_position = Vector(post_swerve.pos[1], post_swerve.pos[2],
                                post_swerve.pos[3])
                            local distance = Vect.Length(post_swerve_position - target_ship.GetPosition())
                            if closest_swerve_distance == nil or distance < closest_swerve_distance then
                                closest_swerve_distance = distance
                                selected_swerve_move_code = swerve_move_code
                            end
                        end
                    end

                    if selected_swerve_move_code ~= nil then
                        local swerve_move_info = MoveData.DecodeInfo(selected_swerve_move_code, ship)
                        local swerve_probe_data = MoveModule.MoveProbe.TryFullMove(swerve_move_info, ship,
                            MoveModule.GetFullMove)
                        if swerve_probe_data.collObs == nil then
                            move_code = selected_swerve_move_code
                            print(' Tried ' .. selected_swerve_move_code .. ', avoids the obstacle.')
                            AIModule.current_move.obstacle = false
                            AIModule.current_move.collision = swerve_probe_data.collObj ~= nil
                        else
                            print(' Tried ' .. selected_swerve_move_code .. ', still hits an obstacle.')

                            local obstacle_name = swerve_probe_data.collObs.getName()
                            if obstacle_name:find('Asteroid') then
                                -- Asteroid: Suffer 1 Hit damage and roll one attack die. On a Hit/Crit suffer 1 Hit damage
                                AIModule.current_move.obstacle = 'asteroid'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with an Asteroid. Suffer 1 Hit damage and roll an attack die, suffer 1 additional Hit damage if a Hit or Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Debris') then
                                -- Debris cloud: Take 1 Stress (happens in ManeuverPostShipRest), and roll one attack die. On a Hit suffer 1 Hit damage, on a Crit suffer 1 Crit damage
                                AIModule.current_move.obstacle = 'debris_field'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with a Debris Field. Roll an attack die and suffer 1 Hit damage if a Hit is rolled or 1 Critical damage if a Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Gas Cloud') then
                                -- Gas cloud: Break All Locks, gain 1 Strain (happens in ManeuverPostShipRest), and roll one attack die. On a Hit gain 1 Ion. On a Crit gain 3 Ion
                                AIModule.current_move.obstacle = 'gas_cloud'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with a Gas Cloud. Break all Locks and roll an attack die, gain 1 Ion if a Hit is rolled or 3 Ions if a Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Loose Cargo') then
                                -- Loose Cargo: Take 1 Strain (happens in ManeuverPostShipRest), and roll one attack die. On a Hit/Crit take 1 Stress
                                AIModule.current_move.obstacle = 'Loose Cargo'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with a Loose Cargo. Roll an attack die and gain 1 Stress if if a Hit or Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Spare') then
                                -- Spare Parts: Take 1 Strain (happens in ManeuverPostShipRest), and roll one attack die. On a Hit/Crit take 1 Stress
                                AIModule.current_move.obstacle = 'Spare'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with Spare Parts. Roll an attack die and gain 1 Stress if if a Hit or Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Chaff') then
                                -- Electro-chaff Cloud: Break All Locks, gain 1 Jam, and roll one attack die. On a Hit/Crit gain 1 Stress
                                AIModule.current_move.obstacle = 'chaff_cloud'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with an Electro-chaff Cloud. Break all Locks, gain 1 Jam token, and roll an attack die. Gain 1 Stress if a Hit or Critical is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            elseif obstacle_name:find('Blaze') then
                                -- Blaze: Roll one attack die. On a Hit/Crit suffer 1 Hit damage, on a Focus it gains 1 Stress token
                                AIModule.current_move.obstacle = 'Blaze'
                                printToAll(
                                    ship.GetName() ..
                                    ' has collided with a Blaze. Roll an attack die, suffer 1 Hit damage if a Hit or Critical is rolled, or gain 1 Stress if a Focus is rolled.',
                                    color(1.0, 1.0, 0.2, 0.9))
                            end
                        end
                    end
                end
            end

            -- TODO: Check for edge of table collision

            AIModule.current_move.difficulty = 'b'

            -- If we are ionised, then our move is always blue and we remove
            -- all of our ion tokens. Otherwise, we check for our difficulty.
            if is_ionised then
                while TokenModule.GetShipTokenCount(ship, 'Ion') > 0 do
                    -- BUG: This fails to identify the ion token stack if the
                    -- ship has exactly two stress tokens. If this occurs, the
                    -- ship also leaves behind the single remaining stress
                    -- token. I've done a bit of debugging and it appears that
                    -- when a token stack has "takeObject" called on it, it
                    -- changes from a 'chip' type to a 'generic' type. This
                    -- means that it isn't picked up by ObjType.GetNearOfType.
                    -- This does correct itself if the tokens are moved around
                    -- manually, so I assume that this is just a one-frame
                    -- occurence that wouldn't matter if the AI wasn't doing
                    -- everything at the same time. Potential fix: set
                    -- '__XW_Token' on the token afterwards?
                    DialModule.PerformAction(ship, 'Ion', ship.getVar('owningPlayer'), { ['remove'] = true })
                end
            else
                AIModule.current_move.difficulty = AIModule.GetMoveDifficulty(ship, move_code)
                if AIModule.current_move.difficulty == nil and ship_behaviour.special_move_difficulties then
                    -- Check for special moves that aren't part of the moveSet (config enabled manouvres)
                    AIModule.current_move.difficulty = ship_behaviour.special_move_difficulties[move_code] or 'w'
                end
            end
            -- Remove tokens _before_ the move - if we wait till afterwards then
            -- the tokens haven't caught up with the ship and the token module
            -- doesn't count them.
            if AIModule.current_move.difficulty == 'b' then
                if stress then
                    DialModule.PerformAction(ship, 'Stress', ship.getVar('owningPlayer'), { ['remove'] = true })
                    AIModule.current_move.stress_count = AIModule.current_move.stress_count - 1
                end
                if TokenModule.GetShipTokenCount(ship, 'Strain') > 0 then
                    DialModule.PerformAction(ship, 'Strain', ship.getVar('owningPlayer'), { ['remove'] = true })
                end
                if TokenModule.GetShipTokenCount(ship, 'Deplete') > 0 then
                    DialModule.PerformAction(ship, 'Deplete', ship.getVar('owningPlayer'), { ['remove'] = true })
                end
            end

            AIModule.current_move.in_progress = true
            if MoveModule.PerformMove(move_code, ship, false, AIModule.ManeuverPostShipRest, true) == false then
                -- If the PerformMove function retured false, then the ship
                -- could not move at all. In this case the post-rest callback
                -- won't be fired, so we'll call it ourselves. Also, just in
                -- case, set the collision flag.
                AIModule.current_move.collision = true
                AIModule.ManeuverPostShipRest(ship)
            end
        end
    else
        printToAll('No AI routine found for ship ID ' .. tostring(ship_id), color(1.0, 1.0, 0.2, 0.9))
    end
end

AIModule.ManeuverPostShipRest = function(ship)
    local action_selected = false;

    if AIModule.current_move.obstacle == 'debris_field' then
        DialModule.PerformAction(ship, 'Stress', ship.getVar("owningPlayer"))
    elseif AIModule.current_move.obstacle == 'gas_cloud' or AIModule.current_move.obstacle == 'Loose Cargo' or AIModule.current_move.obstacle == 'Spare' then
        DialModule.PerformAction(ship, 'Strain', ship.getVar("owningPlayer"))
    end

    if AIModule.current_move.difficulty == 'r' then
        DialModule.PerformAction(ship, 'Stress', ship.getVar("owningPlayer"))
    elseif AIModule.current_move.take_action == true and AIModule.current_move.stress_count == 0 and AIModule.current_move.collision == false and AIModule.current_move.obstacle == false then
        if AIModule.current_move.is_ionised then
            -- Ionised ships can only perform a focus action, if possible.
            for _, action in pairs(ship.getTable('Data')['actSet']) do
                if action == 'F' then
                    table.insert(AIModule.current_move.action_stack, 'focus')
                    action_selected = true
                    break
                end
            end
        else
            -- Check for Full Throttle and apply it now if appropriate.
            AIModule.ApplySpecialAbility(ship, 'fullThrottle')

            -- Run through the ship's actions and try them in order.
            action_selected = AIModule.SelectAction(ship)
        end
    end

    if action_selected then
        AIModule.ProcessActionStack(ship)
    else
        AIModule.current_move.in_progress = false
    end
end

--[[ AIModule.GetMoveDifficulty
This function takes a ship and a move code and returns the difficulty of the
move.

ship: TTS Object, the ship performing the move
move_code: String, the move code being queried.

returns a string corresponding to the difficulty of the move for the ship:
    'b': blue maneuver, reduces stress
    'w': white manuever, stress neutral
    'r': red maneuver, causes stress
    nil: maneuver is impossible for the given ship
]]
AIModule.GetMoveDifficulty = function(ship, move_code)
    move_set = ship.getTable('Data')['moveSet']
    for _, raw_move_code in ipairs(move_set) do
        local ship_move_difficulty = string.sub(raw_move_code, 1, 1)
        local ship_move_code = string.sub(raw_move_code, 2)

        if ship_move_code == move_code then
            return ship_move_difficulty
        end
    end
    return nil
end

AIModule.TrySwerveOptions = function(ship, move_codes, can_perform_red_maneuvers)
    print("AIModule.TrySwerveOptions: " .. move_codes[1] .. "red?: " .. tostring(can_perform_red_maneuvers))
    move_set = ship.getTable('Data')['moveSet']
    valid_moves = {}
    for _, raw_move_code in ipairs(move_set) do
        local move_difficulty = string.sub(raw_move_code, 1, 1)
        if move_difficulty ~= 'r' or can_perform_red_maneuvers then
            local move_code = string.sub(raw_move_code, 2)
            for _, test_move_code in ipairs(test_move_codes) do
                if test_move_code == move_code then
                    table.insert(valid_moves, move_code)
                end
            end
        end
    end
    return valid_moves
end

--[[ AIModule.GetNearestMoves
This function takes a ship and a move code, and returns the nearest maneuvers
that the ship is capable of. This may be the specified move. "Nearest" is
defined as closest in speed. We won't change the angle of the move. So for
example, if tr1 is passed in we will try tr2 and tr3, but not br1.

ship: TTS Object, the ship whose move set the function will be testing
move_code: String, the move code we want to get the closest maneuver to
can_perform_red_maneuvers: Boolean, if true then we will try red maneuvers,
    if false then we won't.

returns a table of move codes, as strings.
]]
--
AIModule.GetNearestMoves = function(ship, move_code, can_perform_red_maneuvers)
    print("AIModule.GetNearestMoves: " .. tostring(move_code) .. "red?: " .. tostring(can_perform_red_maneuvers))
    move_set = ship.getTable('Data')['moveSet']
    local move_info = MoveData.DecodeInfo(move_code, ship)
    local original_speed = move_info.speed

    -- We're going to loop through all of the ships moves and test for whether
    -- they're possible or not, and each loop we'll increase the speed offset
    -- by one. So 0 first, then -1 and +1, then -2 and +2, ... First we need
    -- to calculate the maximum number of loops we can make.
    local min_speed = 1
    local max_speed = 3
    if move_info.type == 'straight' then
        min_speed = 0
        max_speed = 5
    end
    max_offset = math.max(move_info.speed - min_speed, max_speed - move_info.speed)
    print("max_offset: " .. tostring(max_offset))
    -- Break the move code into sections so we can change the speed easily.
    local speed_position = string.find(move_code, tostring(original_speed))
    local move_pre_speed = string.sub(move_code, 1, speed_position - 1)
    local move_post_speed = string.sub(move_code, speed_position + 1)

    -- Loop through all the moves at the current offset. If we find at least
    -- one possible move, then return it.
    local speed_offset = 0
    while speed_offset <= max_offset do
        -- Prepare a table of 1-2 speeds to try this loop
        local test_speeds = {}
        if speed_offset == 0 then
            table.insert(test_speeds, original_speed)
        else
            for _, direction in ipairs({ 1, -1 }) do
                local test_speed = original_speed + speed_offset * direction
                if test_speed <= max_speed and test_speed >= min_speed then
                    table.insert(test_speeds, test_speed)
                end
            end
        end

        -- Turn the move speeds into move codes
        test_move_codes = {}
        for _, test_speed in ipairs(test_speeds) do
            print("test_speed: " .. move_pre_speed .. tostring(test_speed) .. move_post_speed)
            table.insert(test_move_codes, move_pre_speed .. tostring(test_speed) .. move_post_speed)
        end

        -- Loop through and check if these maneuvers are in our list
        move_replacements = {}
        for _, raw_move_code in ipairs(move_set) do
            local move_difficulty = string.sub(raw_move_code, 1, 1)
            if move_difficulty ~= 'r' or can_perform_red_maneuvers then
                local move_code = string.sub(raw_move_code, 2)
                for _, test_move_code in ipairs(test_move_codes) do
                    if test_move_code == move_code then
                        table.insert(move_replacements, move_code)
                    end
                end
            end
        end

        if #move_replacements ~= 0 then
            return move_replacements
        end

        speed_offset = speed_offset + 1
    end
    return {}
end

AIModule.ApplySpecialAbility = function(ship, ability)
    if AIModule.HasSpecialAbility(ship, ability) then
        if ability == 'fullThrottle' then
            -- Take an evade action if the ship fully executed (ie, no
            -- ship-to-ship collision) a 3-5 maneuver. We're assumed to not be
            -- stressed as this is only called right before actions are
            -- selected.
            if AIModule.current_move.collision == false then
                local move_code = AIModule.current_move.move_code
                if string.find(move_code, '3') or string.find(move_code, '4') or string.find(move_code, '5') then
                    printToAll(string.format('%s used full throttle to evade.', ship.getName()))
                    DialModule.PerformAction(ship, 'Evade', ship.getVar('owningPlayer'))
                    table.insert(AIModule.current_move.actions, 'evade')
                end
            end
        end
    end
end

AIModule.HasSpecialAbility = function(ship, ability)
    local ship_behaviour = BehaviourDB.GetRuleSet().GetShipBehaviour(ship)

    if ship_behaviour.special_rules == nil then
        return false
    end

    for _, ship_ability in pairs(ship_behaviour.special_rules) do
        if ability == ship_ability then
            return true
        end
    end

    return false
end

--[[ AIModule.IsIonised
This function returns whether or not a ship has enough ion tokens to ionise it.

ship: TTS Object, the ship performing the move

returns true if the ship is ionised, false otherwise.
]]
AIModule.IsIonised = function(ship)
    local ion_count = TokenModule.GetShipTokenCount(ship, "Ion")
    local ship_size = ship.getTable('Data').Size or 'small'
    if ship_size == 'small' then
        return ion_count >= 1
    elseif ship_size == 'medium' then
        return ion_count >= 2
    elseif ship_size == 'large' then
        return ion_count >= 3
    else
        return ion_count >= 6
    end

    return false
end

--[[ AI action selection

This submodule is smaller than the maneuver system, but probably more complex.
The main function is AIModule.AttemptAction, which takes an action definition
and checks if it is possible to execute. This involves checking the action's
pre-conditions (if the ship is in the right situation to attempt it), then if
the ship can actually execute the action, and finally checking the action's
post-conditions (if the action met with the desired result).

Where this gets complicated is the use of action probes, which are hypothetical
future positions of the ship. So if a ship makes a boost, then we create a probe
for each type of boost (bl1, s1, br1) and evaluate the post-conditions for each
probe. Where this gets _really_ complicated is when handling ships that can
string together more than one move action, such as the Interceptor's boost
action linking to a barrel roll action. For this we have to "expand" the first
set of probes by the second action - so the probe "bl1" expands into six more
probes: "bl1 > rl1", "bl1 > rl2", "bl1 > rl3", "bl1 > rr1", "bl1 > rr2", and
"bl1 > rr3". These permutations can get quite large (45 in the case of the
Interceptor) so these are cached where possible, but even so they can lead to
long execution times.

Finally, the actions are packed into a stack and processed one-by-one. Just like
the maneuver submodule these have to be dealt with in a callback to wait for the
TTS components to come to a rest.
]]

-- List which actions are expandable actions, and therefore have to be expanded
-- into a list of potential move codes or turret rotations. Any action not
-- listed here is assumed to be possible to made at any time (such as 'focus',
-- 'evade', etc)
AIModule.expandable_actions = {
    ['barrelRoll'] = { 'rl1', 'rr1', 'rl2', 'rr2', 'rl3', 'rr3' },
    ['boost'] = { 'bl1', 's1', 'br1' },
    ['rotateTurret'] = true -- These are calculated at run-time based on the turret type and current rotation.
}

-- Which arcs are adjacent to each arc, used for checking whether a ship is
-- wholly within an arc or not.
AIModule.arc_adjacencies = {
    ['front'] = { 'left', 'right' },
    ['back'] = { 'left', 'right' },
    ['left'] = { 'front', 'back' },
    ['right'] = { 'front', 'back' },
    ['leftRight'] = { 'front', 'back' },
    ['frontBack'] = { 'left', 'right' },
    ['fullfront'] = { 'fullback' },
    ['fullback'] = { 'fullfront' }
}

AIModule.full_action_names = {
    C = 'calculate',
    F = 'focus',
    TL = 'targetLock',
    E = 'evade',
    Rot = 'rotate',
    B = 'boost',
    BR = 'barrelRoll',
    VR = 'barrelRoll',
    RF = 'reinforce',
    RL = 'reload',
    Coord = 'coordinate',
    Jam = 'jam',
}

AIModule.SelectAction = function(ship)
    local ship_behaviour = BehaviourDB.GetRuleSet().GetShipBehaviour(ship)

    for _, action in ipairs(ship_behaviour.action_selection) do
        if AIModule.AttemptAction(ship, AIModule.current_move.target, action) then
            return true
        end
    end

    local ship_id = ship.getTable('Data')['shipId']
    printToAll('No AI actions found for ship ID ' .. tostring(ship_id) .. ', please make actions manually.',
        color(1.0, 1.0, 0.2, 0.9))
end

AIModule.AttemptAction = function(ship, target, action_definition)
    if action_definition.pass_through then
        AIModule.PrintActionDescription(action_definition.description, ship, target)
        return false
    end

    -- Generate a static action probe to start our moves from.
    local initial_probe = AIModule.GetActionProbe(ship)
    -- The list of possible probe moves, if any. Group by the set index.
    local probe_sets = {}
    -- The simple actions that we'll take, grouped by the set index.
    local simple_actions = {}

    -- Check for preconditions
    if AIModule.CheckProbeConditions(ship, target, initial_probe, action_definition.preconditions) == false then
        return false
    end

    -- There are three ways that an action can be defined in the behaviour
    -- database, so look for the shorthands and expand them out to the full
    -- definition if necessary.
    local action_set = action_definition.action
    if type(action_definition.action) == 'string' then
        action_set = { [1] = { [action_definition.action] = { stress = false } } }
    elseif action_definition.action[1] == nil then
        action_set = { [1] = action_definition.action }
    end

    -- Iterate over each item in the action list, attempting each one in turn.
    -- The action could be a move action (barrelRoll or boost) in which case
    -- we need to expand it into all possible moves.
    local action_includes_move_component = false
    for set_index, action_list in ipairs(action_set) do
        probe_sets[set_index] = {}
        simple_actions[set_index] = {}
        local initial_action = true

        for action, arguments in pairs(action_list) do
            -- Check for the stress shorthand in the arguments parameter.
            if type(arguments) ~= 'table' then
                arguments = { stress = arguments }
            end

            if AIModule.expandable_actions[action] ~= nil then
                -- Get or build the list of actions to expand into.
                local expanded_actions = AIModule.expandable_actions[action]
                if type(expanded_actions) == 'table' then
                    action_includes_move_component = true
                else
                    expanded_actions = {}
                    if action == 'rotateTurret' then
                        action_includes_move_component = true
                        local mount = arguments.mount or 'main'
                        local turret_rotation_options = AIModule.GetTurretRotationOptions(ship, mount)
                        for _, rotation in pairs(turret_rotation_options) do
                            table.insert(expanded_actions,
                                {
                                    ['action'] = 'rotateTurret',
                                    ['mount'] = mount,
                                    ['arc'] = rotation,
                                    stress = arguments
                                        .stress
                                })
                        end
                    end
                end

                local action_difficulty = 'w'
                if arguments.stress == true then
                    action_difficulty = 'r'
                end

                -- This action is an expanded action, so expand our current set
                -- of possible action probes further.
                if initial_action == true then
                    probe_sets[set_index] = table.join(probe_sets[set_index],
                        AIModule.ExpandActionProbe(ship, initial_probe, expanded_actions, action_difficulty))
                    initial_action = false
                else
                    new_probes = {}
                    for _, probe in pairs(probe_sets[set_index]) do
                        new_probes = table.join(new_probes,
                            AIModule.ExpandActionProbe(ship, probe, expanded_actions, action_difficulty))
                    end

                    probe_sets[set_index] = table.join(probe_sets[set_index], new_probes)
                end

                -- Set the set index on each probe.
                for _, probe in pairs(probe_sets[set_index]) do
                    probe.set_index = set_index
                end
            else
                -- There's one instance that we skip the action - we don't take
                -- a target lock action if the target is already locked. This is
                -- often handled by the preconditions anyway, but sometimes it's
                -- not so we double-check here. Also, range must be checked by
                -- the postconditions as doing a range check now would be from
                -- the post-maneuver position, not the post-action position.
                local skip_action = false
                if action == 'targetLock' then
                    skip_action = AIModule.HasTargetLockOnShip(ship, target)
                        or AIModule.SkipTargetLock(ship, target)
                end

                if skip_action == false then
                    table.insert(simple_actions[set_index], action)

                    if arguments.stress == true then
                        table.insert(simple_actions[set_index], 'stress')
                    end
                end
            end
        end
    end

    -- We merge together all of the probe sets into one table so we can rank
    -- them and compare them to each other. We need to select a random one, so
    -- we'll randomise the list and pick the first one that passes all the
    -- postconditions. If the list is empty, or if no probe passes the
    -- postconditions, then we can't complete the action and must return false.
    selected_probe = initial_probe

    -- Group all the probe sets together
    local all_possible_probes = {}
    for _, probe_set in pairs(probe_sets) do
        all_possible_probes = table.join(all_possible_probes, probe_set)
    end

    -- Randomise the probes, then sort by difficulty so we avoid stress if
    -- possible. We set the index here as it is used by SortProbesByDifficulty
    -- to guarantee a stable sort.
    all_possible_probes = table.shuffle(all_possible_probes)
    for index, probe in ipairs(all_possible_probes) do
        probe.index = index
    end
    table.sort(all_possible_probes, AIModule.SortProbesByDifficulty)

    -- Iterate over the probes. The first successful one we find we store
    -- in the probe_actions array that gets processed later, and we also record
    -- the set index so we know which set of simple actions to use.
    local probe_actions = {}
    local set_index = 1
    local move_count = 0
    for _, probe in pairs(all_possible_probes) do
        if AIModule.CheckProbeConditions(ship, target, probe, action_definition.postconditions) == true then
            selected_probe = probe
            set_index = probe.set_index

            for _, action in pairs(probe.actions) do
                -- Keep track of how many actual moves we make.
                if action.action == nil then
                    move_count = move_count + 1
                end

                if action ~= 's0' then
                    table.insert(probe_actions, action)
                end
            end

            if probe.difficulty == 'r' then
                table.insert(simple_actions[set_index], 'stress')
            end

            break
        end
    end

    if action_includes_move_component and move_count == 0 then
        return false
    end

    for index = 1, #simple_actions[set_index] do
        table.insert(AIModule.current_move.action_stack,
            simple_actions[set_index][#simple_actions[set_index] + 1 - index])
    end
    for index = 1, #probe_actions do
        table.insert(AIModule.current_move.action_stack, probe_actions[#probe_actions + 1 - index])
    end

    if #AIModule.current_move.action_stack > 0 then
        AIModule.PrintActionDescription(action_definition.description, ship, target, selected_probe)
        return true
    end

    return false
end

-- Processes the queued actions in order, movement first and then simple
-- actions. Will wait for the callback to keep processing actions in the case of
-- a movement action
AIModule.ProcessActionStack = function(ship)
    if AIModule.current_move.in_progress == false then
        return
    end

    while #AIModule.current_move.action_stack > 0 do
        local action = table.remove(AIModule.current_move.action_stack)

        if action.action == 'rotateTurret' then
            ship.call('SetTurretArc', { ['mount'] = action.mount, ['arc'] = action.arc, ['snap'] = false })
        elseif action == 'stress' then
            DialModule.PerformAction(ship, 'Stress', ship.getVar('owningPlayer'))
        elseif action == 'focus' then
            DialModule.PerformAction(ship, 'Focus', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'focus')
        elseif action == 'calculate' then
            DialModule.PerformAction(ship, 'Calculate', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'calculate')
        elseif action == 'focuscalculate' then
            local hasFocus = false
            local hasCalc = false
            for _, action in pairs(ship.getTable('Data').actSet) do
                if action == "F" then
                    DialModule.PerformAction(ship, 'Focus', ship.getVar('owningPlayer'))
                    table.insert(AIModule.current_move.actions, 'focus')
                    hasFocus = true
                elseif action == "C" then
                    hasCalc = true
                end
            end
            if hasCalc and not hasFocus then
                DialModule.PerformAction(ship, 'Calculate', ship.getVar('owningPlayer'))
                table.insert(AIModule.current_move.actions, 'calculate')
            end
        elseif action == 'evade' then
            DialModule.PerformAction(ship, 'Evade', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'evade')
        elseif action == 'targetLock' then
            DialModule.PerformAction(ship, 'Target Lock', ship.getVar('owningPlayer'),
                { ['ship'] = ship, ['target'] = AIModule.current_move.target })
            table.insert(AIModule.current_move.actions, 'targetLock')
        elseif action == 'cloak' then
            DialModule.PerformAction(ship, 'Cloak', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'cloak')
        elseif action == 'reinforceFore' then
            DialModule.PerformAction(ship, 'Reinforce', ship.getVar('owningPlayer'), { ['flip'] = true })
            table.insert(AIModule.current_move.actions, 'reinforce')
        elseif action == 'reinforceAft' then
            DialModule.PerformAction(ship, 'Reinforce', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'reinforce')
        elseif action == 'coordinate' then
            printToAll('Please manage the coordinate action manually.', color(1.0, 1.0, 0.2, 0.9))
            table.insert(AIModule.current_move.actions, 'coordinate')
        elseif action == 'jam' then
            target = AIModule.current_move.target
            DialModule.PerformAction(target, 'Jam', target.getVar('owningPlayer'))
            printToAll('Please manage the effects of the jam token manually.', color(1.0, 1.0, 0.2, 0.9))
            table.insert(AIModule.current_move.actions, 'jam')
        elseif action == 'tractor' then
            target = AIModule.current_move.target
            DialModule.PerformAction(target, 'Tractor', target.getVar('owningPlayer'))
            printToAll('Please manage the effects of the tractor token manually.', color(1.0, 1.0, 0.2, 0.9))
            table.insert(AIModule.current_move.actions, 'tractor')
        elseif action == 'tractorSelf' then
            DialModule.PerformAction(ship, 'Tractor', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'tractor')
        elseif action == 'deplete' then
            DialModule.PerformAction(ship, 'Deplete', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'deplete')
        elseif action == 'strain' then
            DialModule.PerformAction(ship, 'Strain', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'strain')
        elseif action == 'disarm' then
            DialModule.PerformAction(ship, 'Disarm', ship.getVar('owningPlayer'))
            table.insert(AIModule.current_move.actions, 'disarm')
        elseif MoveModule.PerformMove(action, ship, false, AIModule.ProcessActionStack) then
            break
        end
    end

    AIModule.current_move.in_progress = #AIModule.current_move.action_stack > 0
end

AIModule.PrintActionDescription = function(description, ship, target, probe)
    local text = description
    local text_parameters = {}
    if type(description) == 'table' then
        text = description.text
        for _, string_id in pairs(description.strings) do
            if string_id == 'ship' then
                table.insert(text_parameters, ship.getName())
            elseif string_id == 'target' then
                table.insert(text_parameters, target.getName())
            else
                -- If it's not 'ship' or 'target', then it's an action target
                -- that is stored in the chain of the selected action probes.
                -- We'll look up the chain until we find it.
                action_target = ''
                current_probe = probe
                while current_probe ~= nil and action_target == '' do
                    if current_probe.action_targets[string_id] ~= nil then
                        action_target = current_probe.action_targets[string_id].getName()
                    end
                    current_probe = current_probe.parent
                end

                table.insert(text_parameters, action_target)
            end
        end
    else
        text_parameters = { ship.getName() }
    end

    printToAll(string.format(text, unpack(text_parameters)))
end

--[[ The action probe system, part of the AI action submodule.

These functions deal the creating action probes, expanding them, sorting them,
and checking conditions on them.
]]
AIModule.CheckProbeConditions = function(ship, target, probe, conditions)
    -- No conditions, then we can't fail.
    if conditions == nil then
        return true
    end

    local probe_result = true

    for condition, parameters in pairs(conditions) do
        local required_result = parameters
        local arguments = nil
        -- Conditions can either point just to the required result, in which
        -- case they have no arguments, or point to a table which contains both
        -- the required result and arguments.
        if type(parameters) == 'table' then
            required_result = parameters.requiredResult
            arguments = parameters.arguments
        end
        local actual_result = AIModule.condition_functions[condition](ship, target, probe, arguments)
        if actual_result ~= required_result then
            probe_result = false
            break
        end
    end

    return probe_result
end

-- This creates the origin action probe and returns it.
AIModule.GetActionProbe = function(ship)
    local move = 's0'

    if AIModule.current_move.probes[move] == nil then
        AIModule.current_move.probes[move] = {}
    end

    if AIModule.current_move.probes[move].possible == nil then
        AIModule.current_move.probes[move].parent = nil
        AIModule.current_move.probes[move].action_targets = {}
        AIModule.current_move.probes[move].actions = { move }
        AIModule.current_move.probes[move].possible = true
        AIModule.current_move.probes[move].difficulty = 'w'
        AIModule.current_move.probes[move].position = ship.getPosition()
        AIModule.current_move.probes[move].rotation = ship.getRotation()
    end

    return AIModule.current_move.probes[move]
end

-- This function takes an existing probe, and appends all possible moves/actions
-- in the action list onto it, returning a list of those that are possible.
AIModule.ExpandActionProbe = function(ship, probe, actions, difficulty)
    local possible_probes = {}

    local probe_name = ''
    for _, previous_action in pairs(probe.actions) do
        if string.len(probe_name) > 0 then
            probe_name = probe_name .. ','
        end
        probe_name = probe_name .. AIModule.GetActionProbeName(previous_action)
    end

    for _, action in pairs(actions) do
        -- First check if this exists. If it does, and it's possible, then just
        -- return it and skip to the next one.
        local new_probe_name = probe_name .. ',' .. AIModule.GetActionProbeName(action)
        new_probe = AIModule.current_move.probes[new_probe_name]
        if new_probe ~= nil then
            if new_probe.possible == true then
                new_probe.difficulty = difficulty
                table.insert(possible_probes, new_probe)
            end
        else
            local new_probe = {
                ['parent'] = probe,
                ['possible'] = false,
                ['actions'] = table.shallowcopy(probe.actions),
                ['action_targets'] = {},
                ['difficulty'] = difficulty,
            }
            table.insert(new_probe.actions, action)

            if action.action == nil then
                -- If the action doesn't contain an 'action' key, then it's a move.
                local move_code = action

                -- Test whether this probe is even possible.
                local original_ship_state = AIModule.GetShipState(ship)
                AIModule.ApplyProbe(ship, probe)

                local move_info = MoveData.DecodeInfo(move_code, ship)
                local probe_data = MoveModule.MoveProbe.TryFullMove(move_info, ship, MoveModule.GetFullMove)
                if probe_data.done and probe_data.collObj == nil and probe_data.collObs == nil then
                    new_probe.possible = true
                    new_probe.position = probe_data.finalPosRot.pos
                    new_probe.rotation = probe_data.finalPosRot.rot
                    table.insert(possible_probes, new_probe)
                end
                AIModule.current_move.probes[new_probe_name] = new_probe

                AIModule.SetShipState(ship, original_ship_state)
            elseif action.action == 'rotateTurret' then
                -- Turret rotations are always possible so we don't need to test
                -- the action.
                new_probe.possible = true
                new_probe.position = probe.position
                new_probe.rotation = probe.rotation
                new_probe.turrets = { [action.mount] = action.arc }
                table.insert(possible_probes, new_probe)

                AIModule.current_move.probes[new_probe_name] = new_probe
            end
        end
    end

    return possible_probes
end

AIModule.GetActionProbeName = function(action)
    if action.action == nil then
        return action
    elseif action.action == 'rotateTurret' then
        return string.format('rotateTurret(%s,%s)', action.mount, action.arc)
    else
        return ''
    end
end

AIModule.SortProbesByDifficulty = function(e1, e2)
    if e1.difficulty == 'b' and e2.difficulty ~= 'b' then
        return true
    elseif e2.difficulty == 'b' and e1.difficulty ~= 'b' then
        return false
    elseif e1.difficulty == 'w' and e2.difficulty == 'r' then
        return true
    elseif e2.difficulty == 'w' and e1.difficulty == 'r' then
        return false
    end

    return e1.index < e2.index
end

AIModule.GetShipState = function(ship)
    local state = { ['position'] = ship.GetPosition(), ['rotation'] = ship.GetRotation(), ['turrets'] = {} }

    local turret_mounts = ship.call('GetAssignedMounts')
    for _, mount in pairs(turret_mounts) do
        state.turrets[mount] = ship.call('GetTurretArc', { ['mount'] = mount })
    end

    return state
end

AIModule.SetShipState = function(ship, state)
    ship.SetPosition(state.position)
    ship.SetRotation(state.rotation)

    --if state.turrets ~= nil then
    --    for mount, arc in pairs(state.turrets) do
    --        ship.call('SetTurretArc', {['mount'] = mount, ['arc'] = arc, ['snap'] = true})
    --    end
    --end
end

AIModule.ApplyProbe = function(ship, probe)
    ship.SetPosition(probe.position)
    ship.SetRotation(probe.rotation)

    --if probe.turrets ~= nil then
    --    for mount, arc in pairs(probe.turrets) do
    --        ship.call('SetTurretArc', {['mount'] = mount, ['arc'] = arc, ['snap'] = true})
    --    end
    --end
end

AIModule.GetTurretRotationOptions = function(ship, mount)
    -- Build up our list of possible rotations.
    local rotation_options = {}
    local turret_type = ship.call('GetTurretType', { ['mount'] = mount })
    if (turret_type[1] == 'singleturret') then
        rotation_options = { 'front', 'right', 'back', 'left' }
    elseif (turret_type[1] == 'doubleturret') then
        rotation_options = { 'frontback', 'leftright' }
    else
        rotation_options = turret_type
    end

    -- Remove our current option arc from the list of options.
    local turret_arc = ship.call('GetTurretArc', { ['mount'] = mount })
    i = 1
    while i <= #rotation_options do
        if rotation_options[i] == current_arc then
            table.remove(rotation_options, i)
        else
            i = i + 1
        end
    end

    return rotation_options
end

AIModule.condition_functions = {}
AIModule.condition_functions.hasShot = function(ship, target, probe, arguments)
    --[[ TODO: This should favour a shot at the target. To do so we might need to
           create a different condition function "hasShotOnTarget" and have it occur
           before the generic hasShot checks.]]
    local min_range = 1
    local max_range = 3
    if arguments ~= nil then
        min_range = arguments.minRange or min_range
        max_range = arguments.maxRange or max_range
    end

    if probe.shot_range == nil then
        probe.shot_range = -1

        local original_position_rotation = AIModule.GetShipState(ship)
        AIModule.ApplyProbe(ship, probe)
        local arcs = ship.call('GetAllArcs')
        if probe.turrets ~= nil then
            arcs = {}
            for mount, arctype in pairs(probe.turrets) do
                for _, arc in pairs(mountDirectionToArcs[arctype]) do
                    table.insert(arcs, arc)
                end
            end
        end
        targets = ArcCheck.GetTargetsInRelationToArc(ship, arcs)
        targets = table.sieve(targets, AIModule.FilterInArc)
        targets = table.sieve(targets, AIModule.FilterInRange)

        for _, target in pairs(targets) do
            if probe.shot_range == -1 or target.closest.range < probe.shot_range then
                probe.shot_range = target.closest.range
            end
        end

        AIModule.SetShipState(ship, original_position_rotation)
    end

    return probe.shot_range ~= -1 and probe.shot_range >= min_range and probe.shot_range <= max_range
end

AIModule.condition_functions.inTargetsArc = function(ship, target, probe, arguments)
    if probe.in_targets_arc == nil then
        local original_position_rotation = AIModule.GetShipState(ship)
        AIModule.ApplyProbe(ship, probe)

        probe.in_targets_arc = false
        local arcs = ship.call('GetAllArcs')
        if probe.turrets ~= nil then
            arcs = {}
            for mount, arctype in pairs(probe.turrets) do
                for _, arc in pairs(mountDirectionToArcs[arctype]) do
                    table.insert(arcs, arc)
                end
            end
        end

        targets = ArcCheck.GetTargetsInRelationToArc(target, arcs, { ship })
        targets = table.sieve(targets, AIModule.FilterInArc)
        targets = table.sieve(targets, AIModule.FilterInRange)
        for _, target_info in pairs(targets) do
            probe.in_targets_arc = true
            break
        end

        AIModule.SetShipState(ship, original_position_rotation)
    end

    return probe.in_targets_arc
end

AIModule.condition_functions.targetMoved = function(ship, target, probe, arguments)
    if probe.target_moved == nil then
        local ship_initiative = ship.getTable('Data')['initiative']
        local target_initiative = target.getTable('Data')['initiative']
        probe.target_moved = ship_initiative >
            target_initiative -- TODO: This assumes that the AI moves first on ties like in HotAC.
    end

    return probe.target_moved
end

AIModule.condition_functions.targetLocked = function(ship, target, probe, arguments)
    if probe.target_locked == nil then
        probe.target_locked = AIModule.HasTargetLockOnShip(ship, target)
    end

    return probe.target_locked
end

AIModule.condition_functions.targetWithinRange = function(ship, target, probe, arguments)
    local min_range = 1
    local max_range = 3
    if arguments ~= nil then
        min_range = arguments.minRange or min_range
        max_range = arguments.maxRange or max_range
    end

    if probe.target_range == nil then
        local targets = ArcCheck.GetTargetsInRelationToArc(ship, 'all', { target })
        for _, target_info in pairs(targets) do
            probe.target_range = target_info.closest.range
            break
        end
    end

    return probe.target_range >= min_range and probe.target_range <= max_range
end

AIModule.condition_functions.evading = function(ship, target, probe, arguments)
    if probe.evading == nil then
        probe.evading = TokenModule.GetShipTokenCount(ship, 'Evade') > 0
    end

    if probe.evading ~= true then
        for _, action in pairs(AIModule.current_move.actions) do
            if action == 'evade' then
                probe.evading = true
                break
            end
        end
    end

    return probe.evading
end

AIModule.condition_functions.hasAction = function(ship, target, probe, arguments)
    if probe.action_set == nil then
        probe.action_set = {}
        for _, action in pairs(ship.getTable('Data').actSet) do
            if AIModule.full_action_names[action] then
                probe.action_set[AIModule.full_action_names[action]] = true
            end
        end
    end
    return probe.action_set[arguments.action]
end

AIModule.condition_functions.inEnemyArc = function(ship, target, probe, arguments)
    local arc = 'all'
    local wholly_within_arc = true
    local min_enemies = 1
    if arguments ~= nil then
        arc = arguments.arc or arc
        wholly_within_arc = arguments.whollyWithinArc or wholly_within_arc
        min_enemies = arguments.enemyCount or min_enemies
    end

    -- This counts the number of enemies whose arc we are within, and who are
    -- within our specified arc. This is mainly used for the reinforce action
    -- and the fullfront/fullback arc.
    local condition_index = arc .. ',' .. tostring(wholly_within_arc)
    if probe.num_enemy_arcs == nil or probe.num_enemy_arcs[condition_index] == nil then
        if probe.num_enemy_arcs == nil then
            probe.num_enemy_arcs = {}
        end
        probe.num_enemy_arcs[condition_index] = 0

        local original_position_rotation = AIModule.GetShipState(ship)
        AIModule.ApplyProbe(ship, probe)

        -- Get all ships within the specified arc.
        enemies_in_arc = ArcCheck.GetTargetsInRelationToArc(ship, arc)
        enemies_in_arc = table.sieve(enemies_in_arc, AIModule.FilterInArc)

        -- If we only want ships that are fully within the arc, then we loop
        -- through all adjacent arcs and remove any ship that appears in both.
        -- So, if we checked the fullfront arc, then we reject all ships that
        -- is also int eh fullback arc.
        if wholly_within_arc and AIModule.arc_adjacencies[arc] ~= nil then
            for _, adjacent_arc in pairs(AIModule.arc_adjacencies[arc]) do
                if #enemies_in_arc > 0 then
                    -- Quick check to avoid unnecessary calls to ArcCheck.GetTargetsInRelationToArc
                    enemies_in_adjacent_arc = ArcCheck.GetTargetsInRelationToArc(ship, adjacent_arc)
                    enemies_in_adjacent_arc = table.sieve(targets, AIModule.FilterInArc)
                    enemies_in_arc = table.sieve(enemies_in_arc,
                        -- Return false if this ship appears in arc_targets.
                        function(el)
                            for _, enemy in pairs(enemies_in_adjacent_arc) do
                                if el.ship == enemy.ship then
                                    return false
                                end
                            end

                            return true
                        end
                    )
                end
            end
        end

        -- Lastly, we iterate over all targets that remain and check if we are
        -- within their arc. For each ship that can fire at us we increment the
        -- number of arcs.
        for _, enemy_ship in pairs(enemies_in_arc) do
            local enemy_arc = ArcCheck.GetTargetsInRelationToArc(enemy_ship.ship, enemy_ship.ship.call('GetAllArcs'),
                { ship })
            enemy_arc = table.sieve(enemy_arc, AIModule.FilterInArc)
            enemy_arc = table.sieve(enemy_arc, AIModule.FilterInRange)
            for _ in pairs(enemy_arc) do
                probe.num_enemy_arcs[condition_index] = probe.num_enemy_arcs[condition_index] + 1
                break
            end
        end

        AIModule.SetShipState(ship, original_position_rotation)
    end

    return probe.num_enemy_arcs[condition_index] >= min_enemies
end

AIModule.condition_functions.hasCoordinateTarget = function(ship, target, probe, arguments)
    if probe.action_targets.coordinate == nil then
        probe.action_targets.coordinate = false

        -- Range two is 200mm, so triple it to 600mm to be sure of not missing
        -- anything once we take bases into account.
        local friendly_ships = ArcCheck.GetShipsWithinRange(ship, 600, false, true)

        local closest_distance = nil
        for _, friendly_ship in pairs(friendly_ships) do
            local distance = ArcCheck.GetDistanceBetweenShips(ship, friendly_ship)
            if distance ~= nil then
                -- Are we are the right range for coordinate?
                if distance.range >= 1 and distance.range <= 2 then
                    -- Is the ship not stressed?
                    if TokenModule.GetShipTokenCount(friendly_ship, "Stress") == 0 then
                        --[[ TODO: appears to be an error with counting stress tokens?
                                Are we closer than the previously closest ship? ]]
                        if closest_distance == nil or closest_distance > distance.length then
                            probe.action_targets.coordinate = friendly_ship
                            closest_distance = distance.length
                        end
                    end
                end
            end
        end
    end

    return probe.action_targets.coordinate ~= false
end

--------
-- MAIN MOVEMENT MODULE
-- Lets us move ships around and handles what comes with moving

MoveModule = {}

-- Convert a typical entry from MoveData functions
-- (this: {xPos_offset, yPos_offset, zPos_offset, yRot_offset} )
-- to a real ship position in world
MoveModule.EntryToPos = function(entry, shipPos)
    local basePos = nil
    local baseRot = nil
    if type(shipPos) == 'userdata' then
        basePos = shipPos.getPosition()
        baseRot = shipPos.getRotation()
    elseif type(shipPos) == 'table' then
        basePos = shipPos.pos
        baseRot = shipPos.rot
    end
    local finalPos = MoveData.ConvertDataToIGU(entry)
    local finalRot = entry[4] + baseRot[2]
    finalPos = Vect.RotateDeg(finalPos, baseRot[2] + 180)
    finalPos = Vect.Sum(basePos, finalPos)
    return { pos = finalPos, rot = { 0, finalRot, 0 } }
end

-- Get the position for a ship if it did a full move
-- Returned position and rotation are ready to feed TTS functions with
MoveModule.GetFullMove = function(move, ship)
    local entry = MoveData.DecodeFullMove(move, ship)
    return MoveModule.EntryToPos(entry, ship)
end

-- Get the position for a ship if it did a part of a move
-- Returned position and rotation are ready to feed TTS functions with
MoveModule.GetPartMove = function(move, ship, part)
    local entry = MoveData.DecodePartMove(move, ship, part)
    return MoveModule.EntryToPos(entry, ship)
end


-- HISTORY HANDLING:
-- Lets us undo, redo and save positions a ship was seen at

-- History table: {ship=shipRef, actKey=keyOfHistoryEntryShipWasLastSeenAt (._.), history=entryList}
-- Entry list: {entry1, entry2, entry3, ...}
-- Entry: {pos=position, rot=rotation, move=moveThatGotShipHere, part=partOfMovePerformed}
MoveModule.moveHistory = {}

-- Hostory-related commads
XW_cmd.AddCommand('[qz]', 'historyHandle')
XW_cmd.AddCommand('undo', 'historyHandle')
XW_cmd.AddCommand('redo', 'historyHandle')
XW_cmd.AddCommand('keep', 'historyHandle')

-- Return history of a ship
MoveModule.GetHistory = function(ship)
    for k, hist in pairs(MoveModule.moveHistory) do
        if hist.ship == ship then
            return hist
        end
    end
    table.insert(MoveModule.moveHistory, { ship = ship, actKey = 0, history = {} })
    return MoveModule.GetHistory(ship)
end

-- Erase all history "forward" from the current state
-- Happens when you undo and then do a move - all positions you undid are lost
MoveModule.ErasePastCurrent = function(ship)
    local histData = MoveModule.GetHistory(ship)
    local k = 1
    while histData.history[histData.actKey + k] ~= nil do
        histData.history[histData.actKey + k] = nil
        k = k + 1
    end
end

-- Print history, just for debug
MoveModule.PrintHistory = function(ship)
    local histData = MoveModule.GetHistory(ship)
    if histData.actKey == 0 then
        print(ship.getName() .. ': NO HISTORY')
    else
        print(ship.getName() .. '\'s HISTORY:')
        local k = 1
        while histData.history[k] ~= nil do
            local entry = histData.history[k]
            local typeStr = ' (' .. entry.finType
            if entry.part ~= nil then
                typeStr = typeStr .. ':' .. entry.part .. ')'
            else
                typeStr = typeStr .. ')'
            end
            if k == histData.actKey then
                print(' >> ' .. entry.move .. typeStr)
            else
                print(' -- ' .. entry.move .. typeStr)
            end
            k = k + 1
        end
        print(' -- -- -- -- ')
    end
end

-- Save <some> ship position to the history
-- Saves on the position after current and deletes any past that
MoveModule.AddHistoryEntry = function(ship, entry)
    local histData = MoveModule.GetHistory(ship)
    histData.actKey = histData.actKey + 1
    histData.history[histData.actKey] = entry
    MoveModule.ErasePastCurrent(ship)
end

-- How much position can be offset to be considered 'same'
MoveModule.undoPosCutoff = Dim.Convert_mm_igu(1)
-- How much rotation can be offset to be considered 'same'
MoveModule.undoRotCutoffDeg = 1

-- Check if the ship is on the curent history position (tolerance above)
MoveModule.IsAtSavedState = function(ship)
    local histData = MoveModule.GetHistory(ship)
    if histData.actKey > 0 then
        local currEntry = histData.history[histData.actKey]
        local dist = Vect.Distance(ship.getPosition(), currEntry.pos)
        local angDiff = math.abs(ship.getRotation()[2] - currEntry.rot[2])
        if math.abs(angDiff) > 180 then
            angDiff = math.abs(angDiff - math.sgn(angDiff) * 360)
        end
        return (dist < MoveModule.undoPosCutoff and angDiff < MoveModule.undoRotCutoffDeg)
    end
    return false
end

-- Save curent ship position to the history
-- Can be quiet when not explicitly called by the user
MoveModule.SaveStateToHistory = function(ship, beQuiet)
    local histData = MoveModule.GetHistory(ship)
    -- Don't add an entry if it's current position/rotation
    if MoveModule.IsAtSavedState(ship) then
        if beQuiet ~= true then
            AnnModule.Announce({ type = 'historyHandle', note = 'already has current position saved' }, 'all', ship)
        end
    else
        local entry = {
            pos = ship.getPosition(),
            rot = ship.getRotation(),
            move = 'position save',
            part = nil,
            finType = 'special'
        }
        MoveModule.AddHistoryEntry(ship, entry)
        if beQuiet ~= true then
            AnnModule.Announce({ type = 'historyHandle', note = 'stored current position' }, 'all', ship)
        end
    end
end

-- Move a ship to a previous state from the history
-- Return true if action was taken
-- Return false if there is no more data
MoveModule.UndoMove = function(ship)
    local histData = MoveModule.GetHistory(ship)
    local announceInfo = { type = 'historyHandle' }
    -- No history
    if histData.actKey == 0 then
        announceInfo.note = 'has no more moves to undo'
    else
        -- There is history
        local currEntry = histData.history[histData.actKey]
        -- current position not matching history
        if not MoveModule.IsAtSavedState(ship) then
            MoveModule.MoveShip(ship, { finPos = { pos = currEntry.pos, rot = currEntry.rot }, noSave = true })
            announceInfo.note = 'moved to the last saved position'
        else
            -- current position matching current histor
            if histData.actKey > 1 then
                local undidMove = currEntry.move
                histData.actKey = histData.actKey - 1
                currEntry = histData.history[histData.actKey]
                MoveModule.MoveShip(ship, { finPos = { pos = currEntry.pos, rot = currEntry.rot }, noSave = true })
                announceInfo.note = 'performed an undo of (' .. undidMove .. ')'
            else
                -- There is no data to go back to
                announceInfo.note = 'has no more moves to undo'
            end
        end
    end
    AnnModule.Announce(announceInfo, 'all', ship)
    return shipMoved
end

-- Move a ship to next state from the history
MoveModule.RedoMove = function(ship)
    local histData = MoveModule.GetHistory(ship)
    local announceInfo = { type = 'historyHandle' }
    -- No history
    if histData.actKey == 0 then
        announceInfo.note = 'has no more moves to redo'
    else
        -- There is history
        if histData.history[histData.actKey + 1] == nil then
            -- No more moves forward
            announceInfo.note = 'has no more moves to redo'
        else
            -- Move forward
            histData.actKey = histData.actKey + 1
            local currEntry = histData.history[histData.actKey]
            MoveModule.MoveShip(ship, { finPos = { pos = currEntry.pos, rot = currEntry.rot }, noSave = true })
            announceInfo.note = 'performed a redo of (' .. currEntry.move .. ')'
        end
    end
    AnnModule.Announce(announceInfo, 'all', ship)
    return shipMoved
end

-- Get the last move code from ship history
-- Always returns an "entry" table, if there's no move, move key is 'none'
MoveModule.GetLastMove = function(ship)
    local histData = MoveModule.GetHistory(ship)
    if histData.actKey < 1 then
        return { move = 'none' }
    else
        return table.shallowcopy(histData.history[histData.actKey])
    end
end

-- Get some old move from ship history (arg in number of moves back)
-- Always returns an "entry" table, if there's no move, move key is 'none'
MoveModule.GetOldMove = function(ship, numMovesBack)
    local histData = MoveModule.GetHistory(ship)
    if histData.actKey - numMovesBack < 1 then
        return { move = 'none' }
    else
        return table.shallowcopy(histData.history[histData.actKey - numMovesBack])
    end
end

-- THING THAT ALLOWS US TOR ESTORE SHIP POSITION AFTER IT WAS DELETED
-- Table of deleted ships last positions
MoveModule.emergencyRestore = {}
-- Pointer at the most recently added restore entry
MoveModule.restoreBufferPointer = 0
-- Max size of the restore entry table
MoveModule.restoreBufferSize = 25
-- Restore command
XW_cmd.AddCommand('restore#[1-9][0-9]?', 'historyHandle')

-- Try to restore some ship position to an entry with given key
MoveModule.Restore = function(ship, key)
    if #MoveModule.emergencyRestore < key or key <= 0 then
        AnnModule.Announce({ type = 'historyHandle', note = 'Restore key (number after the #) invalid' }, 'all')
        return false
    else
        local data = MoveModule.emergencyRestore[key]
        ship.setPosition(data.savedPos.pos)
        ship.setRotation(data.savedPos.rot)
        MoveModule.SaveStateToHistory(ship, true)
        AnnModule.Announce(
            { type = 'historyHandle', note = 'has been restored to position ' .. data.srcName .. ' was last seen at' },
            'all',
            ship)
        return true
    end
end

-- Save some restore data and notify the user of it
MoveModule.AddRestorePoint = function(entry)
    local newKey = MoveModule.restoreBufferPointer + 1
    if newKey > MoveModule.restoreBufferSize then
        newKey = 1
    end
    AnnModule.Announce(
        {
            type = 'historyHandle',
            note = entry.srcName ..
                '\'s ship has been deleted - you can respawn the model and use \'restore#' ..
                newKey .. '\' command to restore its position'
        }, 'all')
    MoveModule.emergencyRestore[newKey] = entry
    MoveModule.restoreBufferPointer = newKey
end

-- Handle destroyed objects
-- Create a restore entry from last set position in history
-- Delete history if present
MoveModule.onObjectDestroyed = function(obj)
    if not ObjType.IsOfType(obj, 'ship') then
        return
    end
    if MoveModule.GetLastMove(obj).move ~= 'none' then
        local lastMove = MoveModule.GetLastMove(obj)
        MoveModule.AddRestorePoint({ srcName = obj.getName(), savedPos = { pos = lastMove.pos, rot = lastMove.rot } })
    end
    for k, hist in pairs(MoveModule.moveHistory) do
        if hist.ship == ship then
            table.remove(MoveModule.moveHistory, k)
            break
        end
    end
end

-- Get the history table with "serialized" positions/rotations
-- I hate this so much
-- Devs, fix your shit, goddamnit
MoveModule.GetSaveData = function()
    local currHistory = {}
    for k, hist in pairs(MoveModule.moveHistory) do
        if hist.history[1] ~= nil then
            local currEntry = MoveModule.GetLastMove(hist.ship)
            currEntry.pos = TTS_Serialize(currEntry.pos)
            currEntry.rot = TTS_Serialize(currEntry.rot)
            table.insert(currHistory, { ship = hist.ship.getGUID(), actKey = 1, history = { currEntry } })
        end
    end
    if currHistory[1] == nil then
        return nil
    else
        return currHistory
    end
end


-- Restore provided table and notify of the results
MoveModule.RestoreSaveData = function(saveTable)
    if saveTable == nil then
        return
    end
    local count = 0
    local missCount = 0
    for k, hist in pairs(saveTable) do
        hist.ship = getObjectFromGUID(hist.ship)
        if hist.ship == nil then
            missCount = missCount + 1
        else
            count = count + 1
            table.insert(MoveModule.moveHistory, hist)
        end
    end
    local info = ' - Restored last position save for ' .. count .. ' ship(s)'
    if missCount > 0 then
        info = info .. ' (' .. missCount .. ' ship model(s) missing)'
    end
    if count > 0 or missCount > 0 then
        return info
    end
end

SaveManager.Register('MoveModule', MoveModule.GetSaveData, MoveModule.RestoreSaveData)

-- Join hit tables t1 .. t5 resulting from Physics.cast call
-- Return a table of unique objects that pass selection function
-- (apaprently cant use '...' arg type when a function is a table field)
-- Arguments:
--      exclObj     <- object excluded from return table (for casts over a ship)
--      SelectFun   <- function taking an object and returning true/false (obj type selection)
--      t1 .. t5    <- hit tables returned from Physics.cast, some can be nil or empty
-- Return:
--      Concatenated table of unique objects from hit tables that also passed selection function
MoveModule.JoinHitTables = function(exclObj, SelectFun, t1, t2, t3, t4, t5)
    local gTable = { [exclObj.getGUID()] = true }
    local out = {}
    local tbls = { a = t1, b = t2, c = t3, d = t4, e = t5 }
    for k, hTable in pairs(tbls) do
        for k2, hit in pairs(hTable) do
            if SelectFun(hit.hit_object) and gTable[hit.hit_object.getGUID()] == nil then
                gTable[hit.hit_object.getGUID()] = true
                table.insert(out, hit.hit_object)
            end
        end
    end
    return out
end

-- Selection function for MoveModule.JoinHitTables - ships only
MoveModule.SelectShips = function(obj)
    return ObjType.IsOfType(obj, 'ship')
end

-- Selection function for MoveModule.JoinHitTables - ships only
MoveModule.SelectRemotes = function(obj)
    return obj.hasTag('TargetableRemote')
end

-- Selection function for MoveModule.JoinHitTables - huge ships only
MoveModule.SelectHugeShips = function(obj)
    return MoveModule.SelectShips(obj) and (obj.getTable('Data').Size == 'huge')
end

-- Selection function for MoveModule.JoinHitTables - huge ships only
MoveModule.SelectShipsAndRemotes = function(obj)
    return MoveModule.SelectShips(obj) or MoveModule.SelectRemotes(obj)
end



-- Selection function for MoveModule.JoinHitTables - obstacles only
MoveModule.SelectObstacles = function(obj)
    local name = obj.getName()
    return obj.hasTag('Obstacle') or
        ((name:find('Asteroid') or name:find('Debris') or name:find('Chute debris') or name:find('Cloud') or name:find('Spare') or name:find('Obstacle')) ~= nil)
end

-- Selection function for MoveModule.JoinHitTables - mine tokens only
MoveModule.SelectMineTokens = function(obj)
    local name = obj.getName()
    return obj.hasTag('Mine') or
        ((name:find('Mine') or name:find('Connor') or name:find('Chute debris') or name:find('Probe') or name:find('Buzz')) ~= nil)
end

-- Selection function for MoveModule.JoinHitTables - mines and obstacles
MoveModule.SelectMinesAndObstacleTokens = function(obj)
    return MoveModule.SelectObstacles(obj) or MoveModule.SelectMineTokens(obj)
end

-- Selection function for MoveModule.JoinHitTables - anything aside from global table object
MoveModule.SelectAny = function(obj)
    return obj.getGUID() ~= nil
end

-- Cast data for checking collisions over a ship type shape
MoveModule.castData = {}
MoveModule.castData.small = {}
MoveModule.castData.small.base = {
    debug = cast_debug,
    direction = { 0, -0.001, 0 },
    type = 3,
    size = { Dim.Convert_mm_igu(40), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(40) },
    -- + Origin
    -- + Orientation
}
MoveModule.castData.small.nubFR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(20.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.small.nubFL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(20.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.small.nubBR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(20.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.small.nubBL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(20.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}

MoveModule.castData.medium = {}
MoveModule.castData.medium.base = {
    debug = cast_debug,
    direction = { 0, -0.001, 0 },
    type = 3,
    size = { Dim.Convert_mm_igu(60), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(60) },
    -- + Origin
    -- + Orientation
}
MoveModule.castData.medium.nubFR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(30.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.medium.nubFL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(30.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.medium.nubBR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(30.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.medium.nubBL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(30.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}

MoveModule.castData.large = {}
MoveModule.castData.large.base = {
    debug = cast_debug,
    direction = { 0, -0.001, 0 },
    type = 3,
    size = { Dim.Convert_mm_igu(80), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(80) },
    -- + Origin
    -- + Orientation
}
MoveModule.castData.large.nubFR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(40.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.large.nubFL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(40.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.large.nubBR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(40.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.large.nubBL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(40.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}

MoveModule.castData.huge = {}
MoveModule.castData.huge.base = {
    debug = cast_debug,
    direction = { 0, -0.001, 0 },
    type = 3,
    size = { Dim.Convert_mm_igu(80), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(221) },
    -- + Origin
    -- + Orientation
}
MoveModule.castData.huge.nubFR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(111.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.huge.nubFL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), -1 * Dim.Convert_mm_igu(111.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.huge.nubBR = {
    debug = cast_debug,
    localPos = { -1 * Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(111.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}
MoveModule.castData.huge.nubBL = {
    debug = cast_debug,
    localPos = { Dim.Convert_mm_igu(11.38), Dim.Convert_mm_igu(-1.86), Dim.Convert_mm_igu(111.858) },
    direction = { 0, -0.001, 0 },
    type = 2,
    size = { Dim.Convert_mm_igu(3.4), Dim.Convert_mm_igu(8), Dim.Convert_mm_igu(3.4) },
    -- + Origin
}



-- Get cast data for particular ship situation
-- Arguments:
--      ship        <- ship ref (for base size)
--      shipPosRot  <- table with ship check position and rotation ('pos' and 'rot' keys)
--      castType    <- 'base' for base, 'nub[FB][RL]' for one of four nubs
-- Return:
--      Table ready to be fed to Physics.cast
MoveModule.GetCast = function(ship, shipPosRot, castType)
    local baseSize = ship.getTable("Data").Size or 'small'
    local castTable = MoveModule.castData[baseSize][castType]
    --castTable.debug = true
    if castType == 'base' then
        castTable.origin = shipPosRot.pos
        castTable.orientation = shipPosRot.rot
        return castTable
    else
        castTable.origin = Vect.Sum(shipPosRot.pos, Vect.RotateDeg(castTable.localPos, shipPosRot.rot[2]))
        return castTable
    end
end

-- Return all objects that pass selection function and would overlap ship in some situation
-- Arguments:
--      ship        <- ship ref (for base size)
--      shipPosRot  <- table with ship check position and rotation ('pos' and 'rot' keys)
--      SelectFun   <- selection function that returns true/false for an object
-- Return:
--      Concatenated table of all objects that would overlap ship in this situation and pass select function
MoveModule.FullCastCheck = function(ship, shipPosRot, SelectFun)
    return MoveModule.JoinHitTables(
        ship,
        SelectFun,
        Physics.cast(MoveModule.GetCast(ship, shipPosRot, 'base')),
        Physics.cast(MoveModule.GetCast(ship, shipPosRot, 'nubFR')),
        Physics.cast(MoveModule.GetCast(ship, shipPosRot, 'nubFL')),
        Physics.cast(MoveModule.GetCast(ship, shipPosRot, 'nubBR')),
        Physics.cast(MoveModule.GetCast(ship, shipPosRot, 'nubBL'))
    )
end

-- Return all objects that pass selection function and would overlap a template in some situation
-- Arguments:
--      excludeObj   <- Object to exclude from overlapping
--      collList     <- List of already hit objects (from base overlapping)
--      templateData <- table with information on origin, orientation, speed, type and direction
--      SelectFun   <- selection function that returns true/false for an object
-- Return:
--      Concatenated table of all objects that would overlap ship in this situation and pass select function
MoveModule.TemplateCastCheck = function(excludeObj, collList, templateData, SelectFun)
    local gTable = { [excludeObj.getGUID()] = true }

    for k, coll in pairs(collList) do
        gTable[coll.getGUID()] = true
    end

    -- Find template origin and do special handling of special manouvers
    local templateOrigin = {}
    if templateData.extra == "reverse" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, "back")
        if templateData.dir == "left" then
            templateData.dir = "right"
        elseif templateData.dir == "right" then
            templateData.dir = "left"
        end
    elseif templateData.type == "straight" or templateData.type == "bank" or templateData.type == "turn" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, "front")
    elseif templateData.type:find("talon") then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, "front")
        templateData.type = "turn"
    elseif templateData.type == "roll" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        templateData.speed = 1
    elseif templateData.type == "viperF" or templateData.type == "viperB" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        if templateData.dir == "right" and templateData.extra == "forward" then
            templateData.dir = "left"
        elseif templateData.dir == "left" and templateData.extra == "backward" then
            templateData.dir = "right"
        end
        templateData.speed = 1
        templateData.type = "bank"
    elseif templateData.type == "viperTurnF" or templateData.type == "viperTurnB" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        if templateData.dir == "right" and templateData.extra == "forward" then
            templateData.dir = "left"
        elseif templateData.dir == "left" and templateData.extra == "backward" then
            templateData.dir = "right"
        end
        templateData.speed = 1
        templateData.type = "turn"
    elseif templateData.type == "bankSlip" then
        local template_pos = "left"
        if templateData.dir == "left" then
            template_pos = "right"
        end
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, template_pos)
        templateData.type = "bank"
    elseif templateData.type == "turnSlip" then
        local template_pos = "left"
        if templateData.dir == "left" then
            template_pos = "right"
        end
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, template_pos)
        templateData.type = "turn"
    elseif templateData.type == "echoF" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        templateData.speed = 2
        templateData.type = "bank"
        if templateData.dir == "right" then
            templateData.dir = "left"
        elseif templateData.dir == "left" then
            templateData.dir = "right"
        end
    elseif templateData.type == "echoB" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        templateData.speed = 2
        templateData.type = "bank"
    elseif templateData.type == "deCloak" then
        templateOrigin = MoveModule.GetTemplateOrigin(templateData.origin, templateData.orientation,
            templateData.shipSize, templateData.dir)
        if templateData.shipSize == "small" then
            templateData.speed = 2
        else
            templateData.speed = 1
        end
    else
        return
    end

    if templateData.type == "straight" or templateData.type == "roll" or templateData.type == "deCloak" then
        local offsetDistance = Dim.Convert_mm_igu(20) * tonumber(templateData.speed)
        local size = { Dim.Convert_mm_igu(20), Dim.Convert_mm_igu(6), templateData.speed * Dim.Convert_mm_igu(40) }
        if (templateData.type == "roll" or templateData.type == "deCloak") and templateData.shipSize ~= "small" then
            size = { Dim.Convert_mm_igu(40), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(20) }
            offsetDistance = Dim.Convert_mm_igu(10)
        end
        local offset = vector(offsetDistance * math.sin(math.rad(templateOrigin.rot.y)),
            0, offsetDistance * math.cos(math.rad(templateOrigin.rot.y)))

        local collissions = Physics.cast({
            origin = templateOrigin.pos + offset,
            orientation = templateOrigin.rot,
            direction = { 0, -0.001, 0 },
            type = 3,
            size = size,
            max_distance = 1,
            debug = cast_debug
        })

        MoveModule.AddCollissionEntry(gTable, collList, collissions, SelectFun)
    elseif templateData.type == "bank" then
        local radius = 0
        local iterations = 0
        if templateData.speed == 1 then
            radius = Dim.Convert_mm_igu(80)
            iterations = 10
        elseif templateData.speed == 2 then
            radius = Dim.Convert_mm_igu(130)
            iterations = 15
        elseif templateData.speed == 3 then
            radius = Dim.Convert_mm_igu(180)
            iterations = 20
        end
        local radianStep = math.pi / (4 * iterations)
        local dir_mod = 1
        if templateData.dir == "left" then
            dir_mod = -1
        end
        local c = math.cos(math.rad(templateOrigin.rot.y))
        local s = math.sin(math.rad(templateOrigin.rot.y))
        for i = 0, iterations do
            local radians = radianStep * i
            local orientation_offset = vector(0, math.deg(radians), 0)
            -- Calculate world position for template
            local pz = math.sin(radians) * radius
            local px = dir_mod * (1 - math.cos(radians)) * radius
            -- Translate point to template origin
            local position_offset = vector(px * c + pz * s, 0, pz * c - px * s)

            local collissions = Physics.cast({
                origin = templateOrigin.pos + position_offset,
                orientation = templateOrigin.rot + orientation_offset * dir_mod,
                direction = { 0, -0.001, 0 },
                type = 3,
                size = { Dim.Convert_mm_igu(20), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(1) },
                max_distance = 1,
                debug = cast_debug
            })
            MoveModule.AddCollissionEntry(gTable, collList, collissions, SelectFun)
        end
    elseif templateData.type == "turn" then
        local radius = 0
        if templateData.speed == 1 then
            radius = Dim.Convert_mm_igu(35)
        elseif templateData.speed == 2 then
            radius = Dim.Convert_mm_igu(62)
        elseif templateData.speed == 3 then
            radius = Dim.Convert_mm_igu(90)
        end
        local iterations = 10
        local radianStep = math.pi / (2 * iterations)
        local dir_mod = 1
        if templateData.dir == "left" then
            dir_mod = -1
        end
        local c = math.cos(math.rad(templateOrigin.rot.y))
        local s = math.sin(math.rad(templateOrigin.rot.y))
        for i = 0, iterations do
            local radians = radianStep * i
            local orientation_offset = vector(0, math.deg(radians), 0)
            -- Calculate world position for template
            local pz = math.sin(radians) * radius
            local px = dir_mod * (1 - math.cos(radians)) * radius
            -- Translate point to template origin
            local position_offset = vector(px * c + pz * s, 0, pz * c - px * s)

            local collissions = Physics.cast({
                origin = templateOrigin.pos + position_offset,
                orientation = templateOrigin.rot + orientation_offset * dir_mod,
                direction = { 0, -0.001, 0 },
                type = 3,
                size = { Dim.Convert_mm_igu(20), Dim.Convert_mm_igu(6), Dim.Convert_mm_igu(1) },
                max_distance = 1,
                debug = cast_debug
            })
            MoveModule.AddCollissionEntry(gTable, collList, collissions, SelectFun)
        end
    end
end


-- Adds objects from the collissions table to the collList if it pass the selectfun
-- and is not already present
-- Arguments:
--      gTable          <- GUID table, containing allready present objects
--      collList        <- List of hit objects that have passed the select fun
--      collissions     <- Table of hits returned from a Physics.cast()
--      SelectFun       <- Function that returns true if object if of correct type
MoveModule.AddCollissionEntry = function(gTable, collList, collissions, SelectFun)
    for k, hit in pairs(collissions) do
        if gTable[hit.hit_object.getGUID()] == nil and SelectFun(hit.hit_object) then
            gTable[hit.hit_object.getGUID()] = true
            table.insert(collList, hit.hit_object)
        end
    end
end

-- Return all position and rotation for a template originating position based on ship size and direction
-- Arguments:
--      shipOrigin      <- The ship origin
--      shipOrientation <- Orientation of the ship
--      shipSize        <- Size of the ship (small, medium, large)
--      templateDir     <- Which direction to get position and orientation for
-- Return:
--      TemplateOrigin (position and rotation)
MoveModule.GetTemplateOrigin = function(shipOrigin, shipOrientation, shipSize, templateDir)
    -- OBS: Ships are placed backwards
    roty = shipOrientation.y + 180
    if templateDir == "left" then
        roty = roty - 90
    elseif templateDir == "right" then
        roty = roty + 90
    elseif templateDir == "back" then
        roty = roty - 180
    end

    local distance = Dim.Convert_mm_igu(20)
    if shipSize == "medium" then
        distance = Dim.Convert_mm_igu(30)
    elseif shipSize == "large" then
        distance = Dim.Convert_mm_igu(40)
    end

    local position = shipOrigin + vector(distance * math.sin(math.rad(roty)), 0, distance * math.cos(math.rad(roty)))

    return { pos = position, rot = vector(shipOrientation.x, roty, shipOrientation.z) }
end


-- Check if provided ship in a provided position/rotation would collide with anything from the provided table
-- Return: {coll=collObject, minMargin=howFarCollisionIsStillCertain, numCheck=numCollideChecks}
MoveModule.CheckCollisions = function(ship, shipPosRot, collShipTable)
    local info = { coll = nil, minMargin = 0, numCheck = 0, numCast = 0 }
    local shipInfo = { pos = shipPosRot.pos, rot = shipPosRot.rot, ship = ship }
    local shipSize = ship.getTable("Data").Size or 'small'
    local certShipReach = Dim.Convert_mm_igu(Dim.mm_baseSize[shipSize] / 2)               -- distance at which other ships MUST bump it
    local maxShipReach = Dim.Convert_mm_igu(Dim.mm_baseSize[shipSize] * math.sqrt(2) / 2) -- distance at which other ships CAN bump it

    --for k, collShip in pairs(collShipTable) do
    --    local collShipSize = collShip.getTable("Data").Size or 'small'
    --    local certBumpDist = certShipReach + Dim.Convert_mm_igu(Dim.mm_baseSize[collShipSize]/2)            -- distance at which these two particular ships ships MUST bump
    --    local maxBumpDist = maxShipReach + Dim.Convert_mm_igu(Dim.mm_baseSize[collShipSize]*math.sqrt(2)/2) -- distance at which these two particular ships ships CAN bump
    --
    --        local dist = Vect.Distance(shipPosRot.pos, collShip.getPosition())
    --        if dist < maxBumpDist then
    --            if dist < certBumpDist then
    --                info.coll = collShip
    --                if certBumpDist - dist > info.minMargin then
    --                    info.minMargin = certBumpDist - dist
    --                end
    --            elseif collide(shipInfo, {pos=collShip.getPosition(), rot=collShip.getRotation(), ship=collShip}) == true then
    --                info.coll = collShip
    --                info.numCheck = info.numCheck + 1
    --                break
    --            end
    --        end
    --    end
    if info.coll == nil then
        local hTable = {}
        if shipSize == 'huge' then
            hTable = MoveModule.FullCastCheck(ship, shipPosRot, MoveModule.SelectHugeShips)
        else
            hTable = MoveModule.FullCastCheck(ship, shipPosRot, MoveModule.SelectShips)
        end
        info.coll = hTable[1]
        info.collidingShips = hTable
    end
    return info
end

MoveModule.partResolutionRough = 1 / 100 -- Resolution for rough checks (guaranteed)
MoveModule.partResolutionFine = 1 / 1000 -- Resolution for fine checks  (for forward adjust)

-- Module for trying and finding free positions
MoveModule.MoveProbe = {}

-- Get near ships when trying a move that allows for partial execution
-- Args: SEE MoveModule.MoveProbe.GetFreePart
-- Return: {shipRef1, shipRef2, ... , shipRefN}
MoveModule.MoveProbe.GetShipsNearPart = function(info, ship, partFun, partRange)
    local middlePart = (partRange.to - partRange.from) / 2
    local maxShipReach = Dim.Convert_mm_igu(Dim.mm_baseSize[info.size] * math.sqrt(2)) / 2
    local moveReach = math.max(
        Vect.Distance(partFun(info.code, ship, middlePart).pos, partFun(info.code, ship, partRange.to).pos),
        Vect.Distance(partFun(info.code, ship, middlePart).pos, partFun(info.code, ship, partRange.from).pos))
    local collShipRange = moveReach + maxShipReach + Dim.Convert_mm_igu(Dim.mm_largeBase * math.sqrt(2)) / 2 +
        Dim.Convert_mm_igu(10)
    return ObjType.GetNearOfType(partFun(info.code, ship, MoveData.partMax / 2).pos, collShipRange, 'ship', { ship })
end
-- Get first free part for a partial-enabled move (going through parts as partRange specifies)
-- Args:
--      info        <- move info as per MoveData.DecodeInfo
--      ship        <- object ref to a ship we want to move
--      partFun     <- function that takes (moveInfo, shipRef, part) and returns {pos=position, rot=rotation} (pure data, ignores collisions)
--      partRange   <- { from = partValueFromToCheck, to = partValueToCheckTo} ((from < to), (from > to) and (from == to) to all handled)
-- Return:  {
--      part        <- number of the part that was last checked (first free if other args specify free part was found)
--      info        <- nil if free part was found sowmehere, 'first' if partRange.from was free, 'overlap' if no part was free
--      collObj     <- nil if first part was free, object ref to last colliding ship otherwise
--          }
MoveModule.MoveProbe.GetFreePart = function(info, ship, partFun, partRange, moveLength)
    if moveLength == nil then
        moveLength = 0
    end
    moveLength = Dim.Convert_mm_igu(moveLength)
    local out = { part = nil, info = nil, collObj = nil }
    local checkNum = { rough = 0, fine = 0 }

    -- Get ships that *can* possibly collide during this move
    local collShips = MoveModule.MoveProbe.GetShipsNearPart(info, ship, partFun, partRange)

    -- Current part and part delts for ROUGH CHECKING
    local actPart = partRange.from
    local partDelta = math.sgn(partRange.to - partRange.from) * (MoveData.partMax * MoveModule.partResolutionRough)
    local minPartDelta = math.abs(partDelta)
    local collision = false

    -- Collision check, then part delta step or margin step
    repeat
        local nPos = partFun(info.code, ship, actPart)
        local collInfo = MoveModule.CheckCollisions(ship, nPos, collShips)
        checkNum.rough = checkNum.rough + collInfo.numCheck
        local distToSkip = nil
        if collInfo.coll ~= nil then
            collision = true
            distToSkip = collInfo.minMargin
            -- If there is a distance we can travel that assures collison will not end
            if distToSkip > 0 then
                -- Calculate how big part it is and skip away
                partDelta = math.sgn(partDelta) * ((distToSkip * MoveData.partMax) / moveLength)
                if math.abs(partDelta) < minPartDelta then
                    partDelta = math.sgn(partDelta) * minPartDelta
                end
            else
                partDelta = math.sgn(partDelta) * minPartDelta
            end
        else
            collision = false
        end
        if collision == true then
            out.collObj = collInfo.coll
            actPart = actPart + partDelta
        end
        -- until we're out of collisions OR we're out of part range
    until collision == false or ((partRange.to - actPart) * math.sgn(partDelta) < 0) or partDelta == 0

    if collision == false and partDelta ~= 0 and actPart ~= partRange.from then
        -- Right now, we're out of any collisions or at part 0 (no move)
        -- Go fineResolution of a move forward until we have a collision, then skip one back
        partDelta = math.sgn(partRange.to - partRange.from) * (MoveData.partMax * MoveModule.partResolutionFine) * -1
        local collInfo = nil
        repeat
            local nPos = partFun(info.code, ship, actPart)
            collInfo = MoveModule.CheckCollisions(ship, nPos, { out.collObj })
            checkNum.fine = checkNum.fine + collInfo.numCheck
            if collInfo.coll ~= nil then
                collision = true
            else
                collision = false
            end
            actPart = actPart + partDelta
        until collision == true or (partRange.from - actPart) * math.sgn(partDelta) < 0
        actPart = actPart - 2 * partDelta
        out.collObj = collInfo.coll -- This is what we hit
        out.part = actPart
    elseif collision == false then
        -- This happens if rough check didn't do anything (first part free, but no fullMove function)
        out.part = actPart
        out.info = 'first'
    elseif collision == true then
        -- This happens if rough check didn't escape collisions (no free part)
        out.info = 'overlap'
        out.part = partRange.to
    end
    -- print('-- GetFreePart CHECK_COUNT: ' .. checkNum.rough+checkNum.fine .. ' (' .. checkNum.rough .. ' + ' .. checkNum.fine .. ')')
    return out
end
-- Get near ships when trying a move that only allows for full execution
-- Args: SEE MoveModule.MoveProbe.TryFullMove
-- Return: {shipRef1, shipRef2, ... , shipRefN}
MoveModule.MoveProbe.GetShipsNearFull = function(info, ship, fullFun)
    local maxShipReach = Dim.Convert_mm_igu(Dim.mm_baseSize[info.size] * math.sqrt(2)) / 2
    local collShipRange = maxShipReach + Dim.Convert_mm_igu(Dim.mm_largeBase * math.sqrt(2)) / 2 + Dim.Convert_mm_igu(10)
    return ObjType.GetNearOfType(fullFun(info.code, ship).pos, collShipRange, 'ship', { ship })
end

-- Get near huge ships when trying a move that only allows for full execution
-- Args: SEE MoveModule.MoveProbe.TryFullMove
-- Return: {shipRef1, shipRef2, ... , shipRefN}
MoveModule.MoveProbe.GetHugeShipsNearFull = function(info, ship, fullFun)
    local shipsfound = MoveModule.MoveProbe.GetShipsNearFull(info, ship, fullFun)
    shipsfound = table.sieve(shipsfound, function(obj)
        return (obj.getTable('Data').Size == 'huge')
    end)
    return shipsfound
end

-- Try a full version of a move
-- Args:
--      info        <- move info as per MoveData.DecodeInfo
--      ship        <- object ref to a ship we want to move
--      fullFun     <- function that takes (moveInfo, shipRef) and returns {pos=position, rot=rotation} (pure data, ignores collisions)
-- Return:  {
--      done        <- TRUE if move was completed, FALSE if it was obstructed
--      finalPosRot <- the final position and rotation after this move
--      collObj     <- nil if completed, object ref to colliding ship otherwise
--      collObs     <- nil if no obstacle moved over, object ref to obstacle if otherwise
--          }
MoveModule.MoveProbe.TryFullMove = function(info, ship, fullFun)
    local collShips = nil
    if info.size == 'huge' then
        collShips = MoveModule.MoveProbe.GetHugeShipsNearFull(info, ship, fullFun)
    else
        collShips = MoveModule.MoveProbe.GetShipsNearFull(info, ship, fullFun)
    end
    local out = { done = nil, finalPosRot = nil, collObj = nil, collObs = nil }
    local checkNum = 0

    local startPosRot = { ['pos'] = ship.GetPosition(), ['rot'] = ship.GetRotation() }
    local finalPosRot = fullFun(info.code, ship)
    out.finalPosRot = finalPosRot

    -- Ship-to-ship collisions
    fullInfo = MoveModule.CheckCollisions(ship, finalPosRot, collShips)
    checkNum = checkNum + fullInfo.numCheck
    if fullInfo.coll == nil then
        out.done = true
    else
        out.done = false
        out.collObj = fullInfo.coll
        out.friendlyCollission = false
        local shipOwner = ship.getVar("owningPlayer")
        for _, colship in pairs(fullInfo.collidingShips or {}) do
            if colship.getVar("owningPlayer") == shipOwner then
                out.friendlyCollission = true
            end
        end
    end

    -- Ship-to-obstacle collisions
    -- Get any obstacles that we're currently overlapping, and ignore them
    -- for the template check (but not for the final position check)
    local startingObstacleCollisions = MoveModule.CheckMineAndObstacleCollisions(ship, startPosRot, false, nil)

    local templateData = {
        origin = ship.GetPosition(),
        orientation = ship.GetRotation(),
        dir = info.dir,
        speed = info.speed,
        type = info.type,
        shipSize = info.size,
        extra = info.extra
    }
    -- Do the template and final position check
    local endingObstacleCollisions = MoveModule.CheckMineAndObstacleCollisions(ship, finalPosRot, false, templateData,
        startingObstacleCollisions)
    if #endingObstacleCollisions ~= 0 then
        out.collObs = endingObstacleCollisions[1]
    end

    return out
end

-- Get the FINAL position for a given move, including partial move and collisions
-- Follows traits from MoveData.DecodeInfo to try different move functions
-- Return:  {
--      finType     <- 'move' when did full/part mvoe
--                     'stationary' when there was no position change (rotation change allowed)
--                     'overlap' if there was no valid free target position
--                     IF OVERLAP, OTHER KEYS ARE TO BE IGNORED
--      finPos      <- { pos = finalPosition, rot = finalRotation }
--      collObj     <- nil if no collision, object ref to colliding ship otherwise
--      finPart     <- part of partial move performed, 'max' if full move, nil if not applicable
--          }
MoveModule.GetFinalPosData = function(move_code, ship, ignoreCollisions)
    local out = { finPos = nil, collObj = nil, finType = nil, finPart = nil, friendlyCollission = false }
    local info = MoveData.DecodeInfo(move_code, ship)

    -- Don't bother with collisions if it's stationary
    if info.size ~= 'huge' and info.speed == 0 then
        ignoreCollisions = true
    end

    -- NON-COLLISION VERSION
    if ignoreCollisions then
        if info.traits.full == true then
            -- If full moves are allowed, get a full move
            out.finPos = MoveModule.GetFullMove(info.code, ship)
            if info.speed == 0 then
                out.finType = 'stationary'
            else
                out.finType = 'move'
            end
            out.finPart = 'max'
            return out
        elseif info.traits.part == true then
            -- If partial moves are allowed, get max part move
            out.finPos = MoveModule.GetPartMove(info.code, ship, MoveData.partMax)
            out.finType = 'move'
            out.finPart = 'max'
            return out
        end

        -- COLLISION VERSION
    else
        -- If move allows for full move check, try it
        if info.traits.full == true then
            local fullData = MoveModule.MoveProbe.TryFullMove(info, ship, MoveModule.GetFullMove)
            out.friendlyCollission = fullData.friendlyCollission
            while info.size == 'huge' and fullData.done == false do
                out.collObj = fullData.collObj
                info.speed = info.speed - 1
                info.extra = nil
                if info.speed == -1 then
                    out.finType = 'overlap'
                    out.finPos = { pos = ship.getPosition(), rot = ship.getRotation() }
                    return out
                else
                    info.code = string.gsub(info.code, "%d", info.speed)
                    info.code = string.gsub(info.code, "k", "s")
                end
                fullData = MoveModule.MoveProbe.TryFullMove(info, ship, MoveModule.GetFullMove)
            end
            if fullData.done == true then
                out.finPos = MoveModule.GetFullMove(info.code, ship)
                out.finType = 'move'
                out.finPart = 'max'
                return out
            end
        end
        -- If move allows for partial execution, try to find a free part
        if info.traits.part == true then
            local partRange = { from = MoveData.partMax, to = 0 }
            local freePartData = MoveModule.MoveProbe.GetFreePart(info, ship, MoveModule.GetPartMove, partRange,
                MoveData.MoveLength(info))
            if freePartData.info ~= 'overlap' then
                out.finPos = MoveModule.GetPartMove(info.code, ship, freePartData.part)
                out.finType = 'move'
                out.finPart = freePartData.part
                out.collObj = freePartData.collObj
                return out
            end
        end
        -- If nothing worked out, we have an all-overlap
        out.finType = 'overlap'
        out.finPos = { pos = ship.getPosition(), rot = ship.getRotation() }
        return out
    end
end


-- Move ship to some position and handle stuff around it
-- If move is not stationary, clear target position and move tokens with it
-- Add history entry if save move name is provided
-- Args:
--      ship        <- object reference to ship to move
--      finData     <- {pos = targetPos, rot=targetRot}
--      saveName    <- move code for history save, no save done if nil
--      finFunction <- optional, function to call when the ship has come to rest
--      waitForTokens <- optional, whether or not we have to wait for the ships tokens to also come to a rest
MoveModule.MoveShip = function(ship, finData, saveName, finFunction, waitForTokens)
    if not ShipVerification.VerifyShipBase(ship) then
        return
    end
    XW_cmd.SetBusy(ship)
    MoveModule.RemoveOverlapReminder(ship)
    if finData.type ~= 'stationary' then
        TokenModule.QueueShipTokensMove(ship)
        local baseSize = ship.getTable("Data").Size or 'small'
        local shipReach = Dim.Convert_mm_igu(Dim.mm_baseSize[baseSize] + 5) * (math.sqrt(2) / 2)
        TokenModule.ClearPosition(finData.finPos.pos, shipReach, ship)
    end
    local finPos = finData.finPos
    if finData.noSave ~= true then
        MoveModule.SaveStateToHistory(ship, true)
    end
    ship.setPositionSmooth(finPos.pos, false, true)
    ship.setRotationSmooth(finPos.rot, false, true)
    -- Wait for resting, but provide final position to set so smooth move doesn't fuck with accuracy
    MoveModule.WaitForResting(ship, finPos, finFunction, waitForTokens)
    if saveName ~= nil then
        MoveModule.AddHistoryEntry(ship,
            { pos = finPos.pos, rot = finPos.rot, move = saveName, part = finData.finPart, finType = finData.finType })
    end
end



-- This part controls the waiting part of moving
-- Basically, if anything needs to be done after the ship rests, this can trigger it

-- Ships waiting to be resting
-- Entry: {ship = shipRef, finPos={pos=posToSet, rot=rotToSet}}
MoveModule.restWaitQueue = {}

-- Tokens waiting to be moved with ships
-- Entry: { tokens={t1, t2, ... , tN}, ship=shipWaitingFor }
-- tX: {ref = tokenRef, relPos = pos, relRot = rot}
-- elements wait here until ships are ready
MoveModule.tokenWaitQueue = {}

-- Add ship to the queue so it fires once it completes the move
-- OPTIONAL: finPos     <- position to be set at the end of the wait
-- OPTIONAL: finFun     <- function to be execeuted at the end of the wait (argument: waiting ship)
-- OPTIONAL: tokens     <- whether we also have to wait for the ship's tokens to finish moving afterwards.
MoveModule.WaitForResting = function(ship, finPos, finFun, waitForTokens)
    table.insert(MoveModule.restWaitQueue,
        { ship = ship, finPos = finPos, finFun = finFun, waitForTokens = waitForTokens })
    startLuaCoroutine(Global, 'restWaitCoroutine')
end

-- This completes when a ship is resting at a table level
-- Does token movement and ship locking after
-- IF a final position was provided in the data table, set it at the end
-- IF a final function was provideed in the data table, execute it at the end
function restWaitCoroutine()
    if MoveModule.restWaitQueue[1] == nil then
        return 1
    end

    local waitData = MoveModule.restWaitQueue[#MoveModule.restWaitQueue]
    local actShip = waitData.ship
    local finPos = waitData.finPos
    local finFun = waitData.finFun
    local waitForTokens = waitData.waitForTokens
    table.remove(MoveModule.restWaitQueue, #MoveModule.restWaitQueue)
    -- Wait
    repeat
        coroutine.yield(0)
    until actShip.resting == true and actShip.isSmoothMoving() == false and actShip.held_by_color == nil

    if finPos ~= nil then
        actShip.setPosition(finPos.pos)
        actShip.setRotation(finPos.rot)
    end

    local newTokenTable = {}
    for k, tokenSetInfo in pairs(MoveModule.tokenWaitQueue) do
        -- Move and pop waiting tokens
        if tokenSetInfo.ship == actShip then
            for k2, tokenData in pairs(tokenSetInfo.tokens) do
                local offset = Vect.RotateDeg(tokenData.relPos, actShip.getRotation()[2])
                local dest = Vect.Sum(offset, actShip.getPosition())
                dest[2] = dest[2] + 0.5
                dest = TokenModule.VisiblePosition(tokenData.ref, tokenSetInfo.ship, dest)
                tokenData.ref.setPositionSmooth(dest, false, true)
                local tRot = tokenData.ref.getRotation()
                tokenData.ref.setRotationSmooth({ tRot[1], actShip.getRotation()[2] + tokenData.relRot, tRot[3] })
                tokenData.ref.highlightOn({ 0, 1, 0 }, 2)
            end
        else
            -- Index back tokens that are not waiting for this ship
            table.insert(newTokenTable, tokenSetInfo)
        end
    end

    if waitForTokens == true then
        repeat
            coroutine.yield(0)
        until TokenModule.DoesShipHasAnySmoothMovingTokens(actShip) == false
    end

    MoveModule.tokenWaitQueue = newTokenTable
    actShip.lock()
    actShip.highlightOn({ 0, 1, 0 }, 0.1)
    XW_cmd.SetReady(actShip)
    if finFun ~= nil then
        finFun(actShip)
    end
    return 1
end

-- Perform move designated by move_code on a ship and announce the result
-- How move is preformed generally relies on MoveData.DecodeInfo for its code
-- Includes token handling so nothing obscurs the final position
-- Starts the wait coroutine that handles stuff done when ship settles down
-- Takes two optional parameters, the function to call at the end of the move,
-- and whether we have to wait for the tokens to come to a rest before calling
-- it.
MoveModule.PerformMove = function(move_code, ship, ignoreCollisions, finishFunction, waitForTokens)
    ship.lock()
    local originalPos = ship.getPosition()
    local origionalRot = ship.getRotation()
    local info = MoveData.DecodeInfo(move_code, ship)
    local finData = MoveModule.GetFinalPosData(move_code, ship, ignoreCollisions)
    local annInfo = {
        type = finData.finType,
        note = info.note,
        code = info.code,
        friendlyCollission = finData
            .friendlyCollission
    }
    if finData.finType == 'overlap' then
        annInfo.note = info.collNote
    elseif finData.finType == 'move' then
        if finData.collObj ~= nil then
            annInfo.note = info.collNote
            annInfo.collidedShip = finData.collObj
        end
    elseif finData.finType == 'stationary' then
        -- And here as well
    end

    if finData.finType ~= 'overlap' then
        MoveModule.MoveShip(ship, finData, move_code, finishFunction, waitForTokens)
        if finData.collObj ~= nil then
            MoveModule.SpawnOverlapReminder(ship)
        end
    end
    AnnModule.Announce(annInfo, 'all', ship)

    local templateData = {
        origin = originalPos,
        orientation = origionalRot,
        dir = info.dir,
        speed = info.speed,
        type = info.type,
        shipSize = info.size,
        extra = info.extra
    }

    MoveModule.CheckMineAndObstacleCollisions(ship, finData.finPos, true, templateData)
    if ((finData.collObj == nil) and ship.getTable('Data').movethrough) then
        MoveModule.CheckMovethroughShips(ship, true, templateData)
    end
    return (finData.finType ~= 'overlap')
end

-- Spawn a 'BUMPED' informational button on the base that removes itself on click or next move
MoveModule.SpawnOverlapReminder = function(ship)
    Ship_RemoveOverlapReminder(ship)
    remindButton = { click_function = 'Ship_RemoveOverlapReminder', label = 'BUMPED', rotation = { 0, 0, 0 }, width = 1000, height = 350, font_size = 250 }

    local size = ship.getTable("Data").Size or 'small'
    if size == 'large' then
        remindButton.position = { 0, 0.2, 2 }
    elseif size == 'medium' then
        remindButton.position = { 0, 0.2, 1.4 }
    else
        remindButton.position = { 0, 0.3, 0.8 }
    end
    ship.createButton(remindButton)
end

-- Remove the 'BUMPED' dummy button from a ship
MoveModule.RemoveOverlapReminder = function(ship)
    local buttons = ship.getButtons()
    if buttons ~= nil then
        for k, but in pairs(buttons) do
            if but.label == 'BUMPED' then
                ship.removeButton(but.index)
            end
        end
    end
end

-- Check if a ship in some situation is overlapping any obstacles
-- Highlight overlapped obstacles red
-- If 'vocal' set to true, add a notification
-- Return table of overlapped obstacles
MoveModule.CheckObstacleCollisions = function(ship, targetPosRot, vocal, templateData)
    local collList = MoveModule.FullCastCheck(ship, targetPosRot, MoveModule.SelectObstacles)
    if templateData ~= nil then
        MoveModule.TemplateCastCheck(ship, collList, templateData, MoveModule.SelectObstacles)
    end
    if collList[1] ~= nil then
        local obsList = '('
        for k, obs in pairs(collList) do
            obs.highlightOn({ 1, 0, 0 }, 3)
            obsList = obsList .. obs.getName() .. ', '
        end
        obsList = obsList:sub(1, -3) .. ')'
        if vocal then
            AnnModule.Announce(
                { type = 'warn', note = ship.getName() .. ' appears to have overlapped an obstacle ' .. obsList }, 'all')
        end
    end
    return collList
end



-- Check if a ship in some situation is overlapping any mine tokens
-- Highlight overlapped tokens red
-- If 'vocal' set to true, add a notification
-- Return table of overlapped tokens
--TODO maybe check mine colision after bomb drop?
MoveModule.CheckMineCollisions = function(ship, targetPosRot, vocal, templateData)
    local collList = MoveModule.FullCastCheck(ship, targetPosRot, MoveModule.SelectMineTokens)
    if templateData ~= nil then
        MoveModule.TemplateCastCheck(ship, collList, templateData, MoveModule.SelectMineTokens)
    end
    if collList[1] ~= nil then
        local mineList = '('
        for k, mine in pairs(collList) do
            mine.highlightOn({ 1, 0, 0 }, 3)
            mineList = mineList .. mine.getName() .. ', '
        end
        mineList = mineList:sub(1, -3) .. ')'
        if vocal then
            AnnModule.Announce(
                { type = 'warn', note = ship.getName() .. ' appears to have overlapped a mine token ' .. mineList },
                'all')
        end
    end
    return collList
end

MoveModule.CheckMineAndObstacleCollisions = function(ship, targetPosRot, vocal, templateData, ignoredTemplateObstacles)
    local collList = MoveModule.FullCastCheck(ship, targetPosRot, MoveModule.SelectMinesAndObstacleTokens)
    if templateData ~= nil then
        MoveModule.TemplateCastCheck(ship, collList, templateData, function(obj)
            if ignoredTemplateObstacles ~= nil then
                for _, ignoredTemplate in pairs(ignoredTemplateObstacles) do
                    if obj == ignoredTemplate then
                        return false
                    end
                end
            end
            return MoveModule.SelectMinesAndObstacleTokens(obj)
        end)
    end
    if vocal then
        if collList[1] ~= nil then
            local hitList = '('
            for k, hitObj in pairs(collList) do
                hitObj.highlightOn({ 1, 0, 0 }, 3)
                hitList = hitList .. hitObj.getName() .. ', '
            end
            hitList = hitList:sub(1, -3) .. ')'
            AnnModule.Announce(
                {
                    type = 'warn',
                    note = ship.getName() ..
                        ' appears to have overlapped a mine or obstacle token ' .. hitList
                },
                'all')
        end
    end
    return collList
end

MoveModule.CheckMovethroughShips = function(ship, vocal, templateData)
    collList = {}
    if templateData ~= nil then
        MoveModule.TemplateCastCheck(ship, collList, templateData, MoveModule.SelectShips)
    end
    if vocal then
        for i, coll in pairs(collList) do
            AnnModule.Announce({
                type = 'warn',
                note = ship.getName() ..
                    ' appears to have moved through ' .. coll.getName()
            }, 'all')
            coll.highlightOn({ 0.2, 0.2, 1 }, 3)
        end
    end
    return collList
end

-- Remove the 'BUMPED' button from a ship (click function)
function Ship_RemoveOverlapReminder(ship)
    MoveModule.RemoveOverlapReminder(ship)
end

-- Check which ship has it's base closest to position (large ships have large bases!), that's the owner
--   also check how far it is to the owner-changing position (margin of safety)
-- Kinda tested: margin > 20mm = visually safe
-- Arg can be a token ref or a position
-- Returns {dist=distanceFromOwner, owner=ownerRef, margin=marginForNextCloseShip}
MoveModule.GetTokenOwner = function(tokenPos)
    local out = { owner = nil, dist = 0, margin = -1 }
    local nearShips = ObjType.GetNearOfType(tokenPos, Dim.Convert_mm_igu(120), 'ship')
    if nearShips[1] == nil then
        return out
    end
    local baseDist = {}
    -- Take the base size into account for distances
    for k, ship in pairs(nearShips) do
        local realDist = Vect.Distance(tokenPos, ship.getPosition())
        local size = ship.getTable("Data").Size or 'small'
        if size == 'large' then
            realDist = realDist - Dim.Convert_mm_igu(10)
        elseif size == 'medium' then
            realDist = realDist - Dim.Convert_mm_igu(5)
        elseif size == 'huge' then
            realDist = realDist - Dim.Convert_mm_igu(15) -- Todo, check if this arbetary number works
        end
        table.insert(baseDist, { ship = ship, dist = realDist })
    end
    local nearest = baseDist[1]
    for k, data in pairs(baseDist) do
        if data.dist < nearest.dist then
            nearest = data
        end
    end
    local nextNearest = { dist = 999 }
    for k, data in pairs(baseDist) do
        if data.ship ~= nearest.ship and (data.dist < nextNearest.dist) then
            nextNearest = data
        end
    end
    return { owner = nearest.ship, dist = nearest.dist, margin = (nextNearest.dist - nearest.dist) / 2 }
end

-- END MAIN MOVEMENT MODULE
--------

--------
-- TOKEN MODULE
-- Moves tokens, clears positions from tokens, checks its owners, deducts a visible position after a ship move

-- Table with refs for different token and template sources
TokenModule = {
    tokenSize = 1,
    tokenSources = {},
    tokenAssignments = {},
    scaleModifiers = { [1] = 1.0, [2] = 1.5, [3] = 2.0 },
}

-- Update token and template sources on each load
TokenModule.onLoad = function(save_data)
    if save_data then
        TokenModule.tokenSize = save_data.tokenSize
    end

    for k, obj in pairs(getAllObjects()) do
        if obj.tag == 'Infinite' then
            if obj.getName() == 'Focus' then
                TokenModule.tokenSources.Focus = { src = obj, hlColor = { 0, 0.5, 0 } }
            elseif obj.getName() == 'Calculate' then
                TokenModule.tokenSources.Calculate = { src = obj, hlColor = { 0, 1, 0 } }
            elseif obj.getName() == 'Evade' then
                TokenModule.tokenSources.Evade = { src = obj, hlColor = { 0, 1, 0 } }
            elseif obj.getName() == 'Stress' then
                TokenModule.tokenSources.Stress = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Strain' then
                TokenModule.tokenSources.Strain = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Deplete' then
                TokenModule.tokenSources.Deplete = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Ion' then
                TokenModule.tokenSources.Ion = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Jam' then
                TokenModule.tokenSources.Jam = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Tractor' then
                TokenModule.tokenSources.Tractor = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Disarm' then
                TokenModule.tokenSources.Disarm = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Reinforce' then
                TokenModule.tokenSources.Reinforce = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Cloak' then
                TokenModule.tokenSources.Cloak = { src = obj, hlColor = { 0.8, 0, 0 } }
            elseif obj.getName() == 'Target Locks' then
                TokenModule.tokenSources['Target Lock'] = { src = obj, hlColor = { 0, 0, 1 } }
            elseif obj.getName():find('Templates') ~= nil then
                if obj.getName():find('Straight') ~= nil then
                    TokenModule.tokenSources['s' .. obj.getName():sub(1, 1)] = obj
                elseif obj.getName():find('Turn') ~= nil then
                    TokenModule.tokenSources['t' .. obj.getName():sub(1, 1)] = obj
                elseif obj.getName():find('Bank') ~= nil then
                    TokenModule.tokenSources['b' .. obj.getName():sub(1, 1)] = obj
                end
            end
        end
    end
end

TokenModule.onSave = function()
    local saveData = {}
    saveData.tokenSize = TokenModule.tokenSize
    -- return JSON.encode(saveData)
    return saveData
end

SaveManager.Register('TokenModule', TokenModule.onSave, TokenModule.onLoad)

TokenModule.onObjectDestroyed = function(destroyed_object)
    if TokenModule.tokenAssignments[destroyed_object.getGUID()] ~= nil then
        TokenModule.tokenAssignments[destroyed_object.getGUID()].call("RemoveToken", { token = destroyed_object })
        TokenModule.tokenAssignments[destroyed_object.getGUID()] = nil
    end
end

TokenModule.onObjectDropped = function(player_color, object)
    if not isAssignable(object) then
        return
    end

    if object.getVar('__XW_TokenType') == 'targetLock' then
        return
    end

    local nearest = FindNearestShip(object, 100)
    TokenModule.AssignToken(object, nearest)
end

function isAssignable(object)
    -- Target lock has special onDrop handling on its own
    return object.getVar('__XW_TokenType') ~= 'targetLock'
        and ObjType.IsOfType(object, 'token')
        or object.hasTag('Assignable')
end

EventSub.Register('onObjectDropped', TokenModule.onObjectDropped)

TokenModule.removeOnFlip = function(object, player)
    local ship = Global.call("getShipTokenIsAssignedTo", { token = object })
    local color = Color.fromString(player.color):toHex()
    local player = player.steam_name
    local token = object.getName()

    if ship then
        printToAll(string.format("[%s]%s spent %s's %s token[-]", color, player, ship.getName(), token))
    else
        printToAll(string.format("[%s]%s spent a %s token[-]", color, player, token))
    end

    object.destruct()
end

-- How far can tokens be to be considered owned bya  ship
TokenModule.tokenReachDistance = Dim.Convert_mm_igu(100)
-- By how much this token has to be distant from other ship "interception zone" to be visible
-- (how far from an owner-switching-border it has to be so you can see whose it is)
TokenModule.visibleMargin = Dim.Convert_mm_igu(20)

-- Preset positions for tokens on and near the base
-- Generally used only when their current position switches its owner after a move
-- Positions on the base

TokenModule.basePos = {}

-- On base - small ships
TokenModule.basePos.small = {}
TokenModule.basePos.small.Focus = { 12, 12 }
TokenModule.basePos.small.Calculate = { 12, 24 }
TokenModule.basePos.small.Evade = { 12, -12 }
TokenModule.basePos.small.Stress = { -12, 12 }
TokenModule.basePos.small.Ion = { -12, -24 }
TokenModule.basePos.small.Strain = { -12, 24 }
TokenModule.basePos.small.Deplete = { -12, 36 }

TokenModule.basePos.small.Reinforce = { -24, 24 }
TokenModule.basePos.small.Cloak = { -24, -24 }
TokenModule.basePos.small.Jam = { 24, -12 }
TokenModule.basePos.small.Disarm = { 24, 12 }
TokenModule.basePos.small.Tractor = { 24, 24 }

TokenModule.basePos.small.rest = { -12, -12 }

--On base - medium ships
TokenModule.basePos.medium = {}
TokenModule.basePos.medium.Focus = { 25, 25 }
TokenModule.basePos.medium.Calculate = { 25, 35 }
TokenModule.basePos.medium.Evade = { 25, -25 }
TokenModule.basePos.medium.Stress = { -25, 25 }
TokenModule.basePos.medium.Ion = { -25, -35 }
TokenModule.basePos.medium.Strain = { -25, 35 }
TokenModule.basePos.medium.Deplete = { -25, -45 }

TokenModule.basePos.medium.Reinfoce = { -35, 35 }
TokenModule.basePos.medium.Cloak = { -35, -35 }
TokenModule.basePos.medium.Jam = { 35, -25 }
TokenModule.basePos.medium.Disarm = { 35, 25 }
TokenModule.basePos.medium.Tractor = { 35, 35 }

TokenModule.basePos.medium.rest = { -25, -25 }

-- On base - large ships
TokenModule.basePos.large = {}
TokenModule.basePos.large.Focus = { 30, 30 }
TokenModule.basePos.large.Calculate = { 30, 40 }
TokenModule.basePos.large.Evade = { 30, 0 }
TokenModule.basePos.large.Stress = { 30, -30 }
TokenModule.basePos.large.Strain = { 30, -40 }
TokenModule.basePos.large.Deplete = { -30, -40 }
TokenModule.basePos.large.Tractor = { -30, 30 }
TokenModule.basePos.large.Ion = { -30, 0 }
TokenModule.basePos.large.Lock = { 0, 30 }

TokenModule.basePos.large.Cloak = { 30, 30 }
TokenModule.basePos.large.Reinforce = { -30, 30 }
TokenModule.basePos.large.Jam = { -30, -30 }
TokenModule.basePos.large.Disarm = { 40, 30 }

TokenModule.basePos.large.rest = { -30, -30 }

-- On base - huge ships
TokenModule.basePos.huge = {}
TokenModule.basePos.huge.Focus = { 30, 30 }
TokenModule.basePos.huge.Calculate = { 30, 40 }
TokenModule.basePos.huge.Evade = { 30, 0 }
TokenModule.basePos.huge.Stress = { 30, -30 }
TokenModule.basePos.huge.Strain = { 30, -40 }
TokenModule.basePos.huge.Deplete = { -30, -40 }
TokenModule.basePos.huge.Tractor = { -30, 30 }
TokenModule.basePos.huge.Ion = { -30, 0 }
TokenModule.basePos.huge.Lock = { 0, 30 }

TokenModule.basePos.huge.Cloak = { 30, 30 }
TokenModule.basePos.huge.Reinforce = { -30, 30 }
TokenModule.basePos.huge.Jam = { -30, -30 }
TokenModule.basePos.huge.Disarm = { 40, 30 }

TokenModule.basePos.huge.rest = { -30, -30 }

-- Positions near the base
-- Near base - small ships
TokenModule.nearPos = {}

TokenModule.nearPos.small = {}
TokenModule.nearPos.small.Focus = { 35, 25 }
TokenModule.nearPos.small.Calculate = { 15, 35 }
TokenModule.nearPos.small.Evade = { 35, 0 }
TokenModule.nearPos.small.Stress = { 35, -25 }
TokenModule.nearPos.small.Strain = { 35, -35 }
TokenModule.nearPos.small.Deplete = { -35, -35 }
TokenModule.nearPos.small.Ion = { -35, 25 }
TokenModule.nearPos.small.Tractor = { -35, 0 }
TokenModule.nearPos.small.Lock = { 0, 40 }

TokenModule.nearPos.small.Reinfoce = { -35, 35 }
TokenModule.nearPos.small.Cloak = { -35, -35 }
TokenModule.nearPos.small.Jam = { 35, -25 }
TokenModule.nearPos.small.Disarm = { 35, 25 }

TokenModule.nearPos.small.rest = { -35, -25 }

-- Near base - medium ships
TokenModule.nearPos.medium = {}
TokenModule.nearPos.medium.Focus = { 45, 28 }
TokenModule.nearPos.medium.Calculate = { 45, 56 }
TokenModule.nearPos.medium.Evade = { 45, 0 }
TokenModule.nearPos.medium.Stress = { 45, -28 }
TokenModule.nearPos.medium.Strain = { 45, -45 }
TokenModule.nearPos.medium.Deplete = { -45, -45 }
TokenModule.nearPos.medium.Ion = { -45, 28 }
TokenModule.nearPos.medium.Tractor = { -45, 0 }
TokenModule.nearPos.medium.Lock = { 0, 45 }

TokenModule.nearPos.medium.Reinfoce = { -35, 35 }
TokenModule.nearPos.medium.Cloak = { -35, -35 }
TokenModule.nearPos.medium.Jam = { 35, -25 }
TokenModule.nearPos.medium.Disarm = { 35, 25 }

TokenModule.nearPos.medium.rest = { -45, -35 }

-- Near base - large ships
TokenModule.nearPos.large = {}
TokenModule.nearPos.large.Focus = { 55, 30 }
TokenModule.nearPos.large.Calculate = { 55, 30 }
TokenModule.nearPos.large.Evade = { 55, 0 }
TokenModule.nearPos.large.Stress = { 55, -30 }
TokenModule.nearPos.large.Strain = { 55, -55 }
TokenModule.nearPos.large.Deplete = { -55, -55 }
TokenModule.nearPos.large.Tractor = { -55, 45 }
TokenModule.nearPos.large.Ion = { -55, 15 }
TokenModule.nearPos.large.Weapons = { -55, -15 }
TokenModule.nearPos.large.Lock = { 0, 50 }

TokenModule.nearPos.large.Reinfoce = { -45, 45 }
TokenModule.nearPos.large.Cloak = { -45, -45 }
TokenModule.nearPos.large.Jam = { 45, -45 }
TokenModule.nearPos.large.Disarm = { 45, 45 }

TokenModule.nearPos.large.rest = { -55, -45 }

-- Near base - large ships
TokenModule.nearPos.huge = {}
TokenModule.nearPos.huge.Focus = { 55, 30 }
TokenModule.nearPos.huge.Calculate = { 55, 30 }
TokenModule.nearPos.huge.Evade = { 55, 0 }
TokenModule.nearPos.huge.Stress = { 55, -30 }
TokenModule.nearPos.huge.Strain = { 55, -55 }
TokenModule.nearPos.huge.Deplete = { -55, -55 }
TokenModule.nearPos.huge.Tractor = { -55, 45 }
TokenModule.nearPos.huge.Ion = { -55, 15 }
TokenModule.nearPos.huge.Weapons = { -55, -15 }
TokenModule.nearPos.huge.Lock = { 0, 50 }

TokenModule.nearPos.huge.Reinfoce = { -45, 45 }
TokenModule.nearPos.huge.Cloak = { -45, -45 }
TokenModule.nearPos.huge.Jam = { 45, -45 }
TokenModule.nearPos.huge.Disarm = { 45, 45 }

TokenModule.nearPos.huge.rest = { -55, -45 }

-- Deduct target token position in the world for a ship, token and some entry from TokenModule.basePos or .nearPos
TokenModule.TokenPos = function(tokenName, ship, posTable)
    local baseSize = ship.getTable("Data").Size or 'small'
    local entry = posTable[baseSize].rest
    for tokenEntryName, tEntry in pairs(posTable[baseSize]) do
        if tokenName:find(tokenEntryName) ~= nil then
            entry = tEntry
        end
    end
    local tsPos = { Dim.Convert_mm_igu(entry[1]), 0.5, Dim.Convert_mm_igu(entry[2]) }
    return Vect.Sum(ship.getPosition(), Vect.RotateDeg(tsPos, ship.getRotation()[2] + 180))
end

-- Return position for a given token that is on the base of given ship
TokenModule.BasePosition = function(tokenName, ship)
    local name = nil
    if type(tokenName) == 'string' then
        name = tokenName
    elseif type(tokenName) == 'userdata' then
        name = tokenName.getName()
    end
    return TokenModule.TokenPos(name, ship, TokenModule.basePos)
end

-- Return position for a given token that is near the base of given ship
TokenModule.NearPosition = function(tokenName, ship)
    local name = nil
    if type(tokenName) == 'string' then
        name = tokenName
    elseif type(tokenName) == 'userdata' then
        name = tokenName.getName()
    end
    return TokenModule.TokenPos(name, ship, TokenModule.nearPos)
end

-- Return a visible position for some token near some ship
-- Priorities as follows (OK if token is still visible there as in you can see who is its owner easily):
-- 1. Prefer the position given as 3rd argument if passed
-- 2. Prefer position on a stack if a stack of tokens already belongs to a ship
-- 3. Prefer position NEAR ship base as position table dictates
-- 4. Prefer position ON ship base as position table dictates (if all else fails, this will be returned)
TokenModule.VisiblePosition = function(tokenName, ship, preferredPos)
    -- Check preferred position margin
    if preferredPos ~= nil then
        local prefInfo = TokenModule.TokenOwnerInfo(preferredPos)
        if prefInfo.owner == ship and prefInfo.margin > TokenModule.visibleMargin then
            return preferredPos
        end
    end
    -- Check for present stacks
    local currTokensInfo = TokenModule.GetShipTokensInfo(ship)
    local currStack = { qty = -2, obj = nil }
    for k, tokenInfo in pairs(currTokensInfo) do
        if tokenInfo.token.getName() == tokenName and tokenInfo.token.getQuantity() > currStack.qty and (not tokenInfo.token.IsSmoothMoving()) then
            currStack.obj = tokenInfo.token
            currStack.qty = currStack.obj.getQuantity()
        end
    end
    if currStack.obj ~= nil then
        return Vect.Sum(currStack.obj.getPosition(), { 0, 0.7, 0 })
    end
    -- Check for near near base position or return base position
    local nearPos = TokenModule.NearPosition(tokenName, ship)
    local nearData = TokenModule.TokenOwnerInfo(nearPos)
    if nearData.margin < TokenModule.visibleMargin then
        return TokenModule.BasePosition(tokenName, ship)
    else
        return nearPos
    end
end

-- Check which tokens belong to a ship and queue them to be moved with it
-- Needs the MoveModule.WaitForResting fired to actually use stuff from this queue
TokenModule.QueueShipTokensMove = function(ship)
    local selfTokens = TokenModule.GetShipTokens(ship)
    local waitTable = { tokens = {}, ship = ship }
    -- Save relative position/rotation
    for k, token in pairs(selfTokens) do
        print("QueueShipTokensMove: " .. token.getName())
        local relPos = Vect.RotateDeg(Vect.Between(ship.getPosition(), token.getPosition()), -1 * ship.getRotation()[2])
        local relRot = token.getRotation()[2] - ship.getRotation()[2]
        table.insert(waitTable.tokens, { ref = token, relPos = relPos, relRot = relRot })
    end
    table.insert(MoveModule.tokenWaitQueue, waitTable)
end

-- Table for locks to be set and callback to trigger their naming and coloring
-- Entry: {lock=targetLockRef, color=colorToTint, name=nameToSet}
TokenModule.locksToBeSet = {}

-- Callback to set ALL the locks in wueue
function TokenModule_SetLocks()
    for k, info in pairs(TokenModule.locksToBeSet) do
        print("lock: " .. tostring(info.lock))
        info.lock.call('manualSet', { color = info.color, name = info.name })
        info.lock.highlightOn({ 0, 0, 0 }, 0.01)

        if info.ship ~= nil then
            info.lock.call('setOwner', { player = info.color, ship = info.ship })
        end

        if info.target ~= nil then
            info.lock.call('assignToShip', { ship = info.target })
        end
    end
    TokenModule.locksToBeSet = {}
end

-- Table for locks to be set and callback to trigger their naming and coloring
-- Entry: {lock=targetLockRef, color=colorToTint, name=nameToSet}
TokenModule.tractorsToBeSet = {}

-- Callback to set ALL the locks in wueue
function TokenModule_SetTractors()
    for k, info in pairs(TokenModule.tractorsToBeSet) do
        info.tractor.call('manualSet', { ref = info.ref })
        info.tractor.highlightOn({ 0, 0, 0 }, 0.01)
    end
    TokenModule.tractorsToBeSet = {}
end

-- Table for tokens to be flipped and callback to trigger their flipping
-- Entry: token
TokenModule.tokensToBeFlipped = {}

function TokenModule_FlipTokens()
    for _, token in pairs(TokenModule.tokensToBeFlipped) do
        token.flip()
    end
    TokenModule.tokensToBeFlipped = {}
end

-- Table for locks to be set and callback to trigger their naming and coloring
-- Entry: {lock=targetLockRef, color=colorToTint, name=nameToSet}
TokenModule.ionsToBeSet = {}

-- Callback to set ALL the locks in wueue
function TokenModule_SetIons()
    for k, info in pairs(TokenModule.ionsToBeSet) do
        info.ion.call('manualSet', { ref = info.ref })
        info.ion.highlightOn({ 0, 0, 0 }, 0.01)
    end
    TokenModule.ionsToBeSet = {}
end

-- Take a token of some type and move to some position
-- Player color argument only matters when taking target locks
-- Returns ref to a newly taken token
-- Highlights the token with type-aware color
TokenModule.TakeToken = function(type, playerColor, dest, flip)
    local takeTable = {}
    if dest ~= nil then
        takeTable.position = dest
    end
    local highlightColor = TokenModule.tokenSources[type].hlColor
    if type == 'Target Lock' then
        takeTable.callback = 'TokenModule_SetLocks'
        takeTable.callback_owner = Global
    elseif type == 'Ion' then
        takeTable.callback = 'TokenModule_SetIons'
        takeTable.callback_owner = Global
    elseif type == 'Tractor' then
        takeTable.callback = 'TokenModule_SetTractors'
        takeTable.callback_owner = Global
    elseif flip == true then
        takeTable.callback = 'TokenModule_FlipTokens'
        takeTable.callback_owner = Global
    end
    local newToken = TokenModule.tokenSources[type].src.takeObject(takeTable)
    newToken.highlightOn(highlightColor, 3)

    local scale = TokenModule.scaleModifiers[TokenModule.tokenSize]
    newToken.setScale(newToken.getScale() * scale)
    return newToken
end

-- Get owner info from a token or positions
-- Return: {
--      token   <- passed token ref if arg was a token ref
--      owner   <- ship ref to owner, nil if none
--      dist    <- distance to owner (igu)
--      margin  <- how far from owner token would have to be moved to change owner
-- }
TokenModule.TokenOwnerInfo = function(tokenPos)
    local pos = nil
    local out = { token = nil, owner = nil, dist = 0, margin = -1 }
    if type(tokenPos) == 'table' then
        pos = tokenPos
    elseif type(tokenPos) == 'userdata' then
        out.token = tokenPos
        pos = tokenPos.getPosition()
    end
    local nearShips = ObjType.GetNearOfType(pos, TokenModule.tokenReachDistance, 'ship')
    if nearShips[1] == nil then
        return out
    end
    local baseDist = {}
    -- Take the base size into account for distances
    for k, ship in pairs(nearShips) do
        local realDist = Vect.Distance(pos, ship.getPosition())
        local size = ship.getTable("Data").Size or 'small'
        if size == 'large' then
            realDist = realDist - Dim.Convert_mm_igu(10)
        elseif size == 'medium' then
            realDist = realDist - Dim.Convert_mm_igu(5)
        end
        table.insert(baseDist, { ship = ship, dist = realDist })
    end
    local nearest = { ship = nil, dist = 999 }
    local nextNearest = { ship = nil, dist = 999 }
    for k, data in pairs(baseDist) do
        if data.dist < nearest.dist then
            nextNearest = nearest
            nearest = data
        elseif data.dist < nextNearest.dist then
            nextNearest = data
        end
    end
    out.owner = nearest.ship
    out.dist = nearest.dist
    if nextNearest.ship == nil then
        out.margin = 999
    else
        out.margin = (nextNearest.dist - nearest.dist) / 2
    end
    return out
end

-- Return table of MoveModule.GetTokenInfo entries for all tokens withis some distance of given position
TokenModule.GetNearTokensInfo = function(pos, dist)
    local reachDist = TokenModule.tokenReachDistance
    if dist ~= nil then
        reachDist = dist
    end
    local nearTokens = ObjType.GetNearOfType(pos, reachDist, 'token')
    local shipTokensInfo = {}
    for k, token in pairs(nearTokens) do
        local tokenInfo = TokenModule.TokenOwnerInfo(token)
        table.insert(shipTokensInfo, tokenInfo)
    end
    return shipTokensInfo
end

TokenModule.GetShipTokenCount = function(ship, token_name)
    local count = 0;

    for _, token in pairs(TokenModule.GetShipTokens(ship)) do
        if token.getName() == token_name and token.getVar('deleted') == nil then
            local quantity = token.getQuantity()
            if quantity < 0 then
                quantity = 1
            end
            count = count + quantity
        end
    end

    return count
end

-- Return table of MoveModule.GetTokenInfo enties for all tokens that are owned by given ship
TokenModule.GetShipTokensInfo = function(ship)
    local shipTokens = TokenModule.GetShipTokens(ship)
    local shipTokensInfo = {}
    for k, token in pairs(shipTokens) do
        table.insert(shipTokensInfo, TokenModule.TokenOwnerInfo(token))
    end

    return shipTokensInfo
end

-- Return table of object references for all tokens that are owned by given ship
TokenModule.GetShipTokens = function(ship)
    return ship.call("GetTokens")
end

-- Returns whether any of this ships tokens are currently smooth moving.
TokenModule.DoesShipHasAnySmoothMovingTokens = function(ship)
    local ship_tokens = TokenModule.GetShipTokens(ship)
    for _, token in pairs(ship_tokens) do
        if token.isSmoothMoving() then
            return true
        end
    end

    return false
end

-- Clear given distance within position from tokens
-- If given third argument, this hip tokens will be ignored
-- Tokens that have an owner will be moved near(er)/on it
-- Stray tokens will be yanked away
TokenModule.ClearPosition = function(pos, dist, ignoreShip)
    local clearDist = dist + Dim.Convert_mm_igu(20)
    local posTokenInfo = TokenModule.GetNearTokensInfo(pos, clearDist)
    for k, tokenInfo in pairs(posTokenInfo) do
        if tokenInfo.token.getButtons() == nil then
            if tokenInfo.owner ~= nil and tokenInfo.owner ~= ignoreShip then
                local visPos = TokenModule.VisiblePosition(tokenInfo.token.getName(), tokenInfo.owner)
                if Vect.Distance(visPos, pos) <= clearDist then
                    local basePos = TokenModule.BasePosition(tokenInfo.token.getName(), tokenInfo.owner)
                    tokenInfo.token.setPositionSmooth(basePos)
                else
                    tokenInfo.token.setPositionSmooth(visPos)
                end
            else
                local ptVect = Vect.Between(pos, tokenInfo.token.getPosition())
                ptVect[2] = 0
                local actDist = Vect.Distance(tokenInfo.token.getPosition(), pos)
                local distToMove = 2 * clearDist - actDist
                local targetPos = Vect.Sum(tokenInfo.token.getPosition(), Vect.SetLength(ptVect, distToMove))
                targetPos[2] = targetPos[2] + 0.5
                tokenInfo.token.setPositionSmooth(targetPos)
            end
        end
    end
end

TokenModule.AssignToken = function(token, ship)
    if token then
        Wait.condition(function()
                local guid = token.getGUID()
                if (TokenModule.tokenAssignments[guid] ~= nil) and (TokenModule.tokenAssignments[guid].tag == 'Figurine') then
                    if TokenModule.tokenAssignments[guid].getVar("RemoveToken") ~= nil then
                        TokenModule.tokenAssignments[guid].call("RemoveToken", { token = token })
                    end
                end
                TokenModule.tokenAssignments[guid] = ship
                if ship ~= nil then
                    token.setDescription("Assigned to " .. ship.getName())
                    if ship.tag == 'Figurine' then
                        if ship.getVar("AddToken") ~= nil then
                            ship.call("AddToken", { token = token })
                        end
                    end
                else
                    token.setDescription("Unassigned")
                end
            end
            ,
            function()
                return (not token.spawning)
            end)
    end
end

TokenModule.UnAssignToken = function(token)
    local guid = token.getGUID()
    if (TokenModule.tokenAssignments[guid] ~= nil) and (TokenModule.tokenAssignments[guid].tag == 'Figurine') then
        if TokenModule.tokenAssignments[guid].getVar("RemoveToken") ~= nil then
            TokenModule.tokenAssignments[guid].call("RemoveToken", { token = token })
        end
    end
    TokenModule.tokenAssignments[guid] = nil
    token.setDescription("Unassigned")
end

function getShipTokenIsAssignedTo(args)
    if args.token then
        local guid = args.token.getGUID()
        return TokenModule.tokenAssignments[guid]
    end
    return nil
end

-- END TOKEN MODULE
--------


function proxyPerformAction(table)
    ship = table[1]
    actionType = table[2]
    playerColor = table[3]
    args = table[4] or {}
    DialModule.PerformAction(ship, actionType, playerColor, args)
end

DialModule = {}
-- Perform an automated action
-- Can be called externally for stuff like range ruler spawning
DialModule.PerformAction = function(ship, type, playerColor, args)
    local tokenActions =
    ' Focus Calculate Evade Stress Strain Deplete Target Lock Ion Cloak Jam Reinforce Disarm Tractor Dummy '
    announceInfo = { type = 'action' }
    -- Ruler spawning
    if type:find('ruler') ~= nil then
        local scPos = type:find(':')
        local rulerCode = type:sub(scPos + 1, -1)
        RulerModule.ToggleRuler(ship, rulerCode)
        return
    elseif type:find('spawnMoveTemplate') ~= nil then
        local size = ship.getTable('Data').Size
        if size ~= 'huge' then
            if DialModule.DeleteTemplate(ship) == false then
                local scPos = type:find(':')
                local dialCode = type:sub(scPos + 1, -1)
                if DialModule.SpawnTemplate(ship, dialCode) ~= nil then
                    announceInfo.note = 'spawned a move template'
                else
                    announceInfo.note = 'looks at you weird'
                end
            else
                return
            end
        else
            return
        end
    elseif type:find('deleteMoveTemplate') ~= nil then
        local size = ship.getTable('Data').Size
        if size ~= 'huge' then
            DialModule.DeleteTemplate(ship)
        end
        return
    elseif tokenActions:find(' ' .. type .. ' ') ~= nil then
        if args ~= nil and args.remove == true then
            local tokens = ship.call("GetTokens", { type = string.lower(type) })
            local delToken = nil
            for k, token in pairs(tokens) do
                if token.getVar('deleted') == nil then
                    delToken = token
                end
            end
            if delToken == nil then
                announceInfo.note = 'tried to shed a ' .. type .. ' but doesn\'t have any'
            else
                announceInfo.note = 'sheds a ' .. type .. ' token'
                TokenModule.UnAssignToken(delToken)
                delToken.destruct()
            end
        else
            local destinationShip = ship
            if args ~= nil and args.target ~= nil then
                destinationShip = args.target
            end
            local dest = TokenModule.VisiblePosition(type, destinationShip)
            local flipToken = args ~= nil and args.flip == true
            local newToken = TokenModule.TakeToken(type, playerColor, dest, flipToken)

            if type == 'Target Lock' then
                local lockArguments = { ship = ship, lock = newToken, name = ship.getName(), color = playerColor }
                if args ~= nil and args.ship ~= nil and args.target ~= nil then
                    -- The AI system passes in arguments to automatically assign the
                    -- lock. Process these if they've been passed in.
                    lockArguments.ship = args.ship
                    lockArguments.target = args.target
                end
                table.insert(TokenModule.locksToBeSet, lockArguments)
                announceInfo.note = 'acquired a target lock'
                TokenModule.UnAssignToken(newToken) -- Target locks are not assigned to the spawning ship
            elseif type == 'Ion' then
                table.insert(TokenModule.ionsToBeSet, { ion = newToken, ref = ship })
                announceInfo.note = 'takes an ion token'
                TokenModule.AssignToken(newToken, ship)
            elseif type == 'Tractor' then
                table.insert(TokenModule.tractorsToBeSet, { tractor = newToken, ref = ship })
                announceInfo.note = 'takes a tractor token'
                TokenModule.AssignToken(newToken, ship)
            else
                if flipToken == true then
                    table.insert(TokenModule.tokensToBeFlipped, newToken)
                end
                if type == 'Evade' then
                    announceInfo.note = 'takes an evade token'
                else
                    announceInfo.note = 'takes a ' .. string.lower(type) .. ' token'
                end
                TokenModule.AssignToken(newToken, ship)
            end
        end
    end
    AnnModule.Announce(announceInfo, 'all', ship)
end

DialModule.RotateCmd = {
    rot = { direction = 'rotateleft', mount = 'main' },
    rotl = { direction = 'rotateleft', mount = 'main' },
    rotr = { direction = 'rotateright', mount = 'main' },
    rot1 = { direction = 'rotateleft', mount = 'front' },
    rotl1 = { direction = 'rotateleft', mount = 'front' },
    rotr1 = { direction = 'rotateright', mount = 'front' },
    rot2 = { direction = 'rotateleft', mount = 'rear' },
    rotl2 = { direction = 'rotateleft', mount = 'rear' },
    rotr2 = { direction = 'rotateright', mount = 'rear' },
}

DialModule.RotateArc = function(ship, cmd)
    ship.call("RotateAttachedArcIndicator", DialModule.RotateCmd[cmd])
end

DialModule.TurretArcCmd = {
    turret = { mount = 'main' },
    turret1 = { mount = 'front' },
    turret2 = { mount = 'rear' },
}

DialModule.TurretArc = function(ship, cmd)
    local arc = ship.call("GetTurretArc", DialModule.TurretArcCmd[cmd])
    local range = ship.call("GetTurretRange", DialModule.TurretArcCmd[cmd])
    if arc then
        command = string.upper(arcToCmnd[arc])
        if range then
            command = command .. tostring(range)
        end
        RulerModule.ToggleRuler(ship, command)
    end
end

DialModule.FixedArc = function(ship, cmd)
    arc = ship.getTable('Data').arcs.fixed
    if arc then
        command = string.upper(arcToCmnd[arc.type[1]])
        if arc.range then
            command = command .. tostring(arc.range)
        end
        RulerModule.ToggleRuler(ship, command)
    end
end




-- Spawned templates are kept there
-- Entry: {ship=shipRef, template=templateObjRef}
DialModule.SpawnedTemplates = {}

-- Position data for template spawning
-- "Trim" entries are to fine-tune the position
-- (its quite rough by the numbers since their origin was not perfectly at the center)
DialModule.TemplateData = {}
DialModule.TemplateData.straight = {}
DialModule.TemplateData.straight[1] = { 0, -2.5, 20, 0 }
DialModule.TemplateData.straight[2] = { 0, -2.5, 40, 0 }
DialModule.TemplateData.straight[3] = { 0, -2.5, 60, 0 }
DialModule.TemplateData.straight[4] = { 0, -2.5, 80, 0 }
DialModule.TemplateData.straight[5] = { 0, -2.5, 100, 0 }
DialModule.TemplateData.bank = {}
DialModule.TemplateData.bank.leftRot = 45
DialModule.TemplateData.bank.trim = { left = { { -2, 0, -4, 0 }, { -5.5, 0, -5.2, 0 }, { -9.3, 0, -6.45, 0 } }, right = { { 4.2, 0, 1.2, 0 }, { 7.8, 0, -0.3, 0 }, { 11.5, 0, -1.4, 0 } } }
DialModule.TemplateData.bank[1] = { 80 * (1 - math.cos(math.pi / 8)), 0, 80 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.bank[2] = { 130 * (1 - math.cos(math.pi / 8)), 0, 130 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.bank[3] = { 180 * (1 - math.cos(math.pi / 8)), 0, 180 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.bankSlip = {}
DialModule.TemplateData.bankSlip.leftRot = 45
DialModule.TemplateData.bankSlip.trim = { left = { { -2, 0, -4, 0 }, { -5.5, 0, -5.2, 0 }, { -9.3, 0, -6.45, 0 } }, right = { { 4.2, 0, 1.2, 0 }, { 7.8, 0, -0.3, 0 }, { 11.5, 0, -1.4, 0 } } }
DialModule.TemplateData.bankSlip[1] = { 80 * (1 - math.cos(math.pi / 8)), 0, 80 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.bankSlip[2] = { 130 * (1 - math.cos(math.pi / 8)), 0, 130 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.bankSlip[3] = { 180 * (1 - math.cos(math.pi / 8)), 0, 180 * math.sin(math.pi / 8), 180 }
DialModule.TemplateData.turn = {}
DialModule.TemplateData.turn.leftRot = 90
DialModule.TemplateData.turn.trim = { left = { { 0, -2.5, 0, 0 }, { -3, -2.5, -3.66, 0 }, { -4.7, -2.5, -7.5, 0 } }, right = { { 0, -2.5, 0, 0 }, { 3, -2.5, -4.1, 0 }, { 4.5, -2.5, -7.8, 0 } } }
DialModule.TemplateData.turn[1] = { 35 * (1 - math.cos(math.pi / 4)) + 2, 0, 35 * math.sin(math.pi / 4) - 2, 180 }
DialModule.TemplateData.turn[2] = { 62.5 * (1 - math.cos(math.pi / 4)) + 5, 0, 62.5 * math.sin(math.pi / 4) - 4, 180 }
DialModule.TemplateData.turn[3] = { 90 * (1 - math.cos(math.pi / 4)) + 9, 0, 90 * math.sin(math.pi / 4) - 6, 180 }
DialModule.TemplateData.talon = {}
DialModule.TemplateData.talon.leftRot = 90
DialModule.TemplateData.talon.trim = { left = { { 0, -2.5, 0, 0 }, { -3, -2.5, -3.66, 0 }, { -4.7, -2.5, -7.5, 0 } }, right = { { 0, -2.5, 0, 0 }, { 3, -2.5, -4.1, 0 }, { 4.5, -2.5, -7.8, 0 } } }
DialModule.TemplateData.talon[1] = { 35 * (1 - math.cos(math.pi / 4)) + 2, 0, 35 * math.sin(math.pi / 4) - 2, 180 }
DialModule.TemplateData.talon[2] = { 62.5 * (1 - math.cos(math.pi / 4)) + 5, 0, 62.5 * math.sin(math.pi / 4) - 4, 180 }
DialModule.TemplateData.talon[3] = { 90 * (1 - math.cos(math.pi / 4)) + 9, 0, 90 * math.sin(math.pi / 4) - 6, 180 }

DialModule.TemplateData.baseOffset = {}
DialModule.TemplateData.baseOffset.small = { 0, 0, 20, 0 }
DialModule.TemplateData.baseOffset.medium = { 0, 0, 30, 0 }
DialModule.TemplateData.baseOffset.large = { 0, 0, 40, 0 }

-- Spawn a template on given ship
-- dialCode is move code PLUS identifier if ship already did it or not
-- be3_A means "spawn a bank left 3 template behind me" (A as in after move)
-- tr1_B means "spawn a turn right 1 template in front of me" (B as in before move)
-- Return template reference
-- TODO toggletemplate?
-- Decode the dial code into a moveData table with move details
DialModule.decodeDialCode = function(ship, dialCode)
    local moveInfo = MoveData.DecodeInfo(dialCode:sub(1, -3), ship) -- Decodes movement type, speed, etc.
    local positionKey = dialCode:sub(-1, -1)                        -- Last character defines position

    moveInfo.position = ({
        A = 'back',
        B = 'front',
        P = 'port',
        S = 'starboard'
    })[positionKey] or 'front'

    return moveInfo
end

DialModule.SpawnTemplate = function(ship, dialCode)
    local moveInfo = DialModule.decodeDialCode(ship, dialCode)

    local speed = moveInfo.speed
    local type = moveInfo.type
    local position = moveInfo.position
    local dir = moveInfo.dir
    local extra = moveInfo.extra

    return DialModule.PlaceTemplate(ship, speed, type, position, dir, extra)
end

DialModule.PlaceTemplate = function(ship, speed, type, position, dir, extra)
    if speed == 0 then
        return nil
    end
    local tempEntry = DialModule.TemplateData[type][speed]
    local baseSize = ship.getTable("Data").Size or 'small'
    tempEntry = Vect.Sum(tempEntry, DialModule.TemplateData.baseOffset[baseSize])
    local ref = ship
    if position == 'back' then
        ref = MoveModule.GetOldMove(ship, 1)
    end
    --TODO LAST MOVE LOGIC OUT!!!
    --TODO dont barf if no last move

    if dir == 'left' then
        tempEntry = MoveData.LeftVariant(tempEntry)
        tempEntry[4] = tempEntry[4] + 180 - DialModule.TemplateData[type].leftRot
    end
    if extra == 'reverse' then
        tempEntry = MoveData.ReverseVariant(tempEntry)
        if type ~= 'straight' then
            tempEntry[4] = tempEntry[4] - DialModule.TemplateData[type].leftRot
        end
    end
    if dir ~= nil then
        if extra ~= 'reverse' then
            tempEntry = Vect.Sum(tempEntry, DialModule.TemplateData[type].trim[dir][speed])
        else
            if dir == 'right' then
                dir = 'left'
            elseif dir == 'left' then
                dir = 'right'
            end
            tempEntry = Vect.Sum(tempEntry,
                Vect.ScaleEach(DialModule.TemplateData[type].trim[dir][speed], { -1, 1, -1, -1 }))
        end
    end

    local finPos = MoveModule.EntryToPos(tempEntry, ref)
    local src = TokenModule.tokenSources[type:sub(1, 1) .. speed]
    local newTemplate = src.takeObject({ position = finPos.pos, rotation = finPos.rot })
    newTemplate.lock()
    newTemplate.setPosition(finPos.pos)
    newTemplate.setRotation(finPos.rot)
    table.insert(DialModule.SpawnedTemplates, { template = newTemplate, ship = ship })
    return newTemplate
end

-- Delete template spawned for a ship, return true if deleted, false if there was none
DialModule.DeleteTemplate = function(ship)
    for k, info in pairs(DialModule.SpawnedTemplates) do
        if info.ship == ship then
            if info.template ~= nil then
                info.template.destruct()
            end
            table.remove(DialModule.SpawnedTemplates, k)
            return true
        end
    end
    return false
end


-- Char width table by Indimeco
StringLen = {}
StringLen.charWidthTable = {
    ['`'] = 2381,
    ['~'] = 2381,
    ['1'] = 1724,
    ['!'] = 1493,
    ['2'] = 2381,
    ['@'] = 4348,
    ['3'] = 2381,
    ['#'] = 3030,
    ['4'] = 2564,
    ['$'] = 2381,
    ['5'] = 2381,
    ['%'] = 3846,
    ['6'] = 2564,
    ['^'] = 2564,
    ['7'] = 2174,
    ['&'] = 2777,
    ['8'] = 2564,
    ['*'] = 2174,
    ['9'] = 2564,
    ['('] = 1724,
    ['0'] = 2564,
    [')'] = 1724,
    ['-'] = 1724,
    ['_'] = 2381,
    ['='] = 2381,
    ['+'] = 2381,
    ['q'] = 2564,
    ['Q'] = 3226,
    ['w'] = 3704,
    ['W'] = 4167,
    ['e'] = 2174,
    ['E'] = 2381,
    ['r'] = 1724,
    ['R'] = 2777,
    ['t'] = 1724,
    ['T'] = 2381,
    ['y'] = 2564,
    ['Y'] = 2564,
    ['u'] = 2564,
    ['U'] = 3030,
    ['i'] = 1282,
    ['I'] = 1282,
    ['o'] = 2381,
    ['O'] = 3226,
    ['p'] = 2564,
    ['P'] = 2564,
    ['['] = 1724,
    ['{'] = 1724,
    [']'] = 1724,
    ['}'] = 1724,
    ['|'] = 1493,
    ['\\'] = 1923,
    ['a'] = 2564,
    ['A'] = 2777,
    ['s'] = 1923,
    ['S'] = 2381,
    ['d'] = 2564,
    ['D'] = 3030,
    ['f'] = 1724,
    ['F'] = 2381,
    ['g'] = 2564,
    ['G'] = 2777,
    ['h'] = 2564,
    ['H'] = 3030,
    ['j'] = 1075,
    ['J'] = 1282,
    ['k'] = 2381,
    ['K'] = 2777,
    ['l'] = 1282,
    ['L'] = 2174,
    [';'] = 1282,
    [':'] = 1282,
    ['\''] = 855,
    ['"'] = 1724,
    ['z'] = 1923,
    ['Z'] = 2564,
    ['x'] = 2381,
    ['X'] = 2777,
    ['c'] = 1923,
    ['C'] = 2564,
    ['v'] = 2564,
    ['V'] = 2777,
    ['b'] = 2564,
    ['B'] = 2564,
    ['n'] = 2564,
    ['N'] = 3226,
    ['m'] = 3846,
    ['M'] = 3846,
    [','] = 1282,
    ['<'] = 2174,
    ['.'] = 1282,
    ['>'] = 2174,
    ['/'] = 1923,
    ['?'] = 2174,
    [' '] = 1282,
    ['avg'] = 2500
}

-- Get real string length per char table
StringLen.GetStringLength = function(str)
    local len = 0
    for i = 1, #str do
        local c = str:sub(i, i)
        if StringLen.charWidthTable[c] ~= nil then
            len = len + StringLen.charWidthTable[c]
        else
            len = len + StringLen.charWidthTable.avg
        end
    end
    return len
end

-- Get a short name for some ship
-- Avoid user-added LGS
-- Avoid name prepositions as in ambigNames
-- Avoid too short or long names
-- Add a single number/char on the end if there is one on the ship
DialModule.GetShortName = function(ship)
    local shipNameWords = {}
    local numWords = 0
    local ambigNames = 'The Captain Colonel Cartel Lieutenant Commander Old'
    local shipName = ship.getName()
    shipName = shipName:gsub('LGS', '')       -- Delete LGS
    shipName = shipName:match("^%s*(.-)%s*$") -- Trim whitespaces
    -- Fill words table
    for word in shipName:gmatch('[\'\"%-%w]+') do
        table.insert(shipNameWords, word)
    end
    -- Delete first word if ambiguous and there's more
    if ambigNames:find(shipNameWords[1]) ~= nil and #shipNameWords > 1 then
        table.remove(shipNameWords, 1)
    end
    -- Function for checking if "short name"
    local function sizeJustRight(str)
        if str == nil then
            return false
        end
        return ((str:len() < 10) --[[and (str:len() > 3)]])
    end
    -- Delete the first word if too short/long and next is better
    if (not sizeJustRight(shipNameWords[1])) and (sizeJustRight(shipNameWords[2])) then
        table.remove(shipNameWords, 1)
    end
    -- Take the resulting first "valid" word
    local shortName = shipNameWords[1]
    -- If there were apostrophes and they are asymmetrical now, trim them
    if ((string.find('\'\"', shortName:sub(1, 1)) ~= nil) or (string.find('\'\"', shortName:sub(-1, -1)) ~= nil)) and (shortName:sub(1, 1) ~= shortName:sub(-1, -1)) then
        shortName = shortName:gsub('\'', '')
        shortName = shortName:gsub('\"', '')
    end
    if shipNameWords[#shipNameWords]:len() == 1 then
        shortName = shortName .. ' ' .. shipNameWords[#shipNameWords]
    end
    return shortName
end

-- END AUTO DIALS MODULE
--------

--------
-- RULERS MODULE

-- Since there are many ruler types (models) and commands, this takes carre of all ruler-related handling
-- TO_DO: ActionModule and include it there

RulerModule = {}

-- Table of existing spawned rulers
-- Entry: {ship=shipRef, tuler=rulerRef, type=rulerTypeCode}
RulerModule.spawnedRulers = {}
-- Click function for ruler button (destroy)
function Ruler_SelfDestruct(obj)
    for k, rTable in pairs(RulerModule.spawnedRulers) do
        if rTable.ruler == obj then
            for _, arcline in pairs(rTable.arclines) do
                if arcline ~= nil then
                    arcline.destruct()
                end
            end
            table.remove(RulerModule.spawnedRulers, k)
            break
        end
    end
    obj.destruct()
end

-- Remove appropriate entry if ruler is destroyed
RulerModule.onObjectDestroyed = function(obj)
    for k, info in pairs(RulerModule.spawnedRulers) do
        if info.ship == obj or info.ruler == obj then
            if info.ship == obj then
                info.ruler.destruct()
            end
            for _, arcline in pairs(info.arclines) do
                arcline.destruct()
            end
            table.remove(RulerModule.spawnedRulers, k)
            break
        end
    end
end

-- RULER MESHES DATABASE
RulerModule.meshes = {}
RulerModule.meshes.smallBase = {}
RulerModule.meshes.smallBase.scale = { 0.629, 0.629, 0.629 }
RulerModule.meshes.smallBase.diffuse =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/arctexture.png'
RulerModule.meshes.smallBase.collider =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Small_base_Collider.obj'
RulerModule.meshes.smallBase.front =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_front.obj'
RulerModule.meshes.smallBase.fullfront =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_fullfront.obj'
RulerModule.meshes.smallBase.rear =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_back.obj'
RulerModule.meshes.smallBase.fullback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_fullback.obj'
RulerModule.meshes.smallBase.sideArc =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_side_4.obj'
RulerModule.meshes.smallBase.frontback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_frontback.obj'
RulerModule.meshes.smallBase.leftright =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_leftright.obj'
RulerModule.meshes.smallBase.bullseye =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_bullseye.obj'
RulerModule.meshes.smallBase.range = {}
RulerModule.meshes.smallBase.range[1] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_range_1.obj'
RulerModule.meshes.smallBase.range[2] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_range_2.obj'
RulerModule.meshes.smallBase.range[3] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_range_3.obj'
RulerModule.meshes.smallBase.range[4] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/small_range_4.obj'


-- Ruler meshes for medium base JC
RulerModule.meshes.mediumBase = {}
RulerModule.meshes.mediumBase.scale = { 0.629, 0.629, 0.629 }
RulerModule.meshes.mediumBase.diffuse =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/arctexture.png'
RulerModule.meshes.mediumBase.collider =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Medium_base_Collider.obj'
RulerModule.meshes.mediumBase.front =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_front.obj'
RulerModule.meshes.mediumBase.fullfront =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_fullfront.obj'
RulerModule.meshes.mediumBase.rear =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_back.obj'
RulerModule.meshes.mediumBase.fullback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_fullback.obj'
RulerModule.meshes.mediumBase.sideArc =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_side_4.obj'
RulerModule.meshes.mediumBase.frontback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_frontback.obj'
RulerModule.meshes.mediumBase.leftright =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_leftright.obj'
RulerModule.meshes.mediumBase.bullseye =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_bullseye.obj'
RulerModule.meshes.mediumBase.range = {}
RulerModule.meshes.mediumBase.range[1] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_range_1.obj'
RulerModule.meshes.mediumBase.range[2] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_range_2.obj'
RulerModule.meshes.mediumBase.range[3] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_range_3.obj'
RulerModule.meshes.mediumBase.range[4] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/medium_range_4.obj'

RulerModule.meshes.largeBase = {}
RulerModule.meshes.largeBase.scale = { 0.629, 0.629, 0.629 }
RulerModule.meshes.largeBase.diffuse =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/arctexture.png'
RulerModule.meshes.largeBase.collider =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Large_base_Collider.obj'
RulerModule.meshes.largeBase.front =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_front.obj'
RulerModule.meshes.largeBase.fullfront =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_fullfront.obj'
RulerModule.meshes.largeBase.rear =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_back.obj'
RulerModule.meshes.largeBase.fullback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_fullback.obj'
RulerModule.meshes.largeBase.sideArc =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_side_4.obj'
RulerModule.meshes.largeBase.frontback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_frontback.obj'
RulerModule.meshes.largeBase.leftright =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_leftright.obj'
RulerModule.meshes.largeBase.bullseye =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_bullseye.obj'
RulerModule.meshes.largeBase.range = {}
RulerModule.meshes.largeBase.range[1] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_range_1.obj'
RulerModule.meshes.largeBase.range[2] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_range_2.obj'
RulerModule.meshes.largeBase.range[3] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_range_3.obj'
RulerModule.meshes.largeBase.range[4] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/large_range_4.obj'

RulerModule.meshes.hugeBase = {}
RulerModule.meshes.hugeBase.scale = { 0.629, 0.629, 0.629 }
RulerModule.meshes.hugeBase.diffuse =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/arctexture.png'
RulerModule.meshes.hugeBase.collider =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Huge_base_Collider.obj'
RulerModule.meshes.hugeBase.front =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_front.obj'
RulerModule.meshes.hugeBase.fullfront =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_fullfront.obj'
RulerModule.meshes.hugeBase.rear =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_back.obj'
RulerModule.meshes.hugeBase.fullback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_fullback.obj'
RulerModule.meshes.hugeBase.sideArc =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_side_4.obj'
RulerModule.meshes.hugeBase.frontback =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_frontback.obj'
RulerModule.meshes.hugeBase.leftright =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_leftright.obj'
RulerModule.meshes.hugeBase.bullseye =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_bullseye.obj'
RulerModule.meshes.hugeBase.range = {}
RulerModule.meshes.hugeBase.range[1] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_range_1.obj'
RulerModule.meshes.hugeBase.range[2] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_range_2.obj'
RulerModule.meshes.hugeBase.range[3] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_range_3.obj'
RulerModule.meshes.hugeBase.range[4] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_range_15.obj'
RulerModule.meshes.hugeBase.range[5] =
'{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/arcranges/new/huge_range_5.obj'


-- Avaialble ruler codes:
-- R            - 1-3 range rings
-- R1/R2/R3     - 1/2/3 range rings
-- A            - contextual arc
-- AA           - full ruler
-- AP           - primary arc
-- AS           - side arc
-- AR           - rear arc
-- AT           - turret arc
-- AM           - mobile arc

XW_cmd.AddCommand('r[1-5]?a?', 'rulerHandle')            -- Range "rings"
XW_cmd.AddCommand('[fbs][lrfb]?[1-5]?a?', 'rulerHandle') -- Rulers with arc lines
XW_cmd.AddCommand('leftright[1-5]?a?', 'rulerHandle')
XW_cmd.AddCommand('frontback[1-5]?a?', 'rulerHandle')
XW_cmd.AddCommand('bull[1-5]?a?', 'rulerHandle')


-- Translate ruler code to a mesh entry
RulerModule.typeToKey = {}
RulerModule.typeToKey.F = 'front'
RulerModule.typeToKey.FF = 'fullfront'
RulerModule.typeToKey.B = 'rear'
RulerModule.typeToKey.FB = 'fullback'
RulerModule.typeToKey.R = 'range'
RulerModule.typeToKey.SL = 'sideArc'
RulerModule.typeToKey.SR = 'sideArc'
RulerModule.typeToKey.FRONTBACK = 'frontback'
RulerModule.typeToKey.LEFTRIGHT = 'leftright'
RulerModule.typeToKey.BULL = 'bullseye'

RulerModule.typeToArc = {}
RulerModule.typeToArc.F = 'front'
RulerModule.typeToArc.FF = 'fullfront'
RulerModule.typeToArc.B = 'back'
RulerModule.typeToArc.FB = 'fullback'
RulerModule.typeToArc.R1 = 'full'
RulerModule.typeToArc.R2 = 'full'
RulerModule.typeToArc.R3 = 'full'
RulerModule.typeToArc.R = 'full'
RulerModule.typeToArc.SL = 'left'
RulerModule.typeToArc.SR = 'right'
RulerModule.typeToArc.FRONTBACK = 'frontback'
RulerModule.typeToArc.LEFTRIGHT = 'leftright'
RulerModule.typeToArc.BULL = 'bullseye'

RulerModule.CachedRulers = {}


-- Get ruler spawn tables for some ship and some ruler code
-- Return table with "mesh", "collider" and "scale" keys
--  (for appropriate ruler)
RulerModule.GetRulerData = function(ship, rulerType, range)
    local baseSize = ship.getTable("Data").Size or 'small'
    local out = { mesh = nil, collider = nil, scale = nil }
    if rulerType:sub(1, 1) == 'R' then
        out.mesh = RulerModule.meshes[baseSize .. 'Base'].range[range]
    else
        local key = RulerModule.typeToKey[rulerType]
        out.mesh = RulerModule.meshes[baseSize .. 'Base'][key]
    end
    out.scale = RulerModule.meshes[baseSize .. 'Base'].scale
    out.collider = RulerModule.meshes[baseSize .. 'Base'].collider
    out.diffuse = RulerModule.meshes[baseSize .. 'Base'].diffuse
    out.material = 3
    return out
end

-- Return a descriptive arc name of command (for announcements)
RulerModule.DescriptiveName = function(ship, rulerType, range)
    if rulerType:sub(1, 1) == 'R' then
        if range == nil then
            ranges = '1-3'
        else
            ranges = tostring(range)
        end
        return 'range ' .. ranges .. ' ruler'
    else
        if rulerType == 'A' then
            rulerType = rulerType .. RulerModule.DefaultShipArc(ship)
        end
        ranges = ''
        if range then
            ranges = 'range ' .. tostring(range) .. ' '
        end
        local arcName = RulerModule.typeToKey[rulerType]
        return ranges .. arcName .. ' arc ruler'
    end
end

-- Get the default ship arc type code
-- e.g. whip with just primary arc will return code for priamry arc spawn
RulerModule.DefaultShipArc = function(ship)
    return 'A' --Todo Remove this
end

-- Create tables for spawning a ruler
-- Return: {
--      params      <- table suitable for spawnObject(params) call
--      custom      <- table suitable for obj.setCustomObject(custom) call
-- }
RulerModule.CreateCustomTables = function(ship, rulerType, range)
    if rulerType == 'A' then
        rulerType = rulerType .. RulerModule.DefaultShipArc(ship)
    end
    local rulerData = RulerModule.GetRulerData(ship, rulerType, range)
    local paramsTable = {}
    paramsTable.type = 'Custom_Model'
    paramsTable.position = ship.getPosition()
    paramsTable.rotation = { 0, ship.getRotation()[2], 0 }
    if rulerType == 'SR' then
        rot = ship.getRotation()[2]
        paramsTable.rotation = { 0, rot + 180, 0 }
    end

    paramsTable.scale = rulerData.scale

    local customTable = {}

    customTable.mesh = rulerData.mesh
    customTable.collider = rulerData.collider
    customTable.diffuse = rulerData.diffuse
    customTable.material = 3
    return { params = paramsTable, custom = customTable }
end

-- Spawn a ruler for a ship
-- Returns new ruler reference
RulerModule.SpawnRuler = function(ship, rulerType, beQuiet, include_friendly_ships, range)
    local rulerData = RulerModule.CreateCustomTables(ship, rulerType, range)
    if rulerData.custom.mesh == nil then
        return nil
    end
    local rulerId = rulerType .. ship.getTable("Data").Size .. tostring(range)
    if not RulerModule.CachedRulers[rulerId] then
        RulerModule.CachedRulers[rulerId] = spawnObject(
            {
                type = 'Custom_Model',
                position = vector(0, -2, 0),
                scale = rulerData.scale
            })
        RulerModule.CachedRulers[rulerId].setCustomObject(rulerData.custom)
        RulerModule.CachedRulers[rulerId].addTag('TempLayoutElement')
        RulerModule.CachedRulers[rulerId].interactable = false
        RulerModule.CachedRulers[rulerId].setLock(true)
        RulerModule.CachedRulers[rulerId].setColorTint(color(1.0, 0.0, 0.0, 0.5))
    end
    local newRuler = RulerModule.CachedRulers[rulerId].clone()
    newRuler.setPosition(ship.getPosition())
    newRuler.setRotation(rulerData.params.rotation)

    local arclines = {}
    if RulerModule.typeToArc[rulerType] then
        arclines = CheckArc({
            ship = ship,
            arctype = RulerModule.typeToArc[rulerType],
            range = range,
            include_friendly_ships = include_friendly_ships
        })
    end
    table.insert(RulerModule.spawnedRulers, { ship = ship, ruler = newRuler, arclines = arclines, type = rulerType })
    newRuler.lock()
    newRuler.setScale(rulerData.params.scale)
    local button = { click_function = 'Ruler_SelfDestruct', label = 'DEL', position = { 0, 0.55, 0 }, rotation = { 0, 0, 0 }, width = 1200, height = 1200, font_size = 250 }
    newRuler.createButton(button)
    return newRuler
end

-- Delete existing ruler for a ship
-- Return deleted ruler type or nil if there was none
RulerModule.DeleteRuler = function(ship)
    for k, rTable in pairs(RulerModule.spawnedRulers) do
        if rTable.ship == ship then
            for _, arcline in pairs(rTable.arclines) do
                if arcline ~= nil then
                    arcline.destruct()
                end
            end
            rTable.ruler.destruct()
            local destType = rTable.type
            table.remove(RulerModule.spawnedRulers, k)
            return destType
        end
    end
    return nil
end

-- Toggle ruler for a ship
-- If a ruler of queried type exists, just delete it and return nil
-- If any other ruler exists, delete it (and spawn queried one), return new ruler ref
RulerModule.ToggleRuler = function(ship, rulerType, beQuiet)
    local destType = RulerModule.DeleteRuler(ship)

    if destType ~= rulerType then
        includeFriendlies = (#rulerType > 1) and (rulerType:sub(#rulerType, #rulerType) == 'A')
        includeFriendlyText = ""
        spawnType = rulerType
        if includeFriendlies then
            spawnType = rulerType:sub(1, -2)
            includeFriendlyText = " including friendlies"
        end
        range = spawnType:match(".*(%d)")
        if range then
            range = tonumber(range)
            spawnType = spawnType:match("(.*)%d")
        else
            range = 3
        end

        print("ToggleRuler range: " .. tostring(range) .. " " .. spawnType)
        if beQuiet ~= true then
            local annInfo = { type = 'action' }
            annInfo.note = 'spawned a ' ..
                RulerModule.DescriptiveName(ship, spawnType, range) .. includeFriendlyText .. ' (' .. rulerType .. ')'
            AnnModule.Announce(annInfo, 'all', ship)
        end
        ship.setLock(true)
        Wait.frames(function()
            RulerModule.SpawnRuler(ship, spawnType, beQuiet, includeFriendlies, range)
        end, 1)
    end
end

-- END RULERS MODULE
--------

--------
-- BOMB MODULE

-- Allows for creating "bomb drops" that snap bomb tokens to position

BombModule = {}

-- Delete button for the spawned template
BombModule.deleteButton = { click_function = 'BombDrop_SelfDestruct', label = 'Cancel', position = { 0, 0.1, 0 }, rotation = { 0, 0, 0 }, scale = { 0.1, 0.1, 0.1 }, width = 2000, height = 900, font_size = 400 }
function BombDrop_SelfDestruct(temp)
    BombModule.DeleteDrop(temp)
end

BombModule.dropTable = {}

XW_cmd.AddCommand('b:s[1-5][r]?', 'bombDrop')
XW_cmd.AddCommand('b:b[rle][1-3][r]?', 'bombDrop')
XW_cmd.AddCommand('b:t[rle][1-3][r]?', 'bombDrop')

-- Spawn a bomb drop, delete old ones
-- If that exact one existed, just delete
BombModule.ToggleDrop = function(ship, dropCode)
    if BombModule.DeleteDrop(ship) ~= dropCode then
        BombModule.SpawnDrop(ship, dropCode)
    end
end

-- Create a bomb drop with a template
BombModule.SpawnDrop = function(ship, dropCode)
    local scPos = dropCode:find(':')
    local templateCode = dropCode:sub(scPos + 1, -1)
    DialModule.DeleteTemplate(ship)
    local dropPos = nil
    local temp = nil
    if dropCode:sub(-1, -1) == 'r' then
        -- FRONT drops
        temp = DialModule.SpawnTemplate(ship, templateCode:sub(1, -2) .. '_B')
        temp.createButton(BombModule.deleteButton)
        dropPos = MoveModule.GetFinalPosData(templateCode:sub(1, -2), ship, true)
        dropPos.finPos.rot[2] = dropPos.finPos.rot[2] - 180
    else
        -- BACK drops
        temp = DialModule.SpawnTemplate(ship, templateCode .. 'r_B')
        temp.createButton(BombModule.deleteButton)
        dropPos = MoveModule.GetFinalPosData(templateCode .. 'r', ship, true)
    end
    if dropPos == nil or temp == nil then
        return
    end
    table.insert(BombModule.dropTable, { ship = ship, temp = temp, code = dropCode, dest = dropPos.finPos })
end

-- Delete existing drop, return deleted code or nil if there was none
BombModule.DeleteDrop = function(temp_ship)
    local newTable = {}
    local deleteCode = nil
    for k, dTable in pairs(BombModule.dropTable) do
        if dTable.ship == temp_ship or dTable.temp == temp_ship then
            deleteCode = dTable.code
            DialModule.DeleteTemplate(dTable.ship)
        else
            table.insert(newTable, dTable)
        end
    end
    BombModule.dropTable = newTable
    return deleteCode
end

-- Delete drops on ship/template delete
BombModule.onObjectDestroyed = function(obj)
    for k, dTable in pairs(BombModule.dropTable) do
        if dTable.ship == obj or dTable.temp == obj then
            BombModule.DeleteDrop(obj)
        end
    end
end

-- Bomb type -> offset data
BombModule.tokenOffset = {}
BombModule.tokenOffset.standardAoE = { pos = { 0, Dim.Convert_mm_igu(-2), Dim.Convert_mm_igu(-4.5) }, rot = { 0, 90, 0 } }
BombModule.tokenOffset.prox = { pos = { 0, Dim.Convert_mm_igu(-2), Dim.Convert_mm_igu(15) }, rot = { 0, 90, 0 } }
BombModule.tokenOffset.cluster = { pos = { 0, Dim.Convert_mm_igu(-2), 0 }, rot = { 0, 180, 0 } }
BombModule.tokenOffset.connor = { pos = { 0, Dim.Convert_mm_igu(-2), Dim.Convert_mm_igu(21) }, rot = { 0, 180, 0 } }
BombModule.tokenOffset.rgc = { pos = { 0, Dim.Convert_mm_igu(-1), Dim.Convert_mm_igu(9.5) }, rot = { 0, 0, 0 } }
BombModule.tokenOffset.chaff = { pos = { Dim.Convert_mm_igu(-0.05), Dim.Convert_mm_igu(-1), Dim.Convert_mm_igu(12.5) }, rot = { 0, 90, 0 } }

-- Bomb name -> type data
BombModule.snapTable = {}
BombModule.snapTable['Ion Bomb'] = 'standardAoE'
BombModule.snapTable['Proton Bomb'] = 'standardAoE'
BombModule.snapTable['Seismic Charge'] = 'standardAoE'
BombModule.snapTable['Thermal Detonator'] = 'standardAoE'
BombModule.snapTable.Bomblet = 'standardAoE'
BombModule.snapTable['Electro-Proton Bomb'] = 'standardAoE'
BombModule.snapTable['Proximity Mine'] = 'prox'
BombModule.snapTable['Cluster Mine (middle)'] = 'cluster'
BombModule.snapTable['Connor Net'] = 'connor'
BombModule.snapTable['Loose Cargo'] = 'rgc'
BombModule.snapTable['Concussion Bomb'] = 'standardAoE'
BombModule.snapTable['Electro-Chaff Cloud'] = 'chaff'
BombModule.snapTable['Blaze Bomb'] = 'standardAoE'

-- Minimum distance to snap
BombModule.snapDist = 1.5
-- Snap on drop
BombModule.OnTokenDrop = function(token)
    -- Get the offset data
    local offset = BombModule.tokenOffset[BombModule.snapTable[token.getName()]]

    -- Deduct closest bomb drop point within snap distance
    local closest = { dist = BombModule.snapDist + 1, pointKey = nil }
    local tPos = token.getPosition()
    for k, dTable in pairs(BombModule.dropTable) do
        local newDist = Vect.Distance(tPos, dTable.dest.pos)
        if newDist < closest.dist then
            closest.dist = newDist
            closest.pointKey = k
            closest.temp = dTable.temp
        end
    end

    -- If there was one
    if closest.pointKey ~= nil then
        -- Move the token to the snap points
        local drop = BombModule.dropTable[closest.pointKey]
        local destPos = Vect.Sum(drop.dest.pos, Vect.RotateDeg(offset.pos, drop.dest.rot[2]))

        local size = drop.ship.getTable("Data").Size or 'small'
        if size == 'large' then
            destPos = Vect.Sum(destPos, Vect.RotateDeg({ 0, 0, Dim.Convert_mm_igu(-20) }, drop.dest.rot[2]))
        elseif size == 'medium' then
            destPos = Vect.Sum(destPos, Vect.RotateDeg({ 0, 0, Dim.Convert_mm_igu(-10) }, drop.dest.rot[2]))
        end
        local destRot = Vect.Sum(drop.dest.rot, offset.rot)
        destPos[2] = drop.ship.getPosition()[2] + offset.pos[2]
        token.lock()
        token.setPositionSmooth(destPos, false, true)
        token.setRotationSmooth(destRot, false, true)
        XW_cmd.SetBusy(token)
        MoveModule.WaitForResting(token, { pos = destPos, rot = destRot })
        -- Expand clusters
        if token.getName() == 'Cluster Mine (middle)' then
            BombModule.ExpandCluster({ pos = destPos, rot = destRot })
        end

        if token.getName() == 'Electro-Chaff Cloud' then
            fuseBag = getObjectFromGUID(Fuse_Bag_GUID)
            fuseBag.takeObject({
                position = vector(destPos[1], destPos[2], destPos[3]) + vector(0, 1, 0),
                smooth = true,
            })
        end

        if token.getName() == 'Blaze Bomb' then
            --BombModule.SpawnBlaze({pos=destPos, rot=destRot})
        end

        if token.hasTag('Mine') then
            BombModule.CheckMineDroppedOverlapping(token)
        end
        AnnModule.Announce(
            { type = 'action', note = drop.ship.getName() .. ' dropped a ' .. token.getName():gsub('%(middle%)', 'set') },
            'all')
        closest.temp.destruct()
        return true
    else
        return false
    end
end

BombModule.CheckMineDroppedOverlapping = function(token, ownship)
    local mine = token
    Wait.condition(
        function()
            local ships = getObjectsWithTag('Ship')
            local minDist = Dim.Convert_mm_igu(110)
            local minePos = mine.getPosition()
            for _, ship in pairs(ships) do
                if ship ~= ownship then
                    local shipPos = ship.getPosition()
                    local dist = math.sqrt(math.pow((minePos.x - shipPos.x), 2) + math.pow((minePos.z - shipPos.z), 2))
                    if dist < minDist then
                        local collissions = MoveModule.CheckMineCollisions(ship,
                            { pos = ship.GetPosition(), rot = ship.GetRotation() }, false, nil)
                        for _, col in pairs(collissions) do
                            if col == mine then
                                AnnModule.Announce(
                                    {
                                        type = 'warn',
                                        note = mine.getName() ..
                                            ' appears to have been dropped ontop of ' .. ship.getName()
                                    }, 'all')
                            end
                        end
                    end
                end
            end
        end,
        function()
            return (mine.resting == true) and (mine.isSmoothMoving() == false)
        end)
end

-- TODO: try to move or integrate this with Bomb Code
clusterScript = [[
-- Convert argument from IN-GAME UNITS to MILIMETERS
local Dim = require("Dim")
Dim.mm_igu_ratio = 0.03637
--function Convert_igu_mm(in_game_units)
--    return in_game_units/Dim.mm_igu_ratio
--end


checkingRange = nil
scale = 1/self.getScale().x

local removeButtonUp = {
    click_function = 'removeCheckRange',
    label = 'Remove',
    function_owner = self,
    position = {0, 0.1*scale, 0},
    rotation = {0, 0, 0},
    width = 400*scale,
    height = 300*scale,
    font_size = 100*scale,
    color = {0.7, 0.7, 0.7}
}

local removeButtonDown = {
    click_function = 'removeCheckRange',
    label = 'Remove',
    function_owner = self,
    position = {0, -0.1*scale, 0},
    rotation = {180, 0, 0},
    width = 400*scale,
    height = 300*scale,
    font_size = 100*scale,
    color = {0.7, 0.7, 0.7}
}

function removeCheckRange()
  checkRange(nil)
end

function onLoad(save_state)
    self.addContextMenuItem("Check Range 1", function() checkRange(1) end, false)
end

function checkRange(range)
    if range and checkingRange ~= range then
      printToAll("Checking for ships within range ".. range .. " of " .. self.getName(), color(1.0,1.0,0))
      vector_lines = {}
      for k,obj in pairs(getObjectsWithAnyTags({'Ship'})) do
          my_pos = self.getNearestPointFromObject(obj)
          closest = Global.call("API_GetClosestPointToShip", {ship=obj,point=my_pos})
          distance = Dim.Convert_igu_mm(closest.length)
          if distance < 100*range then
              printToAll(obj.getName() .. " is within range ".. range .. " of ".. self.getName(), color(1.0,1.0,0))
              table.insert(vector_lines, {
                  points = {self.positionToLocal(closest.A), self.positionToLocal(closest.B)},
                  color = {1,1,1},
                  thickness = 0.05*scale,
                  rotation = vector(0,0,0)
              })
          end
      end
      self.clearButtons()
      self.setVectorLines(vector_lines)
      if #vector_lines > 0 then
        checkingRange = range
        if self.is_face_down then
          self.createButton(removeButtonDown)
        else
          self.createButton(removeButtonUp)
        end
      else
        checkingRange = nil
        printToAll("No ships is within range ".. range .." of " .. self.getName(), color(1.0,1.0,0))
      end
    else
      checkingRange = nil
      self.clearButtons()
      self.setVectorLines({})
    end
end
]]

-- Spawn side tokens for cluster mine
BombModule.ExpandCluster = function(center)
    local offset = { Dim.Convert_mm_igu(43.5), 0, Dim.Convert_mm_igu(-1.5) }
    local tParams = { type = 'Custom_Token' }
    local tCustom = { image = '{verifycache}https://i.imgur.com/MqlYZzR.png', thickness = 0.1, merge_distance = 5 }

    local t1 = spawnObject(tParams)
    t1.setCustomObject(tCustom)
    t1.lock()
    local destOffset1 = Vect.RotateDeg(offset, center.rot[2])
    t1.setPositionSmooth(Vect.Sum(center.pos, destOffset1), false, true)
    t1.setRotationSmooth(center.rot, false, true)
    t1.setScale({ 0.4554, 0.4554, 0.4554 })
    t1.setName('Cluster Mine (side)')
    t1.addTag('Mine')
    t1.setLuaScript(clusterScript)
    BombModule.CheckMineDroppedOverlapping(t1)

    local t2 = spawnObject(tParams)
    t2.setCustomObject(tCustom)
    t2.lock()
    local destOffset2 = Vect.RotateDeg(Vect.ScaleEach(offset, { -1, 1, 1 }), center.rot[2])
    t2.setPositionSmooth(Vect.Sum(center.pos, destOffset2), false, true)
    t2.setRotationSmooth(center.rot, false, true)
    t2.setScale({ 0.4554, 0.4554, 0.4554 })
    t2.setName('Cluster Mine (side)')
    t2.addTag('Mine')
    t2.setLuaScript(clusterScript)
    BombModule.CheckMineDroppedOverlapping(t2)
end

-- TODO: compare with BlazeBomb code
BombModule.SpawnBlaze = function(center)
    local offset = { -Dim.Convert_mm_igu(53), 0, 0 }
    local tParams = { type = 'Custom_Model' }
    local tCustom = {
        mesh =
        'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/tokens/devices/proximity.obj',
        diffuse =
        'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/tokens/devices/blaze.png',
        collider =
        'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/tokens/devices/proximity-col.obj',
        convex = true,
        material = 3,
        type = 0
    }

    local t1 = spawnObject(tParams)
    t1.setCustomObject(tCustom)
    t1.lock()
    local destOffset1 = Vect.RotateDeg(offset, center.rot[2])
    t1.setPositionSmooth(Vect.Sum(center.pos, destOffset1), false, true)
    t1.setRotationSmooth(center.rot, false, true)
    t1.setScale({ 0.38, 0.38, 0.38 })
    t1.setName('Blaze')
    t1.addTag('Mine')
    t1.addTag('Obstacle')
    t1.setLuaScript(clusterScript)
    BombModule.CheckMineDroppedOverlapping(t1)
    fuseBag = getObjectFromGUID(Fuse_Bag_GUID)
    fuseBag.takeObject({
        position = Vect.Sum(Vect.Sum(center.pos, destOffset1), { 0, 1, 0 }),
        smooth = true,
    })
end

-- END BOMB MODULE
--------

--------
-- DIRECT TTS EVENT HANDLING
-- Watch for changed descriptions, handle destroyed objects, saving et cetera

-- ~~~~~~
-- CONFIGURATION:

-- How many frames pass between updating watched objects (ships) list
-- It's so we don't go through massive list of all objects on table each frame (why would we?)

time_time = Time.time
os_time = os.time()

function init_event_check()
    Wait.time(event_check, 0.2, -1)
    Wait.time(ShipProximityHider.proximity_check, 0.3, -1)
end

EventSub.Register('onLoad', init_event_check)

-- This is called each frame
function event_check()
    -- If description is not blank, try processing it
    for k, obj in pairs(getObjectsWithTag('Ship')) do
        if obj ~= nil and obj.getDescription() ~= '' then
            Wait.frames(
                function()
                    XW_cmd.Process(obj, obj.getDescription())
                end
                , 1) -- Waiting a frame to allow Animated Ships to pick up command
        end
    end

    --if Time.frame_count%1 == 0 then
    local os_now = os.time()
    local os_diff = os_now - os_time
    os_time = os_now
    local time_now = Time.time
    local time_diff = time_now - time_time
    time_time = time_now
    --printToAll("Frame dt: " .. Time.delta_time)
    --printToAll("DT Diff:  " .. os_diff - time_diff)
    --end
end

-- When something is destroyed, it is called as an argument here (with 1 more frame to live)
function onObjectDestroyed(dying_object)
    -- Handle history delete and emergency restore saving
    MoveModule.onObjectDestroyed(dying_object)
    -- Handle killing rulers
    RulerModule.onObjectDestroyed(dying_object)
    -- Handle killing bomb drop templates
    BombModule.onObjectDestroyed(dying_object)
    -- Handle killing tokens
    TokenModule.onObjectDestroyed(dying_object)
    -- Dial manager handeling dying dials and ships
    DialManagerModule.onObjectDestroyed(dying_object)
end

-- Report peeking on dials
function onObjectPeek(object, player_color)
    local token_type = object.getVar("__XW_TokenType")
    if token_type == "helper:Dial" then
        if object.is_face_down == false then
            local owning_player = object.getVar("playerColor")
            if owning_player == nil then
                owning_player = "no one"
            end
            if player_color ~= owning_player then
                printToAll(
                    player_color ..
                    " player attempted to peek on " .. object.getName() .. "s dial, owned by " .. owning_player .. "!!",
                    { 1, 0, 0 })
            else
                printToAll(player_color .. " peeked on " .. object.getName() .. "s dial", { 0.6, 0.6, 1 })
                local set_manouver = object.getVar("setMan")
                if set_manouver == "" then
                    printToColor(object.getName() .. "s dial is not yet set", player_color, { 0.6, 0.6, 1 })
                else
                    local info = MoveData.DecodeInfo(set_manouver)
                    local manouver = info.speed
                    -- [koiogran] [segnor] [talon] [reverse] [straight] [forward] [backward] [nil]
                    if info.extra == "koiogran" then
                        manouver = manouver .. " " .. info.extra
                    else
                        manouver = manouver .. " " .. info.type
                    end
                    if info.dir ~= nil then
                        manouver = manouver .. " " .. info.dir
                    end
                    if info.extra and info.extra ~= "koiogran" then
                        manouver = manouver .. " " .. info.extra
                    end
                    printToColor(object.getName() .. "s dial is set to: " .. manouver, player_color, { 0.6, 0.6, 1 })
                end
            end
        end
    end
end

-- END DIRECT TTS EVENT HANDLING
--------


--------
-- COLLISION CHECKING MODULE
-- Generally checking if two rotated rectangles overlap

-- ~~~~~~
-- CONFIGURATION:

-- How many milimeters should we widen the base from each side
-- With this at zero, sometimes ships overlap after a move
addidionalCollisionMargin_mm = -0.5
-- ~~~~~~

-- General idea here: https://www.gamedev.net/page/resources/_/technical/game-programming/2d-rotated-rectangle-collision-r2604
-- Originally written by Flolania and Hera Verigo, slightly refitted here

-- Return corners of ship base in a {xPos, zPos} table format
-- shipInfo: {ship=shipObjectReference, pos=shipPosition, rot=shipRotation}
function getCorners(shipInfo)
    local corners = {}
    local spos = shipInfo.pos
    local srot = shipInfo.rot[2]
    local baseSize = shipInfo.ship.getTable("Data").Size or 'small'
    local size = Dim.Convert_mm_igu((Dim.mm_baseSize[baseSize] / 2) + addidionalCollisionMargin_mm)
    local world_coords = {}
    world_coords[1] = { spos[1] - size, spos[3] + size }
    world_coords[2] = { spos[1] + size, spos[3] + size }
    world_coords[3] = { spos[1] + size, spos[3] - size }
    world_coords[4] = { spos[1] - size, spos[3] - size }
    for r, corr in ipairs(world_coords) do
        local xcoord = spos[1] + ((corr[1] - spos[1]) * math.sin(math.rad(srot))) -
            ((corr[2] - spos[3]) * math.cos(math.rad(srot)))
        local ycoord = spos[3] + ((corr[1] - spos[1]) * math.cos(math.rad(srot))) +
            ((corr[2] - spos[3]) * math.sin(math.rad(srot)))
        corners[r] = { xcoord, ycoord }
    end
    return corners
end

-- Return axes perpendicular to sides of two rectangles
function getAxis(c1, c2)
    local axis = {}
    axis[1] = { c1[2][1] - c1[1][1], c1[2][2] - c1[1][2] }
    axis[2] = { c1[4][1] - c1[1][1], c1[4][2] - c1[1][2] }
    axis[3] = { c2[2][1] - c2[1][1], c2[2][2] - c2[1][2] }
    axis[4] = { c2[4][1] - c2[1][1], c2[4][2] - c2[1][2] }
    return axis
end

function dot2d(p, o)
    return p[1] * o[1] + p[2] * o[2]
end

-- Check if any part of two rectangles overlap
-- Rectangles as in ship bases of a proper size
-- shipInfo: {ship=shipObjectReference, pos=shipPosition, rot=shipRotation}
function collide(shipInfo1, shipInfo2)
    local c2 = getCorners(shipInfo1)
    local c1 = getCorners(shipInfo2)
    local axis = getAxis(c1, c2)
    local scalars = {}
    for i1 = 1, #axis do
        for i2, set in pairs({ c1, c2 }) do
            scalars[i2] = {}
            for i3, point in pairs(set) do
                table.insert(scalars[i2], dot2d(point, axis[i1]))
            end
        end
        local s1max = math.max(unpack(scalars[1]))
        local s1min = math.min(unpack(scalars[1]))
        local s2max = math.max(unpack(scalars[2]))
        local s2min = math.min(unpack(scalars[2]))
        if s2min > s1max or s2max < s1min then
            return false
        end
    end
    return true
end

-- END COLLISION CHECKING MODULE
--------

-------
-- Local Reference function, for spawning items relative to the quick build card
function LocalPos(object, position)
    local rot = object.getRotation()
    local lPos = { position[1], position[2], position[3] }
    -- Z-X-Y extrinsic
    local zRot = RotMatrix('z', rot.z)
    lPos = RotateVector(zRot, lPos)
    local xRot = RotMatrix('x', rot.x)
    lPos = RotateVector(xRot, lPos)
    local yRot = RotMatrix('y', rot.y)
    lPos = RotateVector(yRot, lPos)

    return Vect.Sum(lPos, object.getPosition())
end

------

function onObjectSpawned(obj)
    obj.hide_when_face_down = false
end

XW_cmd.AddCommand('rot[lr]?[12]?', 'rotate')
XW_cmd.AddCommand('turret[12]?', 'turretarc')
XW_cmd.AddCommand('a', 'fixedarc')

mountRotations = {
    front = vector(0, 0, 0),
    left = vector(0, -90, 0),
    back = vector(0, 180, 0),
    right = vector(0, 90, 0),
    frontback = vector(0, 0, 0),
    leftright = vector(0, 90, 0)
}

arcNames = {
    front = "Front",
    left = "Left",
    back = "Back",
    right = "Right",
    frontback = "Front & Back",
    leftright = "Left & Right",
    fullfront = "Full Front",
    fullback = "Full Back",
    bullseye = "Bullseye",
}

arcToCmnd = {
    front = "f",
    left = "sl",
    back = "b",
    right = "sr",
    frontback = "frontback",
    leftright = "leftright",
    fullfront = "ff",
    fullback = "fb",
    bullseye = "bull",
}

nextMountDirection = {
    rotateleft = {
        front = "left",
        left = "back",
        back = "right",
        right = "front",
        leftright = "frontback",
        frontback = "leftright"
    },
    rotateright = {
        front = "right",
        left = "front",
        back = "left",
        right = "back",
        leftright = "frontback",
        frontback = "leftright"
    }
}

mountDirectionToArcs = {
    front = { "front" },
    left = { "left" },
    back = { "back" },
    right = { "right" },
    leftright = { "left", "right" },
    frontback = { "front", "back" },
}

mountToIndex = {
    main = '',
    front = '1',
    rear = '2'
}

-- TODO: this is used by DataPad with Ship Spawning
pilotCardScript =
[[
dial = nil
ship = nil
function addTintObject(params)
    if params[1] == "ship" then
      ship = params[2]
    elseif params[1] == "dial" then
      dial = params[2]
    end
end

function DisableAttachedColliders()
  for i, child in ipairs(self.getChildren()) do
    if i ~= 1 then
      if child.getComponent("MeshCollider") then
        child.getComponent("MeshCollider").set("enabled", false)
      end
    end
  end
end

function tint_check()
    local tint = self.getColorTint()
    if tint ~= color(1,1,1,1) then
      self.setColorTint(color(1,1,1,1))
      if dial ~= nil then
        dial.setColorTint(tint)
      end

      for i, attachment in pairs(self.getAttachments()) do
        id = self.removeAttachment(attachment.index)
        id.setColorTint(tint)
        self.addAttachment(id)
      end

      if ship ~= nil then
        local data = ship.getTable("Data")
        data.ColorId = tint
        ship.setTable("Data", data)
        for i, attachment in pairs(ship.getAttachments()) do
          id = ship.removeAttachment(0) -- This process puts the front attachment in the back, and the index is rearranged
          if id.getName():find("Arc Indicator") then
            local indicator = ship.getTable('arc_indicators')[id.getDescription()] or {}
            if indicator.color_by_id then
              id.setColorTint(tint)
            end
          elseif id.getName() == "ColorId" then
            id.setColorTint(tint)
          end
          ship.addAttachment(id)
        end
      end
      Wait.frames(DisableAttachedColliders, 1)

    end
end

loaded = false

function onLoad(savestate)
  loaded = true
  Wait.time(tint_check, 0.5, -1)
end

function isLoadedAndStill()
  return loaded and self.resting
end
]]

-------
--spawner function, checks for Pilots and Upgrades lists and spawn the respective objects

function newSpawner(listTable)
    --listTable contains :

    --Pilots[x] = table

    --Upgrades[x] = {string1, string2...}
    --spawnCard = Object reference used to position the spawned material
    --Faction = String

    Pilots = listTable.Pilots
    Upgrades = listTable.Upgrades
    spawnCard = listTable.spawnCard
    Faction = listTable.Faction
    Customization = listTable.Customization or {}
    local dialSkin = listTable.factionDial
    spawnedPilotList = {}
    local spawnPrefix =
    "{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/ships-v2/"
    local factionnames = { "rebel", "empire", "scum", "resistance", "first-order", "republic", "separatists" }

    PosBag1 = { 5, 5, 0 }
    PosBag2 = { 10, 10, 0 }
    PosBag3 = { 15, 15, 0 }
    PosBag4 = { 20, 20, 0 }
    PoaBag5 = { 25, 25, 0 }
    tempBagAcc = getObjectFromGUID(Accessories_Bag_GUID).clone({ position = PosBag3 }) -- Accessories bag

    --Stablishes lists of available upgrades, pilots, accessories, ships and mobile upgrades
    listaAcc = tempBagAcc.getObjects()

    tokens = {}
    for k, acc in ipairs(listaAcc) do
        if acc.name == 'Charge' then
            tokens.Charge = tempBagAcc.takeObject({ rotation = spawnCard.getRotation(), guid = acc.guid, smooth = false })
        elseif acc.name == 'Force' then
            tokens.Force = tempBagAcc.takeObject({ rotation = spawnCard.getRotation(), guid = acc.guid, smooth = false })
        elseif acc.name == 'Shield' then
            tokens.Shield = tempBagAcc.takeObject({ rotation = spawnCard.getRotation(), guid = acc.guid, smooth = false })
        elseif acc.name == 'Energy' then
            tokens.Energy = tempBagAcc.takeObject({ rotation = spawnCard.getRotation(), guid = acc.guid, smooth = false })
        end
    end

    --Store the initial position of the Quick Build Card
    storePos = spawnCard.getPosition()
    storeRot = spawnCard.getRotation()

    shipIndex = 1 --Sets index of ship being spawned

    while Pilots[shipIndex] ~= nil do
        --Values used for accessories spawn and layout
        UpNum = 0
        Turret = 0
        dualTurret = 0
        Bombs = 0
        hasMob = 0
        bombTokenDescription = ''
        local configCardGUID = nil

        if Pilots[shipIndex].standardized_loadout then
            spawnCard.setPosition(LocalPos(spawnCard, { -1.1, 0, 0 }))
        end

        -- Spawn Mobile Upgrades
        for j, Up in pairs(Upgrades[shipIndex]) do
            if Up.Config == true then
                finalPos = LocalPos(spawnCard, { -1.9, 0, 0 }) --Layout adjustment
                spawnCard.setPosition(finalPos)
                pos = LocalPos(spawnCard, { 1.42, 0, 5.5 })
                rot = spawnCard.getRotation()
                rot.y = rot.y
                cardLink = Up.card
                cardBackLink = Up.cardB
                if Customization[Up.name] ~= nil then
                    cardLink = Customization[Up.name].face or Up.card
                    cardBackLink = Customization[Up.name].back or Up.cardB
                end
                deck = Decker.Asset(cardLink, cardBackLink)
                card = Decker.Card(deck, 1, 1)
                newUp = card:spawn({ position = pos, rotation = rot, scale = { 0.68, 0.68, 0.68 } })
                newUp.setName(Up.name)
                newUp.addTag("ConfigCard")
                configCardGUID = newUp.getGUID()
                hasMob = 1
                charges = Up.Charge
                while charges > 0 do
                    if charges == 5 then
                        pos = LocalPos(spawnCard, { -1.7 + 4, 0, 1.9 })
                    elseif charges == 4 then
                        pos = LocalPos(spawnCard, { -1.7 + 4, 0, 2.8 })
                    elseif charges == 3 then
                        pos = LocalPos(spawnCard, { -2.6 + 4, 0, 2.8 })
                    elseif charges == 2 then
                        pos = LocalPos(spawnCard, { -1.7 + 4, 0, 3.7 })
                    elseif charges == 1 then
                        pos = LocalPos(spawnCard, { -2.6 + 4, 0, 3.7 })
                    else
                        charges = 0
                    end
                    charges = charges - 1
                    chargeClone = tokens.Charge.clone()
                    chargeClone.setPosition(pos)
                    chargeClone.setVar("charge_owner", Pilots[shipIndex].name)
                    chargeClone.setVar("charge_name", Up.name)
                end
            end
        end
        for j, Up in pairs(Upgrades[shipIndex]) do
            if Up.Config ~= true then
                --Indicates there's a card left of the pilot card, for layout purposes
                pos = LocalPos(spawnCard, { -1.42 - 1.78 * UpNum, 1 - 0.2 * UpNum, 5.5 })
                rot = spawnCard.getRotation()
                rot.y = rot.y - 90
                cardLink = Up.card
                cardBackLink = Up.cardB
                if Customization[Up.name] ~= nil then
                    cardLink = Customization[Up.name].face or Up.card
                    cardBackLink = Customization[Up.name].back or Up.cardB
                end
                deck = Decker.Asset(cardLink, cardBackLink)
                card = Decker.Card(deck, 1, 1)
                local rotUp = rot
                rotUp.y = rotUp.y + 90
                newUp = card:spawn({ position = pos, rotation = rotUp, scale = { 0.68, 0.68, 0.68 } })
                newUp.setName(Up.name)
                if Up.Condition ~= nil then
                    --Checks and spawn conditions associated to pilots
                    for k, acc in ipairs(listaAcc) do
                        if acc.name == Up.Condition then
                            pos = LocalPos(spawnCard, { -2 - 1.78 * UpNum, 1 - 0.2 * UpNum, 8 })
                            rot = spawnCard.getRotation()
                            newAsset = tempBagAcc.takeObject({ position = pos, rotation = rot, guid = acc.guid, smooth = false })
                            assetClone = newAsset.clone()
                            assetClone.setPosition(pos)
                            tempBagAcc.putObject(newAsset)
                        end
                    end
                end
                --Checks and spawns Charge Tokens with appropriate layout (up to 4 tokens)
                charges = Up.Charge
                if charges > 0 then
                    while charges > 0 do
                        if charges == 5 then
                            pos = LocalPos(spawnCard, { -1.7 - 1.78 * UpNum, 1, 1.9 })
                        elseif charges == 4 then
                            pos = LocalPos(spawnCard, { -1.7 - 1.78 * UpNum, 1, 2.8 })
                        elseif charges == 3 then
                            pos = LocalPos(spawnCard, { -2.6 - 1.78 * UpNum, 1, 2.8 })
                        elseif charges == 2 then
                            pos = LocalPos(spawnCard, { -1.7 - 1.78 * UpNum, 1, 3.7 })
                        elseif charges == 1 then
                            pos = LocalPos(spawnCard, { -2.6 - 1.78 * UpNum, 1, 3.7 })
                        else
                            charges = 0
                        end
                        charges = charges - 1
                        chargeClone = tokens.Charge.clone()
                        chargeClone.setPosition(pos)
                        chargeClone.setVar("charge_owner", Pilots[shipIndex].name)
                        chargeClone.setVar("charge_name", Up.name)
                    end
                end
                UpNum = UpNum + 1 --Update number of upgrade being spawned
            end
        end

        if Pilots[shipIndex].id ~= 0 then
            --Pilot and Ship Spawn
            pilotName = Pilots[shipIndex].name
            card = Pilots[shipIndex].card
            cardB = Pilots[shipIndex].cardB
            local tint = color(0, 0, 0, 0)
            local modeltint = color(1, 1, 1, 1)
            if Customization[pilotName] ~= nil then
                tint = Customization[pilotName].tint or color(0, 0, 0, 0)
                card = Customization[pilotName].face or Pilots[shipIndex].card
                cardB = Customization[pilotName].back or Pilots[shipIndex].cardB
                modeltint = Customization[pilotName].modeltint or color(1, 1, 1, 1)
            end

            pos = LocalPos(spawnCard, { 0, 1.2, 5.5 })
            rot = spawnCard.getRotation()
            local newPil = nil
            if card ~= '' then
                if cardB ~= nil then
                    deck = Decker.Asset(card, cardB)
                    card = Decker.Card(deck, 1, 1)
                    newPil = card:spawn({ position = pos, rotation = rot })
                    newPil.setName(pilotName)
                    newPil.setDescription(Pilots[shipIndex].list)
                    newPil.setLuaScript(pilotCardScript)
                    newPil.setLock(true)

                    -- Spawn Pilot Identifier
                    local card = newPil
                    local idpos = pos
                    local idrot = rot

                    pilotIdSpawnFunc = function()
                        local pilotId = spawnObject({
                            type = "Custom_Model",
                            position = idpos,
                            rotation = idrot,
                            scale = Dim.mm_ship_scale,
                            sound = false,
                            snap_to_grid = false,
                        })
                        pilotId.setCustomObject({
                            mesh =
                            '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/cardid.obj',
                            convex = true,
                            material = 1,
                            type = 0
                        })
                        pilotId.setColorTint(tint)
                        card.addAttachment(pilotId)
                        card.setLock(false)
                    end
                    Wait.condition(pilotIdSpawnFunc, function()
                        return (not card.spawning)
                    end)
                end
            end
            if pilotName ~= '' then
                for k, acc in pairs(listaAcc) do
                    local card = newPil
                    if acc.name == 'Unassigned Dial' then
                        local dialpos = LocalPos(spawnCard, { 0, 1, 12 })
                        local dialrot = rot
                        local dial = tempBagAcc.takeObject(
                            {
                                position = dialpos,
                                rotation = dialrot,
                                guid = acc.guid
                            })
                        local newDial = dial.clone()
                        newDial.setPosition(pos)
                        tempBagAcc.putObject(dial)
                        local conditionFunc = function()
                            return (not card.spawning) and (not newDial.spawning)
                        end
                        local executeFunc = function()
                            newDial.setCustomObject({ ['diffuse'] = dialSkin })
                            newDial = newDial.reload()
                            newDial.setColorTint(tint)
                            newDial.setPosition(dialpos)
                            newDial.setRotation(dialrot)
                            card.call('addTintObject', { 'dial', newDial })
                        end
                        Wait.condition(executeFunc, conditionFunc)
                    end
                end
            end
            if Pilots[shipIndex].Condition ~= nil then
                --Checks and spawn conditions associated to pilots
                for k, acc in ipairs(listaAcc) do
                    if acc.name == Pilots[shipIndex].Condition then
                        pos = LocalPos(spawnCard, { -2 - 1.78 * UpNum, 1, 8 })
                        rot = spawnCard.getRotation()
                        newAsset = tempBagAcc.takeObject({ position = pos, rotation = rot, guid = acc.guid })
                        assetClone = newAsset.clone()
                        assetClone.setPosition(pos)
                        tempBagAcc.putObject(newAsset)
                    end
                end
            end

            local newShip = nil
            local texture = nil
            if Customization[pilotName].texture ~= nil then
                texture = Customization[pilotName].texture
            elseif Pilots[shipIndex].Data.texture ~= nil then
                texture = '{verifycache}' .. Pilots[shipIndex].Data.texture
            end
            local shipoffset = vector(0, 0, 0)
            Pilots[shipIndex].Data.ColorId = tint
            if Pilots[shipIndex].Data.Config then
                Pilots[shipIndex].Data.Config.CardGUID = configCardGUID
            end

            if Customization[pilotName].texture ~= nil then
                texture = Customization[pilotName].texture
            elseif Pilots[shipIndex].Data.texture ~= nil then
                texture = '{verifycache}' .. Pilots[shipIndex].Data.textures[Pilots[shipIndex].Data.texture]
            end
            shipoffset = vector(0, 2.2, 0)
            local size = Pilots[shipIndex].Size
            local arcs = Pilots[shipIndex].Data.arcs
            local fixedarc = "none"
            if arcs.fixed then
                fixedarc = arcs.fixed.type[1] or "none"
            end
            if size == "huge" then
                pos = LocalPos(spawnCard, { 0, 0, 12 })
            else
                pos = LocalPos(spawnCard, { 0, 0, 9 })
            end
            rot = spawnCard.getRotation()
            local base_prototype = getObjectFromGUID(CompositeBase_GUID)
            newShip = base_prototype.clone()
            newShip.setPositionSmooth(pos, false, true)
            newShip.setRotationSmooth(rot, false, true)
            newShip.setScale(Dim.mm_ship_scale)

            newShip.setCustomObject({
                mesh = spawnPrefix .. "bases/" .. size .. "/base.obj?1",
                collider = ShipVerification.colliders[size],
                diffuse = spawnPrefix ..
                    "bases/" .. size .. "/" .. fixedarc .. "/" .. factionnames[Faction] .. ".png",
                convex = true,
                material = 1,
                type = 1
            })
            newShip.setTable("Data", Pilots[shipIndex].Data)
            newShip.setLock(true)
            if Pilots[shipIndex].Data.ProximityHider then
                newShip.addTag("ProximityHider")
            end

            local base_name_str = pilotName
            if Pilots[shipIndex].Data.limited and Pilots[shipIndex].Data.limited > 0 then
                base_name_str = string.rep("•", Pilots[shipIndex].Data.limited) .. " " .. pilotName
            end
            newShip.setTable("UiData", {
                name = base_name_str,
                icon = Pilots[shipIndex].Ship,
                init = "init" .. Pilots[shipIndex].Data.initiative
            })

            local pegtype = Pilots[shipIndex].peg or size
            local pegCustomObject = {
                mesh = spawnPrefix .. "bases/pegs/" .. pegtype .. ".obj",
                diffuse = spawnPrefix .. "bases/" .. size .. "/" .. fixedarc .. "/" .. factionnames[Faction] .. ".png",
                collider =
                '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/minisculebox.obj',
                convex = true,
                material = 1,
                type = 1
            }
            local shippos = pos
            local shiprot = rot
            local ship = newShip
            local shipCustomObject = nil
            if Pilots[shipIndex].Data.mesh then
                shipCustomObject = {
                    mesh = '{verifycache}' .. Pilots[shipIndex].Data.mesh,
                    diffuse = texture,
                    collider =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/minisculebox.obj',
                    convex = true,
                    material = 1,
                    type = 1
                }
            end

            local pegAndShipSpawnFunction = function()
                local pegModel = spawnObject({
                    type         = "Custom_Model",
                    position     = shippos,
                    rotation     = shiprot,
                    scale        = Dim.mm_ship_scale,
                    sound        = false,
                    snap_to_grid = false,
                })
                pegModel.setName("Peg")
                pegModel.setCustomObject(pegCustomObject)
                ship.addAttachment(pegModel)
                if shipCustomObject then
                    local shipModel = spawnObject({
                        type         = "Custom_Model",
                        position     = vector(shippos[1], shippos[2], shippos[3]) + shipoffset,
                        rotation     = shiprot,
                        scale        = Dim.mm_ship_scale,
                        sound        = false,
                        snap_to_grid = false,
                    })
                    shipModel.setName("Ship")
                    shipModel.setCustomObject(shipCustomObject)
                    shipModel.setColorTint(modeltint)
                    ship.addAttachment(shipModel)
                end
            end
            Wait.condition(pegAndShipSpawnFunction,
                function() return (not ship.spawning) and (not ship.isSmoothMoving()) end)
            if newShip ~= nil then
                local ship = newShip
                local card = newPil
                local idpos = pos
                local idrot = rot
                local customObj = {
                    convex = true,
                    material = 1,
                    type = 1,
                    collider =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/minisculebox.obj',
                }
                if Pilots[shipIndex].Size == "small" then
                    customObj.mesh =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/Base_ID_Marker.obj'
                elseif Pilots[shipIndex].Size == "medium" then
                    customObj.mesh =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/Base%20ID%20MED.obj'
                elseif Pilots[shipIndex].Size == "large" then
                    customObj.mesh =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/Base%20ID%20LAR.obj'
                elseif Pilots[shipIndex].Size == "huge" then
                    customObj.mesh =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/Base_ID_HUGE.obj'
                end
                local shipIdSpawnFunc = function()
                    local shipId = spawnObject({
                        type = "Custom_Model",
                        position = idpos,
                        rotation = idrot,
                        scale = Dim.mm_ship_scale * 0.99,
                        sound = false,
                        snap_to_grid = false,
                    })
                    shipId.setCustomObject(customObj)
                    shipId.setColorTint(tint)
                    shipId.setName("ColorId")
                    ship.addAttachment(shipId)
                    ship.setLock(false)
                    ship.addTag("Ship")
                    ship.drag_selectable = true
                    ship.interactable = true

                    card.call('addTintObject', { 'ship', ship })
                    ship.call('initContextMenu')
                end
                if Pilots[shipIndex].Data.ProximityHider then
                    ship.addTag("ProximityHider")
                end
                Wait.condition(shipIdSpawnFunc,
                    function()
                        return (not ship.spawning) and (not ship.isSmoothMoving()) and (not card.spawning)
                    end)

                if Pilots[shipIndex].Data.Config and Pilots[shipIndex].Data.Config.States then
                    for k, config in pairs(Pilots[shipIndex].Data.Config.States) do
                        if config.Model then
                            local customObject = ship.getCustomObject()
                            customObject.mesh = config.Model
                            customObject.diffuse = texture
                            local configSpawnFunction = function()
                                local configModel = spawnObject({
                                    type = "Custom_Model",
                                    position = vector(idpos[1], idpos[2], idpos[3]) + shipoffset,
                                    rotation = idrot,
                                    scale = Dim.mm_ship_scale,
                                    sound = false,
                                    snap_to_grid = false,
                                })
                                configModel.setName("Config")
                                configModel.setDescription(tostring(k))
                                configModel.setCustomObject(customObject)
                                configModel.setColorTint(modeltint)
                                if k ~= 1 then
                                    configModel.setScale(vector(0.0001, 0.0001, 0.0001))
                                end
                                ship.addAttachment(configModel)
                                Wait.frames(function()
                                    ship.call("DisableAttachedColliders")
                                end, 2)
                                Wait.frames(function()
                                    ship.call("DisableAttachedColliders")
                                end, 10)
                                Wait.frames(function()
                                    ship.call("DisableAttachedColliders")
                                end, 30)
                            end
                            Wait.condition(configSpawnFunction,
                                function()
                                    return (not ship.spawning) and (not ship.isSmoothMoving())
                                end)
                        end -- if Config.Model
                    end     -- for Data.Config
                    if Pilots[shipIndex].Data.Config and Pilots[shipIndex].Data.Config.Token then
                        pos = LocalPos(spawnCard, { -1.5, 1, 8.7 })
                        local configToken = spawnObject({
                            type = "Custom_Model",
                            scale = { 0.38, 0.38, 0.38 },
                            rotation = { 0, 270, 0 },
                            position = pos,
                        })
                        configToken.setCustomObject({
                            mesh =
                            "https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/Items/tokens/flip/flipToken.obj",
                            diffuse = Pilots[shipIndex].Data.Config.Token,
                            type = 5,
                            material = 1,
                            specular_intensity = 0
                        })
                        configToken.setLuaScript(
                            [[
        __XW_Token = true
        __XW_TokenIdle = true
        __XW_TokenType = 'config'

        self.addTag('Flippable')

        function onFlip()
        local ship = Global.call("getShipTokenIsAssignedTo",{token=self})
        if ship and ship.getVar("SetConfiguration") then
            ship.call("SetConfiguration", {ConfigId=self.is_face_down and 1 or 2})
        end
        end
        ]])
                    end -- token
                end     -- config


                --[[customization_parts = {
                canopy = {
                model = 'https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/ships-v2/medium/firesprayclasspatrolcraft/firesprayV3-canopy.obj',
                material = 2,
                tintable = true
                }
            }]]
                --[[
            local Dim = require("Dim")
            for k, customization_part in pairs(Pilots[shipIndex].Data.customization_parts or {}) do
                if customization_part.model then
                local customObject = ship.getCustomObject()
                customObject.mesh = customization_part.model
                if customization_part.texture then
                    customObject.diffuse = customization_part.texture
                else
                    customObject.diffuse = texture
                end
                if customization_part.material then
                    customObject.material = customization_part.material
                end
                customObject.specular_sharpness = customization_part.specular_sharpness or 3
                customObject.specular_intensity = customization_part.specular_intensity or 0.1
                local customSpawnFunction = function()
                    local partModel = spawnObject({
                        type              = "Custom_Model",
                        position          = vector(idpos[1],idpos[2],idpos[3]) + shipoffset,
                        rotation          = idrot,
                        scale             = Dim.mm_ship_scale*1.01,
                        sound             = false,
                        snap_to_grid      = false,
                    })
                    partModel.setName("Part")
                    partModel.setDescription(tostring(k))
                    partModel.setCustomObject(customObject)
                    if customization_part.tint then
                    partModel.setColorTint(customization_part.tint)
                    end
                    ship.addAttachment(partModel)
                    Wait.frames(function() ship.call("DisableAttachedColliders") end, 2)
                    Wait.frames(function() ship.call("DisableAttachedColliders") end, 10)
                    Wait.frames(function() ship.call("DisableAttachedColliders") end, 30)
                end
                Wait.condition(customSpawnFunction , function() return (not ship.spawning) and (not ship.isSmoothMoving() ) end)
                end -- if customization_part.models
            end -- for Data.customization_parts

            ]]
            end

            for mount, turret in pairs(Pilots[shipIndex].Data.arcs.turret or {}) do
                local indicator_name = 'Arc Indicator' .. tostring(Faction)
                if turret.type[1] == 'doubleturret' then
                    indicator_name = 'Dual Arc Indicator' .. tostring(Faction)
                end
                local mount_pos = Pilots[shipIndex].Data.mountingPoints[mount]
                local offset = LocalPos(spawnCard, { mount_pos[1], 0, mount_pos[2] + 9 })
                for k, acc in pairs(listaAcc) do
                    if acc.name == indicator_name then
                        arcInd = tempBagAcc.takeObject({ position = offset, rotation = rot, guid = acc.guid, smooth = false })
                        newInd = arcInd.clone()
                        newInd.setPosition(pos)
                        tempBagAcc.putObject(arcInd)
                        newInd.setName(string.gsub(newInd.getName(), Faction, ''))
                    end
                end
            end

            if Pilots[shipIndex].Bomb == true then
                --Checks and spawn bomb drop token if needed
                for k, acc in ipairs(listaAcc) do
                    if acc.name == 'Bomb drop token (unassigned)' then
                        pos = LocalPos(spawnCard, { -1.5, 1, 8.7 })
                        bombDrop = tempBagAcc.takeObject({ position = pos, rotation = rot, guid = acc.guid, smooth = false })
                        dropClone = bombDrop.clone()
                        dropClone.setPosition(pos)
                        tempBagAcc.putObject(bombDrop)
                        dropClone.setDescription(Pilots[shipIndex].bombD)
                    end
                end
            end
            if Pilots[shipIndex].Docking == true then
                for k, acc in ipairs(listaAcc) do
                    if acc.name == 'Shuttle Launcher (assigned to mothership)' then
                        pos = LocalPos(spawnCard, { -1.5, 1, 8.7 })
                        shuttleDrop = tempBagAcc.takeObject({ position = pos, rotation = rot, guid = acc.guid, smooth = false })
                        dropClone = shuttleDrop.clone()
                        dropClone.setPosition(pos)
                        tempBagAcc.putObject(shuttleDrop)
                    end
                end
            end
            if Pilots[shipIndex].wingleader == true then
                for k, acc in ipairs(listaAcc) do
                    if acc.name == 'Epic Wing Token' then
                        pos = LocalPos(spawnCard, { -1.5, 1, 8.7 })
                        wingtoken = tempBagAcc.takeObject({ position = pos, rotation = rot, guid = acc.guid, smooth = false })
                        wingtokenclone = wingtoken.clone()
                        wingtokenclone.setPosition(pos)
                        tempBagAcc.putObject(wingtoken)
                    end
                end
            end

            --spawn pilot charge tokens
            if Pilots[shipIndex].Charge > 0 or Pilots[shipIndex].standardized_loadout then
                local chargeValue = Pilots[shipIndex].Charge
                while chargeValue > 0 do
                    chargeValue = chargeValue - 1
                    if Pilots[shipIndex].standardized_loadout then
                        pos = LocalPos(spawnCard, { 0.5 + 0.9 * chargeValue, 1, 3.4 })
                        if chargeValue > 2 then
                            pos = LocalPos(spawnCard, { 0.5 + 0.9 * (chargeValue - 3), 1, 2.5 })
                        end
                    elseif chargeValue == 3 then
                        pos = LocalPos(spawnCard, { -0.9, 1, 0.6 })
                    elseif chargeValue == 2 then
                        pos = LocalPos(spawnCard, { 0.9, 1, 1.6 })
                    elseif chargeValue == 1 then
                        pos = LocalPos(spawnCard, { 0, 1, 1.6 })
                    elseif chargeValue == 0 then
                        pos = LocalPos(spawnCard, { -0.9, 1, 1.6 })
                    else
                        charges = 0
                        pos = vector(0, 0, 0)
                    end
                    chargeClone = tokens.Charge.clone()
                    chargeClone.setPosition(pos)
                    chargeClone.setVar("charge_owner", Pilots[shipIndex].name)
                end
                if Pilots[shipIndex].standardized_loadout and Pilots[shipIndex].standardized_upgrades then
                    local total_height = 3.0
                    local step = total_height / #Pilots[shipIndex].standardized_upgrades
                    for k, upg in pairs(Pilots[shipIndex].standardized_upgrades) do
                        if upg.charge > 0 then
                            for i = 1, upg.charge, 1 do
                                chargeClone = tokens.Charge.clone()
                                chargeClone.setPosition(LocalPos(spawnCard,
                                    { -2.7 - i * 0.6, 1, 4 + step * (k - 1) + step /
                                    2 }))
                                chargeClone.setVar("charge_owner", Pilots[shipIndex].name)
                                chargeClone.setVar("charge_name", upg.name)
                                chargeClone.setScale(chargeClone.getScale() * 0.75)
                            end
                        end
                    end
                end
            end

            -- spawn force
            if Pilots[shipIndex].Force > 0 then
                local forceValue = Pilots[shipIndex].Force
                while forceValue > 0 do
                    forceValue = forceValue - 1
                    if Pilots[shipIndex].standardized_loadout then
                        pos = LocalPos(spawnCard, { 3.2, 1, 4.5 + 0.9 * forceValue })
                    elseif hasMob == 1 then
                        --adjusts layout if Mobile Upgrade is present
                        pos = LocalPos(spawnCard, { 1.7 + 0.9 * forceValue, 1, 3.4 })
                        if forceValue > 2 then
                            pos = LocalPos(spawnCard, { 1.7 + 0.9 * (forceValue - 3), 1, 2.5 })
                        end
                    else
                        pos = LocalPos(spawnCard, { 1.7, 1, 3.7 + 0.9 * forceValue })
                    end
                    forceClone = tokens.Force.clone()
                    forceClone.setPosition(pos)
                    forceClone.setVar("force_owner", Pilots[shipIndex].name)
                end
            end

            -- spawn energy
            if Pilots[shipIndex].Energy > 0 then
                local energyValue = Pilots[shipIndex].Energy
                while energyValue > 0 do
                    energyValue = energyValue - 1
                    if Pilots[shipIndex].standardized_loadout then
                        --pos = LocalPos(spawnCard, {3.3, 1, 5 + 0.9*Pilots[shipIndex].Force})
                        pos = LocalPos(spawnCard, { 0.5 + 0.9 * energyValue, 1, 3.4 })
                        if energyValue > 2 then
                            pos = LocalPos(spawnCard, { 0.5 + 0.9 * (energyValue - 3), 1, 2.5 })
                        end
                    else
                        pos = LocalPos(spawnCard, { 1.7, 1, 3.7 + 0.9 * energyValue })
                    end
                    energyClone = tokens.Energy.clone()
                    energyClone.setPosition(pos)
                    energyClone.setVar("energy_owner", Pilots[shipIndex].name)
                end
            end

            --Spawns Shields
            if Pilots[shipIndex].Shield > 0 then
                local shieldValue = Pilots[shipIndex].Shield
                --spawn shield tokens, layout good for up to 9 shields
                while shieldValue > 0 do
                    shieldValue = shieldValue - 1
                    if Pilots[shipIndex].standardized_loadout then
                        pos = LocalPos(spawnCard, { -2.2 + 0.9 * shieldValue, 1, 3.4 })
                        if shieldValue > 5 then
                            pos = LocalPos(spawnCard, { -2.2 + 0.9 * (shieldValue - 6), 1, 1.6 })
                        elseif shieldValue > 2 then
                            pos = LocalPos(spawnCard, { -2.2 + 0.9 * (shieldValue - 3), 1, 2.5 })
                        end
                    else
                        pos = LocalPos(spawnCard, { -1 + 0.9 * shieldValue, 1, 3.4 })
                        if shieldValue > 5 then
                            pos = LocalPos(spawnCard, { -1 + 0.9 * (shieldValue - 6), 1, 1.6 })
                        elseif shieldValue > 2 then
                            pos = LocalPos(spawnCard, { -1 + 0.9 * (shieldValue - 3), 1, 2.5 })
                        end
                    end
                    shieldClone = tokens.Shield.clone()
                    shieldClone.setPosition(pos)
                    shieldClone.setVar("shield_owner", Pilots[shipIndex].name)
                end
            end
        end

        if Pilots[shipIndex].standardized_loadout then
            charges = 0
            for _, upgrade in pairs(Pilots[shipIndex].standardized_upgrades) do
                charges = math.max(charges, upgrade.charge)
            end
            finalPos = LocalPos(spawnCard, { -(5.5 + charges * 0.7), 0, 0 })
        else
            finalPos = LocalPos(spawnCard, { -4 - 1.78 * UpNum, 0, 0 })
        end
        spawnCard.setPosition(finalPos)
        shipIndex = shipIndex + 1
    end

    finalPos = LocalPos(spawnCard, { 0, 0, 5.5 })
    spawnCard.setPosition(finalPos)

    for i, remote in pairs(listTable.Remotes or {}) do
        print("Spawning remote:" .. remote)
        for k, acc in ipairs(listaAcc) do
            if acc.name == remote then
                pos = LocalPos(spawnCard, { 1, 1, 0 })
                print("Found remote, spawning pos: " .. tostring(pos[1]) .. "," ..
                    tostring(pos[2]) .. "," .. tostring(pos[3]))
                remObj = tempBagAcc.takeObject({ rotation = spawnCard.getRotation(), guid = acc.guid, smooth = false })
                remoteClone = remObj.clone()
                remoteClone.setPosition(pos)
                tempBagAcc.putObject(remObj)
                finalpos = LocalPos(spawnCard, { -3, 0, 0 })
                spawnCard.setPosition(finalpos)
                break
            end
        end
    end

    -- Delete cloned bags
    tempBagAcc.destruct()
    for k, token in pairs(tokens) do
        token.destruct()
    end

    if listTable.Obstacles ~= nil then
        tempObstacleBag = getObjectFromGUID(Obstacle_Bag_GUID).clone({ position = PosBag3 }) -- Obstacles bag
        obstacleAcc = tempObstacleBag.getObjects()
        for i, obstacleName in ipairs(listTable.Obstacles) do
            local found = false
            for j, obstacle in ipairs(obstacleAcc) do
                if obstacle.name == obstacleName then
                    print("Found obstacle: " .. obstacle.name .. " - " .. obstacleName)
                    pos = LocalPos(spawnCard, { 0, 1, 0 })
                    obstacleToken = tempObstacleBag.takeObject({
                        rotation = spawnCard.getRotation(),
                        guid = obstacle.guid,
                        smooth = false
                    })
                    obstacleClone = obstacleToken.clone()
                    obstacleClone.setPosition(pos)
                    tempObstacleBag.putObject(obstacleToken)
                    found = true
                    break
                end
            end
            if not found then
                print("Couldnt find obstacle: " .. obstacleName)
            else
                finalPos = LocalPos(spawnCard, { -4, 0, 0 })
                spawnCard.setPosition(finalPos)
            end
        end
        tempObstacleBag.destruct()
    end

    --returns Quick Build Card to initial position
    spawnCard.setPosition(storePos)
    spawnCard.setRotation(storeRot)
end

function RotMatrix(axis, angDeg)
    local ang = math.rad(angDeg)
    local cs = math.cos
    local sn = math.sin

    if axis == 'x' then
        return {
            { 1, 0,       0 },
            { 0, cs(ang), -1 * sn(ang) },
            { 0, sn(ang), cs(ang) }
        }
    elseif axis == 'y' then
        return {
            { cs(ang),      0, sn(ang) },
            { 0,            1, 0 },
            { -1 * sn(ang), 0, cs(ang) }
        }
    elseif axis == 'z' then
        return {
            { cs(ang), -1 * sn(ang), 0 },
            { sn(ang), cs(ang),      0 },
            { 0,       0,            1 }
        }
    end
end

-- Apply given rotation matrix on given vector
-- (multiply matrix and column vector)
function RotateVector(rotMat, vect)
    local out = { 0, 0, 0 }
    for i = 1, 3, 1 do
        for j = 1, 3, 1 do
            out[i] = out[i] + rotMat[i][j] * vect[j]
        end
    end
    return out
end

--Decker module

do
    Decker = {}

    -- provide unique ID starting from 20 for present decks
    local nextID = nil
    do
        local _nextID = 20
        nextID = function()
            _nextID = _nextID + 1
            return tostring(_nextID)
        end
    end

    -- Asset signature (equality comparison)
    local function assetSignature(assetData)
        return table.concat({
            assetData.FaceURL,
            assetData.BackURL,
            assetData.NumWidth,
            assetData.NumHeight,
            assetData.BackIsHidden and 'hb' or '',
            assetData.UniqueBack and 'ub' or ''
        })
    end
    -- Asset ID storage to avoid new ones for identical assets
    local idLookup = {}
    local function assetID(assetData)
        local sig = assetSignature(assetData)
        local key = idLookup[sig]
        if not key then
            key = nextID()
            idLookup[sig] = key
        end
        return key
    end

    local assetMeta = {
        deck = function(self, cardNum, options)
            return Decker.AssetDeck(self, cardNum, options)
        end
    }
    assetMeta = { __index = assetMeta }

    -- Create a new CustomDeck asset
    function Decker.Asset(face, back, options)
        local asset = {}
        options = options or {}
        asset.data = {
            FaceURL = face or error('Decker.Asset: faceImg link required'),
            BackURL = back or error('Decker.Asset: backImg link required'),
            NumWidth = options.width or 1,
            NumHeight = options.height or 1,
            BackIsHidden = options.hiddenBack or false,
            UniqueBack = options.uniqueBack or false
        }
        -- Reuse ID if asset existing
        asset.id = assetID(asset.data)
        return setmetatable(asset, assetMeta)
    end

    function Decker.AssetFromData(assetData)
        return setmetatable({ data = assetData, id = assetID(assetData) }, assetMeta)
    end

    -- Create a base for JSON objects
    function Decker.BaseObject()
        return {
            Name = 'Base',
            Transform = {
                posX = 0,
                posY = 5,
                posZ = 0,
                rotX = 0,
                rotY = 0,
                rotZ = 0,
                scaleX = 1,
                scaleY = 1,
                scaleZ = 1
            },
            Nickname = '',
            Description = '',
            ColorDiffuse = { r = 1, g = 1, b = 1 },
            Locked = false,
            Grid = true,
            Snap = true,
            Autoraise = true,
            Sticky = true,
            Tooltip = true,
            GridProjection = false,
            Hands = false,
            XmlUI = '',
            LuaScript = '',
            LuaScriptState = '',
            GUID = 'deadbf'
        }
    end

    -- Apply some basic parameters on base JSON object
    function Decker.SetCommonOptions(obj, options)
        options = options or {}
        obj.Nickname = options.name or ''
        obj.Description = options.desc or ''
        obj.LuaScript = options.script or ''
        obj.XmlUI = options.xmlui or ''
        obj.LuaScriptState = options.scriptState or ''
        obj.Locked = options.locked or false
        obj.Tooltip = options.tooltip or true
        obj.GUID = options.guid or 'deadbf'
    end

    -- default spawnObjectJSON params since it doesn't like blank fields
    local function defaultParams(params, json)
        params = params or {}
        params.json = json
        params.position = params.position or { 0, 5, 0 }
        params.rotation = params.rotation or { 0, 0, 0 }
        params.scale = params.scale or { 1, 1, 1 }
        if params.sound == nil then
            params.sound = true
        end
        return params
    end

    -- For copy method
    local deepcopy = nil
    deepcopy = function(t)
        local copy = {}
        for k, v in pairs(t) do
            if type(v) == 'table' then
                copy[k] = deepcopy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
    -- meta for all Decker derived objects
    local commonMeta = {
        -- return object JSON string, used cached if present
        _cache = function(self)
            if not self.json then
                self.json = JSON.encode(self.data)
            end
            return self.json
        end,
        -- invalidate JSON string cache
        _recache = function(self)
            self.json = nil
            return self
        end,
        spawn = function(self, params)
            params = defaultParams(params, self:_cache())
            return spawnObjectJSON(params)
        end,
        copy = function(self)
            return setmetatable(deepcopy(self), getmetatable(self))
        end,
        setCommon = function(self, options)
            Decker.SetCommonOptions(self.data, options)
            return self
        end,
    }
    -- apply common part on a specific metatable
    local function customMeta(mt)
        for k, v in pairs(commonMeta) do
            mt[k] = v
        end
        mt.__index = mt
        return mt
    end

    -- DeckerCard metatable
    local cardMeta = {
        setAsset = function(self, asset)
            local cardIndex = self.data.CardID:sub(-2, -1)
            self.data.CardID = asset.id .. cardIndex
            self.data.CustomDeck = { [asset.id] = asset.data }
            return self:_recache()
        end,
        getAsset = function(self)
            local deckID = next(self.data.CustomDeck)
            return Decker.AssetFromData(self.data.CustomDeck[deckID])
        end,
        -- reset deck ID to a consistent value script-wise
        _recheckDeckID = function(self)
            local oldID = next(self.data.CustomDeck)
            local correctID = assetID(self.data.CustomDeck[oldID])
            if oldID ~= correctID then
                local cardIndex = self.data.CardID:sub(-2, -1)
                self.data.CardID = correctID .. cardIndex
                self.data.CustomDeck[correctID] = self.data.CustomDeck[oldID]
                self.data.CustomDeck[oldID] = nil
            end
            return self
        end
    }
    cardMeta = customMeta(cardMeta)
    -- Create a DeckerCard from an asset
    function Decker.Card(asset, row, col, options)
        options = options or {}
        local card = Decker.BaseObject()
        card.Name = 'Card'
        -- optional custom fields
        Decker.SetCommonOptions(card, options)
        if options.sideways ~= nil then
            card.SidewaysCard = options.sideways
        end
        -- CardID string is parent deck ID concat with its 0-based index (always two digits)
        local num = (row - 1) * asset.data.NumWidth + col - 1
        num = string.format('%02d', num)
        card.CardID = asset.id .. num
        -- just the parent asset reference needed
        card.CustomDeck = { [asset.id] = asset.data }

        local obj = setmetatable({ data = card }, cardMeta)
        obj:_cache()
        return obj
    end

    -- DeckerDeck meta
    local deckMeta = {
        count = function(self)
            return #self.data.DeckIDs
        end,
        -- Transform index into positive
        index = function(self, ind)
            if ind < 0 then
                return self:count() + ind + 1
            else
                return ind
            end
        end,
        swap = function(self, i1, i2)
            local ri1, ri2 = self:index(i1), self:index(i2)
            assert(ri1 > 0 and ri1 <= self:count(), 'DeckObj.rearrange: index ' .. i1 .. ' out of bounds')
            assert(ri2 > 0 and ri2 <= self:count(), 'DeckObj.rearrange: index ' .. i2 .. ' out of bounds')
            self.data.DeckIDs[ri1], self.data.DeckIDs[ri2] = self.data.DeckIDs[ri2], self.data.DeckIDs[ri1]
            local co = self.data.ContainedObjects
            co[ri1], co[ri2] = co[ri2], co[ri1]
            return self:_recache()
        end,
        -- rebuild self.data.CustomDeck based on contained cards
        _rescanDeckIDs = function(self, id)
            local cardIDs = {}
            for k, card in ipairs(self.data.ContainedObjects) do
                local cardID = next(card.CustomDeck)
                if not cardIDs[cardID] then
                    cardIDs[cardID] = card.CustomDeck[cardID]
                end
            end
            --[[
            for id,data in pairs(cardIDs) do
                self.data.CustomDeck[id] = data
            end
            for id,data in pairs(self.data.CustomDeck) do
                if not cardIDs[id] then
                    self.data.CustomDeck[id] = nil
                end
            end
            ]]
            --
            -- eeh, GC gotta earn its keep as well
            self.data.CustomDeck = cardIDs
        end,
        remove = function(self, ind, skipRescan)
            local rind = self:index(ind)
            assert(rind > 0 and rind <= self:count(), 'DeckObj.remove: index ' .. ind .. ' out of bounds')
            local card = self.data.ContainedObjects[rind]
            table.remove(self.data.DeckIDs, rind)
            table.remove(self.data.ContainedObjects, rind)
            if not skipRescan then
                self:_rescanDeckIDs(next(card.CustomDeck))
            end
            return self:_recache()
        end,
        removeMany = function(self, ...)
            local indices = { ... }
            table.sort(indices, function(e1, e2)
                return self:index(e1) > self:index(e2)
            end)
            for _, ind in ipairs(indices) do
                self:remove(ind, true)
            end
            self:_rescanDeckIDs()
            return self:_recache()
        end,
        insert = function(self, card, ind)
            local rind = self:index(ind)
            assert(rind > 0 and rind <= (self:count() + 1), 'DeckObj.insert: index ' .. ind .. ' out of bounds')
            table.insert(self.data.DeckIDs, rind, card.data.CardID)
            table.insert(self.data.ContainedObjects, rind, card.data)
            local id = next(card.data.CustomDeck)
            if not self.data.CustomDeck[id] then
                self.data.CustomDeck[id] = card.data.CustomDeck[id]
            end
            return self:_recache()
        end,
        reverse = function(self)
            local s, e = 1, self:count()
            while s < e do
                self:swap(s, e)
                s = s + 1
                e = e - 1
            end
            return self:_recache()
        end,
        cardAt = function(self, ind)
            local rind = self:index(ind)
            assert(rind > 0 and rind <= (self:count() + 1), 'DeckObj.insert: index ' .. ind .. ' out of bounds')
            local card = setmetatable({ data = deepcopy(self.data.ContainedObjects[rind]) }, cardMeta)
            card:_cache()
            return card
        end,
        switchAssets = function(self, replaceTable)
            -- destructure replace table into
            -- [ID_to_replace] -> [ID_to_replace_with]
            -- [new_asset_ID] -> [new_asset_data]
            local idReplace = {}
            local assets = {}
            for oldAsset, newAsset in pairs(replaceTable) do
                assets[newAsset.id] = newAsset.data
                idReplace[oldAsset.id] = newAsset.id
            end
            -- update deckIDs
            for k, cardID in ipairs(self.data.DeckIDs) do
                local deckID, cardInd = cardID:sub(1, -3), cardID:sub(-2, -1)
                if idReplace[deckID] then
                    self.data.DeckIDs[k] = idReplace[deckID] .. cardInd
                end
            end
            -- update CustomDeck data - nil replaced
            for replacedID in pairs(idReplace) do
                if self.data.CustomDeck[replacedID] then
                    self.data.CustomDeck[replacedID] = nil
                end
            end
            -- update CustomDeck data - add replacing
            for _, replacingID in pairs(idReplace) do
                self.data.CustomDeck[replacingID] = assets[replacingID]
            end
            -- update card data
            for k, cardData in ipairs(self.data.ContainedObjects) do
                local deckID = next(cardData.CustomDeck)
                if idReplace[deckID] then
                    cardData.CustomDeck[deckID] = nil
                    cardData.CustomDeck[idReplace[deckID]] = assets[idReplace[deckID]]
                end
            end
            return self:_recache()
        end,
        getAssets = function(self)
            local assets = {}
            for id, assetData in pairs(self.data.CustomDeck) do
                assets[#assets + 1] = Decker.AssetFromData(assetData)
            end
            return assets
        end
    }
    deckMeta = customMeta(deckMeta)
    -- Create DeckerDeck object from DeckerCards
    function Decker.Deck(cards, options)
        local deck = Decker.BaseObject()
        deck.Name = 'Deck'
        Decker.SetCommonOptions(deck, options)
        deck.DeckIDs = {}
        deck.CustomDeck = {}
        deck.ContainedObjects = {}
        for _, card in ipairs(cards) do
            deck.DeckIDs[#deck.DeckIDs + 1] = card.data.CardID
            local id = next(card.data.CustomDeck)
            if not deck.CustomDeck[id] then
                deck.CustomDeck[id] = card.data.CustomDeck[id]
            end
            deck.ContainedObjects[#deck.ContainedObjects + 1] = card.data
        end

        local obj = setmetatable({ data = deck }, deckMeta)
        obj:_cache()
        return obj
    end

    -- Create DeckerDeck from an asset using X cards on its sheet
    function Decker.AssetDeck(asset, cardNum, options)
        cardNum = cardNum or asset.data.NumWidth * asset.data.NumHeight
        local row, col, width = 1, 1, asset.data.NumWidth
        local cards = {}
        for k = 1, cardNum do
            cards[#cards + 1] = Decker.Card(asset, row, col)
            col = col + 1
            if col > width then
                row, col = row + 1, 1
            end
        end
        return Decker.Deck(cards, options)
    end
end

-- for use with Epic Wing Tool to check if the landing space is empty
function epicMoveWingmate(table)
    local ship = table[1]
    local desiredPosRot = { pos = table[2], rot = table[3] }
    print("Ship size=" .. ship.getTable("Data").Size)
    local info = { size = ship.getTable("Data").Size, code = "dummy", type = "" }
    local fullFunc = function(info, ship)
        return desiredPosRot
    end
    result = MoveModule.MoveProbe.TryFullMove(info, ship, fullFunc)
    if result.done then
        MoveModule.MoveShip(ship, { finPos = desiredPosRot })
        MoveModule.CheckMineAndObstacleCollisions(ship, desiredPosRot, true, nil)
        return true
    else
        -- Todo announce some stuff
        return false
    end
end

---------------------
-- START EZ-TEMPLATES
local ezTemplates = {}

function ezTemplates.Maneuver(object)
    function direction(object, bearing)
        if bearing == 'straight' then
            return nil
        end

        if object.is_face_down then
            return 'left'
        else
            return 'right'
        end
    end

    local name = object.getName():lower()
    local bearing, speed = string.match(name, "^(%a+) (%d)$")
    return tonumber(speed), bearing, direction(object, bearing)
end

function ezTemplates.IsEasyTemplate(object)
    if not object then return false end
    local name = object.getName():lower()
    if not (string.match(name, "^straight %d+$")
            or string.match(name, "^bank %d+$")
            or string.match(name, "^turn %d+$")) then
        return false
    end

    local function ezTemplatesEnabled()
        local s1Bag = getObjectFromGUID(Straight_1_Bag_GUID)
        return s1Bag and s1Bag.hasTag('ezTemplates') or false
    end
    local speed, bearing, direction = ezTemplates.Maneuver(object)
    local enabled = ezTemplatesEnabled()
    return enabled and bearing ~= nil and speed ~= nil
end

function ezTemplates.SnapToShip(player_color, template)
    local ship = FindNearestShip(template, 40, IsInFrontOfShip)
    if ship == nil then
        return
    end

    local speed, bearing, direction = ezTemplates.Maneuver(template)
    local position = 'front' -- For now, just spawn out the front
    destroyObject(template)
    template = DialModule.PlaceTemplate(ship, speed, bearing, position, direction, nil)

    function alignButtonWithShip(template, ship)
        -- Get world rotations
        local shipRot = ship.getRotation()
        local templateRot = template.getRotation()

        -- Calculate relative rotation
        local relativeRot = {
            x = shipRot.x - templateRot.x,
            y = shipRot.y - templateRot.y,
            z = shipRot.z - templateRot.z,
        }

        return relativeRot
    end

    local buttonRot = alignButtonWithShip(template, ship)

    local removeButton = {
        -- click_function = 'deleteObject',
        click_function = 'destroyObject',
        label = 'Del',
        position = { 0, 0.05, 0 },
        rotation = buttonRot,
        width = 180,
        height = 125,
        font_size = 100,
        font_color = { 225 / 255, 225 / 255, 225 / 255 },
        color = { 17 / 255, 16 / 255, 15 / 255 },
        tooltip = "Remove the template"
    }
    template.createButton(removeButton)
end

function ezTemplates.onObjectDropped(player_color, template)
    if not ezTemplates.IsEasyTemplate(template) then
        return
    end

    ezTemplates.SnapToShip(player_color, template)
end

EventSub.Register('onObjectDropped', ezTemplates.onObjectDropped)

-- END EZ-TEMPLATES
-------------------

function IsInFrontOfShip(object, ship)
    -- Get the positions of the object and the ship
    local objPos = object.getPosition()
    local shipPos = ship.getPosition()

    -- Calculate the forward direction vector of the ship
    local shipForward = ship.getTransformForward()

    -- Calculate the vector from the ship to the object
    local toObject = {
        x = shipPos.x - objPos.x,
        y = shipPos.y - objPos.y,
        z = shipPos.z - objPos.z
    }

    -- Convert to a normalized vector (direction only)
    local toObjectNormalized = Vector(toObject):normalize()

    -- Calculate the dot product between the forward vector and the toObject vector
    local dotProduct = shipForward.x * toObjectNormalized.x +
        shipForward.y * toObjectNormalized.y +
        shipForward.z * toObjectNormalized.z

    -- Check if the object is in front (dotProduct > 0) and within a reasonable margin
    return dotProduct > 0.01 -- Adjust the threshold for precision if needed
end

function FindNearestShip(object, max_distance, filter_function)
    filter_function = filter_function or function(obj, ship) return true end

    local min_dist = Dim.Convert_mm_igu(max_distance or 100) -- default 100 mm
    local objPos = object.getPosition():setAt('y', 0)
    local nearest = nil

    for _, ship in pairs(getObjects()) do
        if MoveModule.SelectShips(ship) then
            local shipPos = ship.getPosition():setAt('y', 0)
            local dist = shipPos:distance(objPos)
            if dist < min_dist and filter_function(object, ship) then
                nearest = ship
                min_dist = dist
            end
        end
    end

    return nearest
end

end)
__bundle_register("API", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_xwing
--
-- All cross-script-callable functions
-- ~~~~~~

-- "API" functions, to be working in TTS:
-- Must take one and only one argument, of table type
-- Must return one and only one value
-- Cannot receive/return function or thread type values
-- Have to be called after callee loads (its onLoad triggers)


-- Perform a move using a standard move command
-- Argument: { code = moveCode, ship = shipReference, ignoreCollisions = [true/false] }
-- Return: TRUE if move completed, FALSE if overlap prevented ship from moving
-- Return:                         FALSE if invalid (non-move) command or ship not ready
function API_PerformMove(argTable)
    local type = XW_cmd.CheckCommand(argTable.code)
    if (type ~= 'move' and type ~= 'actionMove') or not XW_cmd.isReady(argTable.ship) then
        return false
    end
    return MoveModule.PerformMove(argTable.code, argTable.ship, argTable.ignoreCollisions)
end

function API_Relocate(argTable)
    Relocator:execute(argTable.ship, argTable.moveType)
end

-- Queue tokens near a ship for movement
-- To be called immediately before changing position of a ship
-- Argument: { ship = shipRef, finPos = { pos = finalPosition, rot = finalRotation} }
-- finPos field may be nil (no position set after wait then)
function API_QueueShipTokensMove(argTable)
    -- Set the ship busy if it's not to try prevent double ready later
    if XW_cmd.isReady(argTable.ship) then
        XW_cmd.SetBusy(argTable.ship)
    end
    local lockFun = nil
    if argTable.noLock == true then
        lockFun = function(ship)
            ship.unlock()
        end
    end
    TokenModule.QueueShipTokensMove(argTable.ship)
    MoveModule.WaitForResting(argTable.ship, argTable.finPos, lockFun)
end

-- Indicate dropping of a bomb token from outside Global
-- Argument: { token = droppedTokenRef }
-- Return: true if token snapped, false otherwise
function API_BombTokenDrop(argTable)
    return BombModule.OnTokenDrop(argTable.token)
end

function API_MineDrop(argTable)
    BombModule.CheckMineDroppedOverlapping(argTable.mine, argTable.ship)
end

function API_IsShipType(argTable)
    return ObjType.IsOfType(argTable.ship, 'ship')
end

function API_AssignToken(argTable)
    TokenModule.AssignToken(argTable.token, argTable.ship)
end

function API_RemoveTokenOnFlip(argTable)
    TokenModule.removeOnFlip(argTable.object, argTable.player)
end

function API_GetPlayerConfig(argTable)
    return ConfigManager.GetConfig(argTable.player_color, argTable.param_name)
end

function API_GetGlobalConfig(argTable)
    return ConfigManager.GetConfig("global", argTable.param_name)
end

function API_SetPlayerConfig(argTable)
    return ConfigManager.SetConfig(argTable.player_color, argTable.param_name, argTable.value)
end

function API_SetGlobalConfig(argTable)
    return ConfigManager.SetConfig("global", argTable.param_name, argTable.value)
end

function API_SpawnTemplate(args)
    return DialModule.SpawnTemplate(args.ship, args.dialCode)
end

function API_FindNearestShip(args)
    return FindNearestShip(args.object, args.max_distance, args.filter_function)
end

function API_GetClosestPointToShip(argTable)
    local size = argTable.ship.getTable('Data').Size or "small"
    local segments = ArcCheck.GetOwnArcLineSegments(argTable.ship, ArcCheck.arc_line_segments[size].full.segments)

    local closestRange = 100000
    local closestDistance = nil
    for _, segment in pairs(segments) do
        distance = ArcCheck.GetDistanceBetweenLineSegmentAndPoint(segment, argTable.point, false)
        --print("Dist: " .. tostring(distance.length))
        if distance.length < closestRange then
            closestRange = distance.length
            closestDistance = distance
        end
    end
    return closestDistance
end

function API_AssignDial(argTable)
    DialManagerModule.assignDial(argTable.dial, argTable.ship, argTable.player)
end

function API_SetDial(argTable)
    if argTable.set then
        DialManagerModule.setDial(argTable.dial)
    else
        DialManagerModule.unSetDial(argTable.dial)
    end
end

function API_IsAllDialsSet(argTable)
    return DialManagerModule.isAllDialsSet(argTable.player)
end

function API_ClearPosition(argTable)
    TokenModule.ClearPosition(argTable.pos, argTable.reach, argTable.ship)
end

function API_GetTokenSize()
    return TokenModule.tokenSize
end

function API_SetTokenSize(argTable)
    TokenModule.tokenSize = argTable.size
end

function API_StreamAnnounce(argTable)
    StreamManagerModule.Announce(argTable.text, argTable.player)
end

function API_ToggleAnnouncement(argTable)
    StreamManagerModule.Announce(argTable.text, argTable.player)
end

function API_XWcmd_isReady(argTable)
    local ship = argTable.ship

    return ship.resting and ship.getDescription() == "" and XW_cmd.isReady(ship)
end

--------
-- OBJECT SPECIFIC VARIABLES
-- These variables are set per object and have some specific meaning
-- Some may be linked to another so caution must be kept when modifying

-- objectType : varName         - val / val2 ... / valN     <- meaning
-- ship : 'hasDials'            - true / (false/nil)        <- Has assigned set of dials (ONLY informative) / Not
-- ship : 'slideOngoing'        - true / (false/nil)        <- Is in process of manually adjusting slide / Not
-- ship : 'cmdBusy'             - true / (false/nil)        <- Is currently processing some command / Not
-- ship : 'missingModelWarned'  - true / (false/nil)        <- Printed a warning that model is unrecognized (once) / Not yet
-- dial : 'slideOngoing'        - true / (false/nil)        <- Its ship in process of manually adjusting slide / Not
-- dial : 'assignedShip'        - shipRef / nil             <- Object reference to its owner / No owner
-- token : 'idle'               - false / (true/nil)        <- This token should be ignored when moving tokens / Not

--------

end)
__bundle_register("Game.Mechanic.Movement.Maneuver", function(require, _LOADED, __bundle_register, __bundle_modules)
local Dim = require("Dim")

local igu = Dim.Convert_mm_igu
-- TODO: add reverse move, and reverse bank

-----------------------------
-- Strategy Design Pattern --
-----------------------------

-- Base MovementStrategy class
local ManeuverStrategy = {}
ManeuverStrategy.__index = ManeuverStrategy

function ManeuverStrategy:new()
    return setmetatable({}, self)
end

function ManeuverStrategy:execute(ship)
    -- To be overridden by subclasses
end

function ManeuverStrategy:getBaseSize(ship)
    local shipData = ship.getTable("Data")
    local size = shipData.Size or "small"
    if type(size) == "string" then
        return igu(Dim.mm_baseSize[size])
    elseif type(size) == "number" then
        return igu(size) -- Assuming the size is provided in mm
    else
        error("Invalid size type")
    end
end

--[[
    If the forward Vector of the object doesn't line up with the object
    visually, you can attach an angle value here to correct the forward vector
    by rotating it around the y-axis by the provided angle in degrees.
    This will correct an object's forward vector to move it properly.
    [+ is clockwise, - is counter-clockwise]
 ]]
function ManeuverStrategy:getForwardVector(ship)
    local shipData = ship.getTable("Data")
    local forwardAdjustment = shipData.forwardAdjustment or 0
    local forward = ship.getTransformForward():copy()
    forward = forward:rotateOver("y", forwardAdjustment)
    return forward:normalized()
end

-- StraightMove class inherits from MovementStrategy
local Straight = setmetatable({}, { __index = ManeuverStrategy })
Straight.__index = Straight

function Straight:new(speed, rotation)
    local instance = ManeuverStrategy:new()
    instance.speed = igu(Dim.XWingTemplates.straight[speed])
    instance.rotation = rotation or 0
    return setmetatable(instance, self)
end

function Straight:execute(ship)
    local forward = self:getForwardVector(ship)
    local baseSize = self:getBaseSize(ship)
    local posDelta = (self.speed + baseSize) * forward
    local newPos = ship.getPosition() + posDelta
    local newRot = ship.getRotation() + Vector(0, self.rotation, 0)
    ship.setPositionSmooth(newPos, false, true)
    ship.setRotationSmooth(newRot, false, false)
end

-- KoiogranTurn class inherits from StraightMove
local KoiogranTurn = setmetatable({}, { __index = Straight })
KoiogranTurn.__index = KoiogranTurn

function KoiogranTurn:new(speed)
    local instance = Straight:new(speed, 180)
    return setmetatable(instance, self)
end

function KoiogranTurn:execute(ship)
    Straight.execute(self, ship)
end

-- Moves along a curved template
local ArcMove = setmetatable({}, { __index = ManeuverStrategy })
ArcMove.__index = ArcMove

function ArcMove:new(radius, angle, bearing, extraRot)
    local instance = ManeuverStrategy:new()
    instance.radius = igu(radius)
    instance.angle = angle
    instance.bearing = bearing or "right" -- Default to right if no bearing is provided
    instance.extraRotation = extraRot or 0
    return setmetatable(instance, self)
end

function ArcMove:execute(ship)
    local sign = (self.bearing == "right" and 1) or -1 -- + is clockwise, - is counter-clockwise
    local turnAngle = sign * self.angle
    local rotAngle = sign * (self.angle + self.extraRotation)

    -- Get ship's forward vector and base size
    local forward = self:getForwardVector(ship)
    local baseSize = self:getBaseSize(ship)

    -- Step 1: Initial straight move by half the base size
    local initialPos = ship.getPosition() + (baseSize / 2) * forward

    -- Recalculate arcCenter based on the new position
    local turnDirection = sign * forward:copy():rotateOver("y", 90):normalized()
    local arcCenter = initialPos + turnDirection * self.radius

    -- Step 2: Arc move
    local newPos = arcCenter + (initialPos - arcCenter):rotateOver("y", turnAngle)

    -- Step 3: Final straight move by half the base size
    newPos = newPos + (baseSize / 2) * forward:rotateOver("y", turnAngle):normalized()

    -- Determine new rotation
    local newRot = ship.getRotation() + Vector(0, rotAngle, 0)

    -- Update ship position and rotation smoothly
    ship.setPositionSmooth(newPos, false, false)
    ship.setRotationSmooth(newRot, false, false)
end

-- TurnMove class inherits from ArcMove
local TurnMove = setmetatable({}, { __index = ArcMove })
TurnMove.__index = TurnMove

function TurnMove:new(speed, bearing)
    return setmetatable(ArcMove:new(Dim.XWingTemplates.turn[speed], 90, bearing), self)
end

-- BankMove class inherits from ArcMove
local BankMove = setmetatable({}, { __index = ArcMove })
BankMove.__index = BankMove

function BankMove:new(speed, bearing)
    return setmetatable(ArcMove:new(Dim.XWingTemplates.bank[speed], 45, bearing), self)
end

-- SegnorLoop class inherits from ArcMove
local SegnorLoop = setmetatable({}, { __index = ArcMove })
SegnorLoop.__index = SegnorLoop

function SegnorLoop:new(speed, bearing)
    local instance = ArcMove:new(Dim.XWingTemplates.bank[speed], 45, bearing, 180) -- Using 45 degrees as the bank angle
    return setmetatable(instance, self)
end

-- TallonRoll class inherits from ArcMove
local TallonRoll = setmetatable({}, { __index = ArcMove })
TallonRoll.__index = TallonRoll

function TallonRoll:new(speed, bearing)
    local instance = ArcMove:new(Dim.XWingTemplates.turn[speed], 90, bearing, 90)
    return setmetatable(instance, self)
end

-- Main Movement class
local Maneuver = {}
Maneuver.__index = Maneuver

-- Define the moveStrategies table once, outside of the constructor
Maneuver.maneuverTemplates = {
    -- Straight Maneuvers
    s1 = Straight:new(1),
    s2 = Straight:new(2),
    s3 = Straight:new(3),
    s4 = Straight:new(4),
    s5 = Straight:new(5),

    -- Koiogran Turn (Straight Move with a 180º Rotation Maneuver)
    k1 = KoiogranTurn:new(1),
    k2 = KoiogranTurn:new(2),
    k3 = KoiogranTurn:new(3),
    k4 = KoiogranTurn:new(4),
    k5 = KoiogranTurn:new(5),

    -- Turn (90º Turn Maneuver)
    tr1 = TurnMove:new(1, "right"),
    tr2 = TurnMove:new(2, "right"),
    tr3 = TurnMove:new(3, "right"),

    tl1 = TurnMove:new(1, "left"),
    tl2 = TurnMove:new(2, "left"),
    tl3 = TurnMove:new(3, "left"),

    -- Bank (45º Turn Maneuver)
    br1 = BankMove:new(1, "right"),
    br2 = BankMove:new(2, "right"),
    br3 = BankMove:new(3, "right"),

    bl1 = BankMove:new(1, "left"),
    bl2 = BankMove:new(2, "left"),
    bl3 = BankMove:new(3, "left"),

    -- Segnor Loop (45º Turn with a 180º Rotation Maneuver)
    br1s = SegnorLoop:new(1, "right"),
    br2s = SegnorLoop:new(2, "right"),
    br3s = SegnorLoop:new(3, "right"),

    bl1s = SegnorLoop:new(1, "left"),
    bl2s = SegnorLoop:new(2, "left"),
    bl3s = SegnorLoop:new(3, "left"),

    -- Tallon Roll (90º Turn with a 90º Rotation Maneuver)
    tr1t = TallonRoll:new(1, "right"),
    tr2t = TallonRoll:new(2, "right"),
    tr3t = TallonRoll:new(3, "right"),

    tl1t = TallonRoll:new(1, "left"),
    tl2t = TallonRoll:new(2, "left"),
    tl3t = TallonRoll:new(3, "left"),
}

function Maneuver:new()
    return setmetatable({}, self)
end

function Maneuver:execute(ship, maneuverType)
    local maneuver = self.maneuverTemplates[maneuverType]
    if ship and maneuver then
        maneuver:execute(ship)
    else
        print("Invalid: ship: " .. tostring(ship) .. " with move type: " .. maneuverType)
    end
end

return Maneuver

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
__bundle_register("Player.Announcements", function(require, _LOADED, __bundle_register, __bundle_modules)
--------------------------
-- ANNOUNCEMENTS MODULE --
--------------------------

-- For writing out stuff in chat

local AnnModule = {
    announceColor = {
        -- color configuration for announcements
        moveClear = { 0.1, 1, 0.1 },     -- Green
        moveCollision = { 1, 0.7, 0.1 }, -- Orange
        action = { 0.3, 0.3, 1 },        -- Blue
        historyHandle = { 0.1, 1, 1 },   -- Cyan
        error = { 1, 0.15, 0.15 },       -- Red
        warn = { 1, 0.4, 0 },            -- Red-orange
        info = { 0.8, 0.1, 0.8 }         -- Purple
    },
    -- Record of players that already got note of some ID
    -- Key: playerSteamID
    -- Value: table of true's on keys of received noteIDs
    notifyRecord = {}
}

-- Notify color or all players of some event
-- announceInfo: {type=typeOfEvent, note=notificationString}
AnnModule.Announce = function(info, target, shipPrefix)
    local annString = ''
    local annColor = { 1, 1, 1 }
    local shipName = ''

    if shipPrefix ~= nil then
        if type(shipPrefix) == 'string' then
            shipName = shipPrefix .. ' '
        elseif type(shipPrefix) == 'userdata' then
            shipName = shipPrefix.getName() .. ' '
        end
    end
    if info.type == 'move' or info.type == 'stationary' then
        if info.collidedShip == nil then
            annString = shipName .. info.note .. ' (' .. info.code .. ')'
            annColor = AnnModule.announceColor.moveClear
        else
            local coltype = nil
            if info.friendlyCollission then
                coltype = "[ff2222]friendly[ffb219]"
            else
                coltype = "[2222ff]only enemy[ffb219]"
            end
            annString = shipName ..
                info.note ..
                ' (' ..
                info.code ..
                ') but it ended overlapping ' ..
                coltype .. ' ship(s) and is now touching ' .. info.collidedShip.getName()
            annColor = AnnModule.announceColor.moveCollision
        end
    elseif info.type == 'overlap' then
        annString = shipName .. info.note .. ' (' .. info.code .. ') but there was no space to complete the move'
        annColor = AnnModule.announceColor.moveCollision
    elseif info.type == 'historyHandle' then
        annString = shipName .. info.note
        annColor = AnnModule.announceColor.historyHandle
    elseif info.type == 'action' then
        annString = shipName .. info.note
        annColor = AnnModule.announceColor.action
    elseif info.type:find('error') ~= nil then
        annString = shipName .. info.note
        annColor = AnnModule.announceColor.error
    elseif info.type:find('warn') ~= nil then
        annString = shipName .. info.note
        annColor = AnnModule.announceColor.warn
    elseif info.type:find('info') ~= nil then
        annString = shipName .. info.note
        annColor = AnnModule.announceColor.info
    end

    if target == 'all' then
        printToAll(annString, annColor)
    else
        printToColor(target, annString, annColor)
    end
end


-- Print note to playerColor
-- Any further calls with same noteID will not notify same player
-- Print to everyone if playerColor is 'all'
AnnModule.NotifyOnce = function(note, noteID, playerColor)
    if playerColor == 'all' then
        local seatedPlayers = getSeatedPlayers()
        for _, color in pairs(seatedPlayers) do
            AnnModule.NotifyOnce(note, noteID, color)
        end
    else
        local steamID = Player[playerColor].steam_id
        if AnnModule.notifyRecord[steamID] == nil then
            AnnModule.notifyRecord[steamID] = {}
        end
        if AnnModule.notifyRecord[steamID][noteID] ~= true then
            broadcastToColor(note, playerColor, AnnModule.announceColor.info)
            AnnModule.notifyRecord[steamID][noteID] = true
        end
    end
end

return AnnModule

end)
__bundle_register("Game.Mechanic.Movement.MoveData", function(require, _LOADED, __bundle_register, __bundle_modules)
--------
-- MOVEMENT DATA MODULE
-- Stores and processes data about moves
-- NOT aware of any ship position, operation solely on relative movements
-- Used for feeding data about a move to a higher level movement module
-- Exclusively uses millimeters and degrees for values, needs external conversion

local EventSub = require("TTS_Lib.EventSub.EventSub")
local Vect = require("TTS_lib.Vector.Vector")

local Dim = require("Dim")

MoveData = {}

-- Lookup table for most of the moves
-- Generated using Matlab, source: https://github.com/tjakubo2/xwing_traj
-- Stored on another object to reduce clutter, passed on load
MoveData.LUT = {}
MoveData.onLoad = function()
    for _, obj in pairs(getAllObjects()) do
        if obj.getName() == 'MoveLUT' then
            MoveData.LUT.Parse(obj)
        end
    end
end
EventSub.Register('onLoad', MoveData.onLoad)
MoveData.LUT.Parse = function(object)
    MoveData.LUT.Data = object.call('ParseLUT', {})
end

-- Max part value for partial moves
-- Part equal to this is a full move
-- Value is largely irrelevant since part can be a fraction (any kind of number really)
MoveData.partMax = 1000

-- Construct data from a lookup table entry
-- Move info provided from MoveData.DecodeInfo
-- Return format: {xPos_offset, yPos_offset, zPos_offset, yRot_offset}
-- Linear interpolation between points in lookup table
--
-- Only returns data for RIGHT direction move (if applies)
-- Doesn't take any segnor, talon versions etc into considerations
-- Above things are considered MODIFIERS with functions to apply them defined further
MoveData.LUT.ConstructData = function(moveInfo, part)
    if part == nil then
        part = MoveData.partMax
    end
    if moveInfo.speed == 0 and moveInfo.type == 'straight' then
        return { 0, 0, 0, 0 }
    end
    part = math.clamp(part, 0, MoveData.partMax)
    local LUTtable = MoveData.LUT.Data[moveInfo.size .. 'Base'][moveInfo.type][moveInfo.speed]
    local LUTindex = (part / MoveData.partMax) * LUTtable.dataNum
    if LUTindex < 1 then LUTindex = 1 end
    -- Interpolation between two nearest indexes
    local aProp = LUTindex - math.floor(LUTindex)
    local bProp = 1 - aProp
    local outPos = Vect.Sum(Vect.Scale(LUTtable.posXZ[math.floor(LUTindex)], bProp),
        Vect.Scale(LUTtable.posXZ[math.ceil(LUTindex)], aProp))
    local outRot = (LUTtable.rotY[math.floor(LUTindex)] * bProp) + (LUTtable.rotY[math.ceil(LUTindex)] * aProp)

    local outData = { outPos[1], 0, outPos[2], outRot }
    return outData
end

-- Get true move length from LUT data *IN MILLIMETERS*
-- True as in trajectory length, not distance between start and end
-- (stored in LUT to reduce load here)
MoveData.MoveLength = function(moveInfo)
    if moveInfo.traits.part == false then
        return nil
    elseif moveInfo.speed == 0 then
        return 0
    else
        return MoveData.LUT.Data[moveInfo.size .. 'Base'][moveInfo.type][moveInfo.speed].length
    end
end

-- Convert an entry from milimeters to in-game units
MoveData.ConvertDataToIGU = function(entry)
    return { Dim.Convert_mm_igu(entry[1]), Dim.Convert_mm_igu(entry[2]), Dim.Convert_mm_igu(entry[3]), entry[4] }
end

-- Change an entry to a left-heading version
MoveData.LeftVariant = function(entry)
    return { -1 * entry[1], entry[2], entry[3], -1 * entry[4] }
end

-- Change an entry to be k-turn like (+180deg rot at the end)
MoveData.TurnAroundVariant = function(entry)
    return { entry[1], entry[2], entry[3], entry[4] + 180 }
end

-- Change an entry to be talon-roll like (+90deg INWARD rot at the end)
MoveData.TurnInwardVariant = function(entry)
    local dir = 0
    if entry[1] > 0 then
        dir = 90
    elseif entry[1] < 0 then
        dir = -90
    end
    return { entry[1], entry[2], entry[3], entry[4] + dir }
end

-- Change an entry to be reverse type
MoveData.ReverseVariant = function(entry)
    return { entry[1], entry[2], -1 * entry[3], -1 * entry[4] }
end

-- Rotate an entry by given degrees
-- Helps define rolls as straights rotated 90deg sideways etc
MoveData.RotateEntry = function(entry, angDeg)
    local rotEntry = Vect.RotateDeg(entry, angDeg)
    return { rotEntry[1], rotEntry[2], rotEntry[3], entry[4] + angDeg }
end

-- Apply move modifiers that happen even if move is partial
MoveData.ApplyBasicModifiers = function(entry, info)
    local out = table.shallowcopy(entry)
    if (info.type == 'turnSlip' or info.type == 'bankSlip') then
        if info.dir == 'right' then
            out = MoveData.LeftVariant(out)
        end
    elseif info.dir == 'left' then
        out = MoveData.LeftVariant(out)
    end
    if info.extra == 'reverse' then
        out = MoveData.ReverseVariant(out)
    end
    return out
end

-- Apply move modifiers that only happen if move is performed fully
MoveData.ApplyFinalModifiers = function(entry, info)
    local out = table.shallowcopy(entry)
    if info.extra == 'talon' then
        out = MoveData.TurnInwardVariant(out)
    elseif info.extra == 'koiogran' or info.extra == 'segnor' then
        out = MoveData.TurnAroundVariant(out)
    end
    return out
end


-- Decode a move command into table with type, direction, speed etc info
-- TODO make a lookup table?
MoveData.DecodeInfo = function(move_code, ship)
    local info = {
        -- [option1] [option2] ... [optionN]  // [errorOption]
        type = 'invalid', -- [straight] [bank] [turn] [roll] [viper] [cloak] [echo] [bankSlip] [ turnSlip]//  [invalid]
        speed = nil,      -- [1] [2] [3] [4] [5]  //  [nil]
        dir = nil,        -- [left] [right] [nil]
        extra = nil,      -- [koiogran] [segnor] [talon] [reverse] [straight] [forward] [backward] [nil]
        traits =
        {
            full = false, -- [true] [false] if this move can be attempted as a full move
            part = false  -- [true] [false] if this move can be attempted as a partial move
        },
        size = nil,       -- [small] [large]  //  [nil]
        note = nil,       -- [string] eg. 'banked xxx'       //  [nil]
        collNote = nil,   -- [string] eg. 'tried to do xxx'  //  [nil]
        code = move_code  -- [string] eg. 'be2'              //  [nil]
    }
    if ship ~= nil then
        info.size = ship.getTable("Data").Size or 'small'
    else
        info.size = 'small'
    end
    -- Straights and koiograns, regular stuff
    if move_code:sub(1, 1) == 's' or move_code:sub(1, 1) == 'k' then
        info.type = 'straight'
        info.speed = tonumber(move_code:sub(2, 2))
        info.traits.full = true
        info.traits.part = true
        if move_code:sub(1, 1) == 'k' then
            info.extra = 'koiogran'
            info.note = 'koiogran turned ' .. info.speed
            info.collNote = 'tried to koiogran turn ' .. info.speed
        elseif move_code:sub(-1, -1) == 'r' then
            info.extra = 'reverse'
            info.note = 'flew reverse ' .. info.speed
            info.collNote = 'tried to fly reverse ' .. info.speed
        elseif move_code:sub(-1, -1) == 'b' then
            info.traits.part = false
            local boostSpd = ''
            if info.speed > 1 then
                boostSpd = ' ' .. info.speed
            end
            info.note = 'boosted straight' .. boostSpd
            info.collNote = 'tried to boost straight' .. boostSpd
        else
            info.note = 'flew straight ' .. info.speed
            info.collNote = 'tried to fly straight ' .. info.speed
        end
        if info.speed == 0 then
            info.traits.part = false
            if info.extra == 'koiogran' then
                info.note = 'turned around'
            else
                info.note = 'is stationary'
            end
        end
        -- Banks, regular stuff
    elseif move_code:sub(1, 1) == 'a' then
        info.type = 'adjust'
        info.speed = tonumber(move_code:sub(2, 2))
        info.traits.full = true
        info.traits.part = false
        if info.speed == 1 then
            info.note = 'adjusted forward'
            info.collNote = 'tried to adjust forward'
        else
            info.note = 'adjusted backward'
            info.collNote = 'tried to adjust backward'
        end
    elseif move_code:sub(1, 1) == 'b' then
        info.type = 'bank'
        info.dir = 'right'
        info.speed = tonumber(move_code:sub(3, 3))
        info.traits.full = true
        info.traits.part = true
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        if move_code:sub(-1, -1) == 's' then
            info.extra = 'segnor'
            info.note = 'segnor looped ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to segnor loop ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 't' then
            info.extra = 'talon'
            info.note = 'talon rolled (bank template) ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to talon roll ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'r' then
            info.extra = 'reverse'
            info.note = 'flew reverse bank ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to fly reverse bank ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'z' then
            info.type = 'bankSlip'
            info.extra = 'bankSlip'
            info.note = 'sliped bank ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to slip bank ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'b' then
            info.traits.part = false
            local boostSpd = ''
            if info.speed > 1 then
                boostSpd = ' ' .. info.speed
            end
            info.note = 'boosted ' .. info.dir .. boostSpd
            info.collNote = 'tried to boost ' .. info.dir .. boostSpd
        else
            info.note = 'banked ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to bank ' .. info.dir .. ' ' .. info.speed
        end
        -- Turns, regular stuff
    elseif move_code:sub(1, 1) == 't' then
        if info.size == 'huge' then
            info.note = "tried to turn, but huge ships can't do that"
            info.collNote = "tried to turn, but huge ships can't do that"
            return info
        end
        info.type = 'turn'
        info.dir = 'right'
        info.speed = tonumber(move_code:sub(3, 3))
        info.traits.full = true
        info.traits.part = true
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        if move_code:sub(-1, -1) == 't' then
            info.type = 'talon'
            info.note = 'talon rolled ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to talon roll ' .. info.dir .. ' ' .. info.speed
            if move_code:sub(-2, -2) == 'f' then
                info.type = 'talonF'
                info.note = 'talon rolled ' .. info.dir .. ' ' .. info.speed .. 'adjusting Forward'
                info.collNote = 'tried to talon roll ' .. info.dir .. ' ' .. info.speed .. 'adjusting Forward'
            elseif move_code:sub(-2, -2) == 'b' then
                info.type = 'talonB'
                info.note = 'talon rolled ' .. info.dir .. ' ' .. info.speed .. 'adjusting Backward'
                info.collNote = 'tried to talon roll ' .. info.dir .. ' ' .. info.speed .. 'adjusting Backward'
            end
        elseif move_code:sub(-1, -1) == 's' then
            info.extra = 'segnor'
            info.note = 'segnor looped (turn template) ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to segnor loop (turn template) ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'r' then
            info.extra = 'reverse'
            info.note = 'flew reverse turn ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to fly reverse turn ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'z' then
            info.type = 'turnSlip'
            info.extra = 'turnSlip'
            info.note = 'sliped turn ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to slip turn ' .. info.dir .. ' ' .. info.speed
        elseif move_code:sub(-1, -1) == 'b' then
            info.traits.part = false
            local boostSpd = ''
            if info.speed > 1 then
                boostSpd = ' ' .. info.speed
            end
            info.note = 'boosted (turn template) ' .. info.dir .. boostSpd
            info.collNote = 'tried to boost (turn template) ' .. info.dir .. boostSpd
        else
            info.note = 'turned ' .. info.dir .. ' ' .. info.speed
            info.collNote = 'tried to turn ' .. info.dir .. ' ' .. info.speed
        end
        if tonumber(move_code:sub(3, 3)) == 4 then
            info.traits.part = false
            info.note = 'Pivoted ' .. info.dir
            info.collNote = 'tried pivoting ' .. info.dir
        end


        -- New Barrel Roll
    elseif move_code:sub(1, 1) == 'r' then
        info.type = 'roll'
        info.dir = 'right'
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        info.collNote = 'tried barrel rolling ' .. info.dir
        info.speed = tonumber(move_code:sub(3, 3))
        info.traits.full = true
        info.traits.part = false
        if tonumber(move_code:sub(3, 3)) == 1 then
            info.note = 'barrel rolled ' .. info.dir .. ' forward'
            info.collNote = 'tried barrel rolling ' .. info.dir .. ' forward'
        elseif tonumber(move_code:sub(3, 3)) == 2 then
            info.note = 'barrel rolled ' .. info.dir .. ' straight'
            info.collNote = 'tried barrel rolling ' .. info.dir .. ' straight'
        elseif tonumber(move_code:sub(3, 3)) == 3 then
            info.note = 'barrel rolled ' .. info.dir .. ' backward'
            info.collNote = 'tried barrel rolling ' .. info.dir .. ' backward'
        end
    elseif move_code:sub(1, 2) == 'vt' then
        info.type = 'viperTurn'
        info.dir = 'right'
        if move_code:sub(3, 3) == 'l' or move_code:sub(3, 3) == 'e' then
            info.dir = 'left'
        end
        info.speed = tonumber(move_code:sub(-1, -1))
        info.traits.full = true
        info.traits.part = false
        if move_code:sub(4, 4) == 'f' then
            info.type = 'viperTurnF'
            info.extra = 'forward'
        else
            info.type = 'viperTurnB'
            info.extra = 'backward'
        end
        if tonumber(move_code:sub(-1, -1)) == 1 then
            info.note = 'barrel rolled using turn template ' .. info.dir .. ' ' .. info.extra .. ' adjusting forward'
            info.collNote = 'tried barrel rolling using turn template ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(-1, -1)) == 2 then
            info.note = 'barrel rolled using turn template ' .. info.dir .. ' ' .. info.extra .. ' adjusting straight'
            info.collNote = 'tried barrel rolling using turn template ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(-1, -1)) == 3 then
            info.note = 'barrel rolled using turn template ' .. info.dir .. ' ' .. info.extra .. ' adjusting backward'
            info.collNote = 'tried barrel rolling using turn template ' .. info.dir .. ' ' .. info.extra
        end
        -- New Viper roll
    elseif move_code:sub(1, 1) == 'v' then
        info.type = 'viper'
        info.dir = 'right'
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        info.speed = tonumber(move_code:sub(-1, -1))
        info.traits.full = true
        info.traits.part = false
        if move_code:sub(3, 3) == 'f' then
            info.type = 'viperF'
            info.extra = 'forward'
        else
            info.type = 'viperB'
            info.extra = 'backward'
        end
        if tonumber(move_code:sub(-1, -1)) == 1 then
            info.note = 'barrel rolled using bank template ' .. info.dir .. ' ' .. info.extra .. ' adjusting forward'
            info.collNote = 'tried barrel rolling using bank template ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(-1, -1)) == 2 then
            info.note = 'barrel rolled using bank template ' .. info.dir .. ' ' .. info.extra .. ' adjusting straight'
            info.collNote = 'tried barrel rolling using bank template ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(-1, -1)) == 3 then
            info.note = 'barrel rolled using bank template ' .. info.dir .. ' ' .. info.extra .. ' adjusting backward'
            info.collNote = 'tried barrel rolling using bank template ' .. info.dir .. ' ' .. info.extra
        end
        -- New Decloak
    elseif move_code:sub(1, 1) == 'c' then
        info.type = 'deCloak'
        info.dir = 'right'
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        info.speed = tonumber(move_code:sub(-1, -1))
        info.traits.full = true
        info.traits.part = false
        if tonumber(move_code:sub(-1, -1)) == 1 then
            info.note = 'decloaked ' .. info.dir .. ' forward'
            info.collNote = 'tried decloaking ' .. info.dir .. ' forward'
        elseif tonumber(move_code:sub(-1, -1)) == 2 then
            info.note = 'decloaked ' .. info.dir .. ' straight'
            info.collNote = 'tried decloaking ' .. info.dir .. ' straight'
        elseif tonumber(move_code:sub(-1, -1)) == 3 then
            info.note = 'decloaked ' .. info.dir .. ' backward'
            info.collNote = 'tried decloaking ' .. info.dir .. ' backward'
        end
        if move_code:sub(2, 2) == 's' then
            info.type = 'straight'
            if info.size == "small" then
                info.speed = 2
            else
                info.speed = 1
            end
            info.dir = nil
            info.note = 'decloaked forward'
            info.collNote = 'tried decloacking forward'
        end
        --New Echo
    elseif move_code:sub(1, 1) == 'e' then
        info.type = 'Echo'
        info.dir = 'right'
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        info.speed = tonumber(move_code:sub(4, 4))
        info.traits.full = true
        info.traits.part = false
        if move_code:sub(3, 3) == 'f' then
            info.type = 'echoF'
            info.extra = 'forward'
        elseif move_code:sub(3, 3) == 'b' then
            info.type = 'echoB'
            info.extra = 'backward'
        end
        if tonumber(move_code:sub(4, 4)) == 1 then
            info.note = 'decloacked ' .. info.dir .. ' ' .. info.extra .. ' adjusting forward'
            info.collNote = 'tried decloacking ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(4, 4)) == 2 then
            info.note = 'decloacked ' .. info.dir .. ' ' .. info.extra .. ' adjusting straight'
            info.collNote = 'tried decloacking ' .. info.dir .. ' ' .. info.extra
        elseif tonumber(move_code:sub(4, 4)) == 3 then
            info.note = 'decloacked ' .. info.dir .. ' ' .. info.extra .. ' adjusting backward'
            info.collNote = 'tried decloacking ' .. info.dir .. ' ' .. info.extra
        end
        if move_code:sub(2, 2) == 's' then
            info.type = 'bank'
            info.speed = 2
            info.note = 'decloaked banking right'
            info.collNote = 'tried decloacking banking right'
            if move_code:sub(3, 3) == 'l' or move_code:sub(3, 3) == 'e' then
                info.dir = 'left'
                info.note = 'decloaked banking left'
                info.collNote = 'tried decloacking banking left'
            end
        end
        -- Barrel rolls and decloaks, spaghetti
    elseif move_code:sub(1, 2) == 'ch' or move_code:sub(1, 2) == 'vr' then
        -- Echo's fucking bullshit which goes against ALL the standards
        -- StarViper handled the same
        info.type = 'echo'
        if move_code:sub(1, 2) == 'vr' then
            info.type = 'viper'
        end
        info.dir = 'right'
        info.extra = 'forward'
        if move_code:sub(4, 4) == 'b' then
            info.extra = 'backward'
        end
        if move_code:sub(3, 3) == 'l' or move_code:sub(3, 3) == 'e' then
            -- Ones going right/left
            info.dir = 'left'
        elseif move_code:sub(3, 3) == 's' then
            -- Ones going forward
            info = MoveData.DecodeInfo('b' .. move_code:sub(4, 4) .. '2', ship)
            info.traits.part = false
            info.code = move_code
        end
        if move_code:sub(1, 2) == 'ch' then
            -- Echo dedscriptions
            if info.type == 'echo' then
                info.note = 'dechocloaked ' .. info.dir .. ' ' .. info.extra
                info.collNote = 'tried to dechocloak ' .. info.dir .. ' ' .. info.extra
            else
                info.note = 'dechocloaked forward ' .. info.dir
                info.collNote = 'tried to dechocloak forward ' .. info.dir
            end
        else
            -- SV descriptions
            info.note = 'bank rolled ' .. info.dir .. ' ' .. info.extra
            info.collNote = 'tried to bank roll ' .. info.dir .. ' ' .. info.extra
        end
        -- Special 2nd adjust move
        if move_code == 'chadj' or move_code == 'vradj' then
            info.extra = 'adjust'
        end
    elseif move_code:sub(1, 1) == 'x' or move_code:sub(1, 1) == 'c' then
        -- Rolls
        info.type = 'roll'
        info.dir = 'right'
        info.speed = 1
        if move_code:sub(2, 2) == 'l' or move_code:sub(2, 2) == 'e' then
            info.dir = 'left'
        end
        info.note = 'barrel rolled'
        info.collNote = 'tried to barrel roll'
        -- Decloaks
        -- Straigh decloak is treated as a roll before, now just return straight 2 data
        if move_code:sub(2, 2) == 's' then
            info.type = 'straight'
            info.speed = 2
            info.traits.full = true
            info.note = 'decloaked forward'
            info.collNote = 'tried to decloak forward'
            info.dir = nil
            -- Side decloak is a barrel roll, but with 2 speed
        elseif move_code:sub(1, 1) == 'c' then
            info.note = 'decloaked'
            info.collNote = 'tried to decloak'
            info.speed = 2
        end

        -- Forward/backward modifiers
        if info.type ~= 'straight' then
            if move_code:sub(-1, -1) == 'f' then
                info.extra = 'forward'
                info.note = info.note .. ' forward ' .. info.dir
                info.collNote = info.collNote .. ' forward ' .. info.dir
            elseif move_code:sub(-1, -1) == 'b' then
                info.extra = 'backward'
                info.note = info.note .. ' backward ' .. info.dir
                info.collNote = info.collNote .. ' forward ' .. info.dir
            else
                info.note = info.note .. ' ' .. info.dir
                info.collNote = info.collNote .. ' ' .. info.dir
            end
        end
    end
    return info
end

-- Get the offset data for a full move
-- Return format: {xPos_offset, yPos_offset, zPos_offset, yRot_offset}
MoveData.DecodeFullMove = function(move_code, ship)
    local data = {}
    local info = MoveData.DecodeInfo(move_code, ship)
    if info.type == 'invalid' then
        print('MoveData.DecodeFullMove: invalid move type')
        return { 0, 0, 0, 0 }
    else
        data = MoveData.DecodePartMove(move_code, ship, MoveData.partMax)
    end
    data = MoveData.ApplyFinalModifiers(data, info)
    return data
end

-- Get the offset data for a partial move
-- Return format: {xPos_offset, yPos_offset, zPos_offset, yRot_offset}
MoveData.DecodePartMove = function(move_code, ship, part)
    local data = {}
    local info = MoveData.DecodeInfo(move_code, ship)
    part = math.clamp(part, 0, MoveData.partMax)
    if info.type == 'invalid' then
        print('MoveData.DecodePartMove: invalid move type')
        return { 0, 0, 0, 0 }
    end
    data = MoveData.LUT.ConstructData(info, part)
    data = MoveData.ApplyBasicModifiers(data, info)
    return data
end

-- END MOVEMENT DATA MODULE
--------

return MoveData

end)
__bundle_register("TTS_lib.Vector.Vector", function(require, _LOADED, __bundle_register, __bundle_modules)
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
__bundle_register("TTS_Lib.EventSub.EventSub", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by dzikakulka
-- Issues, history at: http://github.com/tjakubo2/TTS_lib
--
-- Simple framework for adding many subscribers of default events (onLoad, update, onChat etc)
-- Description and usage in README.md in this lib folder in repository
-- ~~~~~~

local EventSub = {
    subs = {}
}

-- Table mapping event names to table of handler functions

-- Initialize subscriber table for given event function, save current one if exists
EventSub.AddEvent = function(eventName)
    EventSub.subs[eventName] = {}
    if type(_G[eventName]) == 'function' then
        table.insert(EventSub.subs[eventName], _G[eventName])
    end
    -- Set the global event function to call each handler pasing its parameters
    _G[eventName] = function(...)
        for _, handler in ipairs(EventSub.subs[eventName]) do
            handler(table.unpack({ ... }))
        end
    end
end
-- Method for adding subscribers
EventSub.Register = function(eventName, handler)
    assert(type(eventName) == 'string', 'EventSub.Register: Provided event name not a string!')
    assert(type(handler) == 'function', 'EventSub.Register: Provided handler not a function!')
    if not EventSub.subs[eventName] then
        EventSub.AddEvent(eventName)
    end
    table.insert(EventSub.subs[eventName], handler)
end

return EventSub

end)
__bundle_register("Player.GlobalGuiControl", function(require, _LOADED, __bundle_register, __bundle_modules)
local GlobalGuiControl = {
    playerTable = {},
    shown = {
        showMouseOverGui = true,
    }
}

GlobalGuiControl.getPlayerConfig = function(playerColor)
    if not GlobalGuiControl.playerTable[playerColor] then
        GlobalGuiControl.playerTable[playerColor] = { panels = { hover = false } }
    end
    return GlobalGuiControl.playerTable[playerColor]
end

GlobalGuiControl.showForPlayer = function(params)
    local panel = params.panel
    local color = params.color
    local opened = self.UI.getAttribute(panel, "visibility")
    if opened == nil then opened = "" end

    if params.close then
        opened = opened:gsub("|" .. color, "")
        opened = opened:gsub(color .. "|", "")
        opened = opened:gsub(color, "")
        self.UI.setAttribute(panel, "visibility", opened)
        if opened == "" then
            self.UI.setAttribute(panel, "active", "false")
            GlobalGuiControl.shown[panel] = false
        end
    else
        if GlobalGuiControl.shown[panel] ~= true then
            self.UI.setAttribute(panel, "active", "true")
            self.UI.setAttribute(panel, "visibility", color)
            GlobalGuiControl.shown[panel] = true
        else
            self.UI.setAttribute(panel, "visibility", opened .. "|" .. color)
        end
    end
end

GlobalGuiControl.recreateHoverPanels = function()
    local xml = Global.UI.getXmlTable()
    for i = #xml, 1, -1 do
        if xml[i].attributes.id and xml[i].attributes.id:find("HoverPanel") then
            table.remove(xml, i)
        end
    end

    for player, config in pairs(GlobalGuiControl.playerTable) do
        if config.panels.hover then
            print("PlayerPanel: " .. player)
            local playerPanel = {
                tag = "Panel",
                attributes = {
                    visibility = player,
                    id = player .. "HoverPanel",
                    class = "HoverPanel",
                    width = "300",
                    childAlignment = "MiddleRight"
                },

                children = {
                    tag = "HorizontalLayout",
                    attributes = {
                        childForceExpandHeight = false,
                        childForceExpandWidth = false,
                        childAlignment = "MiddleRight"
                    },
                    children = {
                        {
                            tag = "Button",
                            attributes = {
                                textColor = "#FFFFFF",
                                onClick = "mark",
                                minWidth = "250",
                                id = "iniEntry"
                            },
                            value = " - "
                        },
                        -- TODO: This is unexpected in X-Wing
                        {
                            tag = "Button",
                            attributes = {
                                onClick = "getMonsterAC",
                                text = "▶",
                                id = "MonsterAbilityCard",
                                minWidth = "23",
                                maxWidth = "23",
                                minHeight = "25",
                                fontSize = "12",
                                onClick = "hideMouseOverGui(" .. player .. ")"
                            }
                        }
                    }
                }

            }
            table.insert(xml, playerPanel)
        end
    end
    Global.UI.setXmlTable(xml)
end

function showMouseOverGui(player, opt, id)
    player_config = GlobalGuiControl.getPlayerConfig(player.color)
    player_config.panels.hover = true
    GlobalGuiControl.showForPlayer({ color = player.color, panel = "showMouseOverGui", close = true })
    GlobalGuiControl.recreateHoverPanels()
end

function hideMouseOverGui(player, opt, id)
    player_config = GlobalGuiControl.getPlayerConfig(player.color)
    player_config.panels.hover = false
    GlobalGuiControl.showForPlayer({ color = player.color, panel = "showMouseOverGui", close = false })
    GlobalGuiControl.recreateHoverPanels()
end

return GlobalGuiControl

end)
__bundle_register("Player.StreamManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Stream manager, by Eirik Munthe
-- This manager display stream info
local M = {}

M.PresentedDice = {}

M.RollTimeout = 5

M.announcement_timer = nil

M.PanelOffset = {
    left = {
        "-400 200",
        "-400 0",
        "-400 -200",
        "-400 400",
        "-400 -400",
        "-400 600",
        "-400 -600"
    },
    right = {
        "400 200",
        "400 0",
        "400 -200",
        "400 400",
        "400 -400",
        "400 600",
        "400 -600"
    }
}

M.PanelRotation = {
    left = "0 0 0",
    right = "0 0 180"
}

M.PanelPlayerAlignment = {
    left = "UpperLeft",
    right = "LowerRight"
}

M.PanelPlayerOffset = {
    left = "10 -10",
    right = "-10 10"
}

M.PresentationCounter = 0

M.Dice = function(id, number)
    return
    {
        image = "Presentation" .. id .. "Die" .. number,
        modification = "Presentation" .. id .. "Die" .. number .. "Mod",
        presented = false,
        result = "Blank",
        dice_object = nil
    }
end

M.Presentation = function(color, side)
    local id = M.PresentationCounter + 1
    M.PresentationCounter = id
    local presentation = {
        timer_id = nil,
        panel = {
            ui = "PresentationPanel" .. id,
            background = "PresentationPanel" .. id .. "Background",
            side = side,
            player_name = "PresentationPanel" .. id .. "Player"
        },
        player = {
            color = color,
        },
        dice =
        {
            M.Dice(id, 1),
            M.Dice(id, 2),
            M.Dice(id, 3),
            M.Dice(id, 4),
            M.Dice(id, 5),
            M.Dice(id, 6),
        }
    }
    presentation.SetDiceResult = function(result)
        M.PresentedDice[result.die] = presentation
        for _, dice in pairs(presentation.dice) do
            if not dice.presented or dice.dice_object == result.die then
                Global.UI.setAttribute(dice.image, "image", result.type .. result.value)
                Global.UI.setAttribute(dice.image, "active", "true")
                dice.presented = true
                dice.dice_object = result.die
                break;
            end
        end
        --Global.UI.setAttribute(presentation.panel.ui, "active", "true")
        if presentation.timer_id then
            Wait.stop(presentation.timer_id)
        else
            Global.UI.show(presentation.panel.ui)
        end
        presentation.timer_id = Wait.time(presentation.Timout, M.RollTimeout)
    end

    presentation.Timout = function()
        for _, dice in pairs(presentation.dice) do
            Global.UI.setAttribute(dice.image, "image", "RedBlank")
            Global.UI.setAttribute(dice.image, "active", "false")
            if dice.dice_object then
                M.PresentedDice[dice.dice_object] = nil
            end
        end
        Global.UI.hide(presentation.panel.ui)
        --Global.UI.setAttribute(presentation.panel.ui, "active", "false")
        presentation.timer_id = nil
    end

    Global.UI.setAttribute(presentation.panel.background, "rotation", M.PanelRotation[side])
    Global.UI.setAttribute(presentation.panel.ui, "offsetXY", M.PanelOffset[side][id])
    Global.UI.setAttribute(presentation.panel.background, "color", "#" .. Color[color]:toHex(false) .. "88")
    Global.UI.setAttribute(presentation.panel.background, "active", "true")
    Global.UI.setAttribute(presentation.panel.player_name, "alignment", M.PanelPlayerAlignment[side])
    Global.UI.setAttribute(presentation.panel.player_name, "offsetXY", M.PanelPlayerOffset[side])
    --Global.UI.setAttribute(presentation.panel.ui, "active", "true")

    return presentation
end

M.Announce = function(text, color)
    if M.announcement_timer then
        Wait.stop(M.announcement_timer)
        Global.UI.hide("AnnouncementPanel")
        Wait.time(function() M.Announce(text, color) end, 0.5)
    else
        Global.UI.setAttribute("AnnouncementImage", "color", "#" .. Color[color]:toHex(false) .. "88")
        Global.UI.show("AnnouncementPanel")
        Global.UI.setValue("AnnouncementText", text)
        M.announcement_timer = Wait.time(
            function()
                Global.UI.hide("AnnouncementPanel")
                M.announcement_timer = nil
            end, 2)
    end
end

M.SetDiceData = function(DiceData, player)
    local natties = false
    if #DiceData > 2 then
        natties = true
    end
    for _, result in pairs(DiceData) do
        local presentation = nil
        if M.PresentedDice[result.die] then
            presentation = M.PresentedDice[result.die]
        else
            presentation = M.Presentations[player]
        end
        if presentation then
            presentation.SetDiceResult(result)
        end
        if (result.modified == true) or (result.value == "Blank") or (result.value == "Eye") then
            natties = false
        end
    end
    if natties then
        M.Announce("Natties!", player);
    end
end

M.Presentations = {
    --Blue = M.Presentation("Blue", "right"),
    --orange = M.Presentation("Orange", "left")
}


Wait.time(function()
    M.Presentations['Orange'] = M.Presentation("Orange", "left")
    M.Presentations['Blue'] = M.Presentation("Blue", "right")
end
, 1.0)

--[[
Wait.time(function()
  M.SetDiceData({
    {
      die = "temp",
      value = "Hit",
      modified = false,
      type = "Red",
    },
    {
      die = "temp2",
      value = "Crit",
      modified = false,
      type = "Red",
    },
    {
      die = "temp3",
      value = "Hit",
      modified = false,
      type = "Red",
    }
  }, Player.Blue.color)
end
  , 5.0)

Wait.time(function()
  M.SetDiceData({
    {
      die = "temp3",
      value = "Eye",
      modified = true,
      type = "Red",
    }
  }, Player.Blue.color)
end
  , 10.0)

Wait.time(function()
  M.SetDiceData({
    {
      die = "temp3",
      value = "Hit",
      modified = true,
      type = "Red",
    }
  }, Player.Blue.color)
end
  , 12.0)

  Wait.time(function()
    M.SetDiceData({
      {
        die = "g1",
        value = "Evade",
        modified = false,
        type = "Green",
      },
      {
        die = "g2",
        value = "Evade",
        modified = false,
        type = "Green",
      },
      {
        die = "g3",
        value = "Evade",
        modified = false,
        type = "Green",
      }
    }, Player.Orange.color)
  end
    , 14.0)

  Wait.time(function()
    M.SetDiceData({
      {
        die = "temp3",
        value = "Hit",
        modified = true,
        type = "Red",
      }
    }, Player.Blue.color)
  end
    , 20.0)
]]

M.AddPresentation = function(color, side)
    M.Presentations[color] = M.Presentation(color, side)
end

return M

end)
__bundle_register("Ship.ShipProximityHider", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Hotkey module, By Eirik W. Munthe (eirikmun)
local M = {}
M.update_delay = 0.2
M.hide_distance = 3.5
M.tint_values = { far = color(1, 1, 1, 1), close = color(1, 1, 1, 0.2) }

M.size_mod = { small = 0, medium = 0.8, large = 1.6, huge = 1.2 }

M.proximity_check = function()
    for _, hider_ship in pairs(getObjectsWithAllTags({ 'Ship', 'ProximityHider' })) do
        local is_close = "far"
        local hider_pos = hider_ship.getPosition()
        for _, other_ship in pairs(getObjectsWithTag('Ship')) do
            if hider_ship ~= other_ship then
                local size = other_ship.getTable('Data').Size or 'small'
                --print(string.format("Distance between %s and %s is %f", hider_ship.getName(), other_ship.getName(), hider_pos:distance(other_ship.getPosition())))
                if hider_pos:distance(other_ship.getPosition()) < (M.hide_distance + M.size_mod[size]) then
                    is_close = "close"
                    break
                end
            end
        end
        if hider_ship.getVar("SetProximityHiding") then
            hider_ship.call("SetProximityHiding", is_close == "close")
        else
            if hider_ship.getColorTint() ~= M.tint_values[is_close] then
                --print(string.format("Changing tint of %s", hider_ship.getName()))
                hider_ship.setColorTint(M.tint_values[is_close])
            end
        end
    end
end


return M

end)
__bundle_register("Dial.DialManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Dial manager module, By Eirik W. Munthe (eirikmun)
local D = {}

D.announceColor = color(0.1, 1, 0.1)

D.assignedDials = {}

D.assignDial = function(dial, ship, player)
    if ship then
        D.assignedDials[dial.getGUID()] = { dial = dial, ship = ship, player = player, set = false }
    else
        D.assignedDials[dial.getGUID()] = nil
    end
end

D.setDial = function(dial)
    local dialGUID = dial.getGUID()

    if D.assignedDials[dialGUID] then
        D.assignedDials[dialGUID].set = true

        local all_dials_set = true

        for _, assignedDial in pairs(D.assignedDials) do
            local playerColor = assignedDial.ship.getVar("owningPlayer") or ""

            if playerColor:lower() ~= "black" and assignedDial.set == false then
                all_dials_set = false
                break
            end
        end

        if all_dials_set then
            printToAll("All dials have been set by all players", D.announceColor)
        end
    else
        printToAll("Attempted to set dial, but dial not assigned", D.announceColor)
    end
end


D.unSetDial = function(dial)
    if D.assignedDials[dial.getGUID()] then
        D.assignedDials[dial.getGUID()].set = false
    else
        printToAll("Attempted to unset dial, but dial not assigned", D.announceColor)
    end
end

D.onObjectDestroyed = function(obj)
    --print("In table: " .. tostring(D.assignedDials[obj.getGUID()]))
    if D.assignedDials[obj.getGUID()] ~= nil then
        D.assignedDials[obj.getGUID()] = nil
        return
    end
    --print("Deleted obj: " .. tostring(obj))
    for idx, dial in pairs(D.assignedDials) do
        --print("In table: " .. tostring(dial.ship))
        if dial.ship == obj then
            D.assignedDials[idx] = nil
        end
    end
end

D.isAllDialsSet = function(player)
    for _, dial in D.assignedDials do
        if dial.player == player and dial.set == false then
            return false
        end
    end
    return true
end

return D

end)
__bundle_register("Player.PlayerActionModule", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by Eirik 'Flippster' Munthe
--
--
-- X-Wing player action module

-- Define actions for various tags
-- Each tag has a handler for each Player.Action

local DiceControlModule = require("Game.Component.Dice.DiceControl")

local tagActions = {
    NonDeletable = {
        [Player.Action.Delete] = function(object, player)
            return false
        end
    },
    ConfigCard = {
        [Player.Action.FlipOver] = function(object, player)
            for _, ship in pairs(getObjectsWithTag("Ship")) do
                local ship_data = ship.getTable("Data")
                if ship_data.Config and (ship_data.Config.CardGUID == object.getGUID()) then
                    ship.call("SetConfiguration", { ConfigId = object.is_face_down and 1 or 2 })
                    break
                end
            end
        end
    },
    Flippable = {
        [Player.Action.FlipOver] = function(object, player)
            object.call("onFlip", { player = player }) -- Calls the flip behavior for Flippable objects
        end
    },
    DiceControl = {
        [Player.Action.Randomize] = function(object, player)
            DiceControlModule.playerActionRandomize(object, player) -- Handle randomizing objects
        end
    },
    RemoveOnFlip = {
        [Player.Action.FlipOver] = function(object, player)
            return Global.call("API_RemoveTokenOnFlip", { object = object, player = player })
        end
    }
}

-- Handles the player actions based on tags
function onPlayerAction(player, action, targets)
    for _, object in pairs(targets) do
        local tags = object.getTags()
        for _, tag in ipairs(tags) do
            local tagAction = tagActions[tag]
            if tagAction and tagAction[action] then
                if tagAction[action](object, player) == false then
                    return false
                end
            end
        end
    end
    return true
end

-- The following are the available Player.Action.* constants. They are `int`s
-- Copy - Copy (or commence cloning) the targets.
-- Cut - Cut (copy and delete) the targets.
-- Delete - Delete the targets.
-- FlipIncrementalLeft - Incrementally rotate the targets counter-clockwise around their flip axes, typically the scene's Z-axis.
-- FlipIncrementalRight - Incrementally rotate the targets clockwise around their flip axes, typically the scene's Z-axis.
-- FlipOver - Rotate the targets 179 degrees around their flip axes, typically the scene's Z-axis i.e. toggle the targets between face up and face down.
-- Group - Group the targets.
-- Paste - Paste (spawn) the targets.
-- PickUp - Pick up the targets.
-- Randomize - Randomize the targets.
-- RotateIncrementalLeft - Rotate the targets incrementally, typically counter-clockwise around the scene's Y-axis. Instead of being rotated exclusively around the Y-axis, dice will be rotated to the previous rotation value.
-- RotateIncrementalRight - Rotate the targets incrementally, typically clockwise around the scene's Y-axis. Instead of being rotated exclusively around the Y-axis, dice will be rotated to the next rotation value.
-- RotateOver - Rotate the targets 179 degrees around the scene's Y-axis.
-- Select - Add the targets to the player's selection.
-- Under - Move the targets underneath objects below them on table.

end)
__bundle_register("Game.Component.Dice.DiceControl", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by Eirik 'Flippster' Munthe
--
--
-- X-Wing dice control module,
-- Prevents dice tampering, and presents dice results.
-- Stores and presents dice statistics
-- ~~~~~~
local EventSub = require("TTS_Lib.EventSub.EventSub")
local Players = require("Player.Players")

local DiceControlModule = {
    dice_statistics = {},
    rolled_dice = {},
    dice_roller_state = {},
    player_colors = {},
    enabled = true,
    error_color = color(1.0, 0.2, 0.1),
    info_color = color(0.7, 0.7, 0.4),
    highlight_color = "[FFFF55]",
    test_mode = false,
    first_player_scores = {
        Crit = 100,
        Eye = 10,
        Hit = 1,
        Blank = 0
    }
}


DiceControlModule.dice_types = {
    Red = {
        color = "[FF0000]",
        luck_values = {
            Crit  = {
                expected = 1 / 8,
                luck = 1.25
            },
            Hit   = {
                expected = 3 / 8,
                luck = 1
            },
            Eye   = {
                expected = 2 / 8,
                luck = 0.5
            },
            Blank = {
                expected = 2 / 8,
                luck = 0
            }
        },
        result_order = { "Crit", "Hit", "Eye" }
    },
    Green = {
        color = "[00FF00]",
        luck_values = {
            Evade = {
                expected = 3 / 8,
                luck = 1
            },
            Eye = {
                expected = 2 / 8,
                luck = 0.75
            },
            Blank = {
                expected = 3 / 8,
                luck = 0
            }
        },
        result_order = { "Evade", "Eye" }
    },
    RedTest = {
        color = "[FFFFFF]",
        luck_values = {
            Crit = {
                expected = 1 / 8,
                luck = 1.25
            },
            Hit1 = {
                expected = 1 / 8,
                luck = 1
            },
            Hit2 = {
                expected = 1 / 8,
                luck = 1
            },
            Hit3 = {
                expected = 1 / 8,
                luck = 1
            },
            Eye1 = {
                expected = 1 / 8,
                luck = 0.5
            },
            Eye2 = {
                expected = 1 / 8,
                luck = 0.5
            },
            Blank1 = {
                expected = 1 / 8,
                luck = 0
            },
            Blank2 = {
                expected = 1 / 8,
                luck = 0
            }
        },
        result_order = { "Crit", "Hit1", "Hit2", "Hit3", "Eye1", "Eye2", "Blank1", "Blank2" }
    },
    PlayerOrder = {
        color = "[FF00FF]",
        result_order = { "Crit", "Eye", "Hit" }
    },
    Scenario = {
        color = "[7777FF]",
        result_order = { "Scramble the transmissions", "Assault at the satelite array", "Chance engagement", "Salvage mission" }
    },
    Default = {
        color = "[777777]"
    }
}

DiceControlModule.GetDefaultDiceStats = function(diceColor)
    def = { Total = 0 }
    if DiceControlModule.dice_types[diceColor] and DiceControlModule.dice_types[diceColor].luck_values then
        for result, _ in pairs(DiceControlModule.dice_types[diceColor].luck_values) do
            def[result] = 0
        end
    end
    return def
end

DiceControlModule.onLoad = function()
    addContextMenuItem("Toggle dice control",
        function()
            if DiceControlModule.enabled then
                DiceControlModule.enabled = false
                printToAll("Dice control is now DISABLED", DiceControlModule.info_color)
            else
                DiceControlModule.enabled = true
                printToAll("Dice control is now ENABLED", DiceControlModule.info_color)
            end
        end, false, false)
    addContextMenuItem("Present dice statistics", DiceControlModule.presentStatistics, false)
    addContextMenuItem("Reset dice statistics", function() DiceControlModule.dice_statistics = {} end, false)
    DiceControlModule.dicecontainer = DiceControlModule.findByGMNotes("dicebag1") -- you probably want findByGMNotes(gmnoteToFind) here
end

EventSub.Register('onLoad', DiceControlModule.onLoad)


DiceControlModule.presentStatistics = function()
    for player, types in pairs(DiceControlModule.dice_statistics) do
        local total = 0
        printToAll("[" .. Color.fromString(DiceControlModule.player_colors[player]):toHex() .. "]" .. player .. "[-] have rolled:", DiceControlModule.info_color)
        local playerLuck = nil
        for type, results in pairs(types) do
            local typeTotal = results.Total
            total = total + typeTotal
            local luck = 0
            local typeColor = DiceControlModule.dice_types[type].color or "[#FFFFFF]"
            for result, number in pairs(results) do
                local percentage = tostring(math.floor(number / typeTotal * 1000) / 10)
                local luckValue = DiceControlModule.dice_types[type].luck_values
                local luckString = ""
                if luckValue ~= nil and luckValue[result] ~= nil then
                    luckString = " - Expected: " .. tostring(luckValue[result].expected * typeTotal)
                    luck = luck + ((number - (luckValue[result].expected * typeTotal)) * luckValue[result].luck)
                end
                printToAll(typeColor .. type .. "[-] " .. result .. ": " .. DiceControlModule.highlight_color .. tostring(number) .. "[-] (" .. percentage .. "%)" .. luckString, DiceControlModule.info_color)
            end
            if DiceControlModule.dice_types[type] ~= nil then
                printToAll(typeColor .. type .. "[-] dice luck score: " .. DiceControlModule.highlight_color .. tostring(luck) .. "[-]", DiceControlModule.info_color)
                playerLuck = (playerLuck or 0) + luck
            end
        end
        if playerLuck ~= nil then
            printToAll("Total luck score: " .. DiceControlModule.highlight_color .. tostring(playerLuck) .. "[-]", DiceControlModule.info_color)
        end
    end
end

DiceControlModule.playerActionRandomize = function(object, playerInstance)
    local player = playerInstance.steam_name
    DiceControlModule.player_colors[player] = playerInstance.color
    if DiceControlModule.enabled and (object.tag == "Dice") and not object.locked and (object.held_by_color == nil) then
        DiceControlModule.dice_roller_state[player] = DiceControlModule.dice_roller_state[player] or "idle"
        if DiceControlModule.dice_roller_state[player] == "idle" then
            if object.held_by_color ~= nil then
                DiceControlModule.dice_roller_state[player] = "error"
                Wait.frames(function() DiceControlModule.dice_roller_state[player] = "idle" end, 1)
                return
            end
            DiceControlModule.rolled_dice[player] = {}

            if not DiceControlModule.PrepareDice(object, player) then
                return
            end
            DiceControlModule.dice_roller_state[player] = "starting"
            Wait.time(
                function()
                    if #DiceControlModule.rolled_dice[player] ~= 0 then
                        DiceControlModule.dice_roller_state[player] = "waiting"
                    end
                end, 0.8, 0)
            Wait.condition(function() DiceControlModule.PresentDiceRollerResult(player) end,
                function() return DiceControlModule.UntilRolledDiceAreStill(player) end, 6,
                function() DiceControlModule.RollTimeout(player) end)
        elseif DiceControlModule.dice_roller_state[player] == "starting" then
            for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
                if dice == object then
                    return
                end
            end
            DiceControlModule.PrepareDice(object, player)
        elseif DiceControlModule.dice_roller_state[player] == "waiting" then
            for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
                if dice == object then
                    return
                end
            end
            printToAll("Please don't start new rolls while waiting for the result of another", DiceControlModule.error_color)
            destroyObject(object)
        end
    end
end

DiceControlModule.PrepareDice = function(die, player)
    if not die.isSmoothMoving() then
        die.roll()
        Wait.time(function() die.roll() end, 0.1)
        die.interactable = false
        players = getSelectingPlayers(die)
        for _, playerInstance in pairs(players) do
            die.removeFromPlayerSelection(playerInstance.color)
        end
        table.insert(DiceControlModule.rolled_dice[player], die)
        return true
    else
        printToAll("Please don't roll flipping dice", DiceControlModule.error_color)
        destroyObject(die)
        return false
    end
end

DiceControlModule.RollTimeout = function(player)
    printToAll("Roll timed out, please try again", DiceControlModule.error_color)
    for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
        dice.interactable = true
    end
    DiceControlModule.dice_roller_state[player] = "idle"
end

DiceControlModule.PresentDiceRollerResult = function(player)
    local resultTable = {}
    for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
        dice.interactable = true
    end

    for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
        local diceColor = dice.getVar("dicecolor") or "Default"
        local result = dice.getRotationValue()
        resultTable[diceColor] = resultTable[diceColor] or {}
        resultTable[diceColor][result] = (resultTable[diceColor][result] or 0) + 1
        local playerStats = DiceControlModule.dice_statistics[player] or {}
        playerStats[diceColor] = playerStats[diceColor] or DiceControlModule.GetDefaultDiceStats(diceColor)
        playerStats[diceColor].Total = (playerStats[diceColor].Total or 0) + 1
        playerStats[diceColor][result] = (playerStats[diceColor][result] or 0) + 1
        DiceControlModule.dice_statistics[player] = playerStats
    end
    local any_result = false
    local resultText = "[" .. Color.fromString(DiceControlModule.player_colors[player]):toHex() .. "]" .. player .. "[-] rolled " .. DiceControlModule.highlight_color .. tostring(#DiceControlModule.rolled_dice[player]) .. "[-] dice and got "
    local resultTexts = {}
    for dice_color, results in pairs(resultTable) do
        if DiceControlModule.dice_types[dice_color].result_order ~= nil then
            for _, result in pairs(DiceControlModule.dice_types[dice_color].result_order) do
                if results[result] ~= nil then
                    local plural_s = ""
                    if results[result] > 1 then
                        plural_s = "s"
                    end
                    any_result = true
                    table.insert(resultTexts, DiceControlModule.highlight_color .. tostring(results[result]) .. "[-] " .. DiceControlModule.dice_types[dice_color].color .. result .. plural_s .. "[-] ")
                end
            end
        else
            for res, num in pairs(results) do
                resultText = resultText .. DiceControlModule.highlight_color .. tostring(num) .. "[-]x" .. DiceControlModule.dice_types[dice_color].color .. res .. "[-] "
            end
        end
    end
    if any_result == false then
        resultText = resultText .. DiceControlModule.highlight_color .. "Got nothing![-]"
    else
        for i = 1, #resultTexts, 1 do
            resultText = resultText .. resultTexts[i]
            if #resultTexts - i > 1 then
                resultText = resultText .. ", "
            elseif #resultTexts - i == 1 then
                resultText = resultText .. " and "
            end
        end
    end
    printToAll(resultText, DiceControlModule.info_color)
    DiceControlModule.CheckFirstPlayerRoll(player)
    DiceControlModule.dice_roller_state[player] = "idle"

    if DiceControlModule.test_mode then
        for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
            dice.setRotation(vector(326.26, 179.99, 90.00))
        end
        Wait.time(
            function()
                for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
                    if dice then
                        dice.randomize(player)
                    end
                end
            end, 0.8, 0)
    end
end

DiceControlModule.CheckFirstPlayerRoll = function(player)
    if #DiceControlModule.rolled_dice[player] == 3 then
        local score = 0
        for _, dice in pairs(DiceControlModule.rolled_dice[player]) do
            if dice.getVar("dicecolor") ~= "PlayerOrder" then
                print("Not PlayerOrder dice")
                return
            end
            score = score + DiceControlModule.first_player_scores[dice.getRotationValue()] or 0
        end
        getObjectFromGUID("c9a2a0").call("firstPlayerRoll",
            { player = player, color = DiceControlModule.player_colors[player], score = score })
    end
end

DiceControlModule.UntilRolledDiceAreStill = function(player)
    local result = true
    for k = #DiceControlModule.rolled_dice[player], 1, -1 do
        local dice = DiceControlModule.rolled_dice[player][k]
        if dice == nil then
            printToAll("A dice disappeared while rolling!", DiceControlModule.error_color)
            table.remove(DiceControlModule.rolled_dice[player], k)
        elseif dice.held_by_color ~= nil then
            printToAll("Please don't grab dice that are being rolled!", DiceControlModule.error_color)
            table.remove(DiceControlModule.rolled_dice[player], k)
            destroyObject(dice)
        elseif not dice.resting then
            result = false
        end
    end
    return result
end

-- [[ Following is addition for changing dice looks by Snake3y3s]]
DiceControlModule.platformToBag = {
    ["atkPlat01"] = "atkOG1",
    ["atkPlat02"] = "atkBLACK1",
    ["atkPlat03"] = "atkWHITE1",
    ["atkPlat04"] = "atkGOLD1",
    ["atkPlat05"] = "atkSPARKLY1",
    ["atkPlat06"] = "atkMARBLE1",
    ["defPlat01"] = "defOG1",
    ["defPlat02"] = "defBLACK1",
    ["defPlat03"] = "defWHITE1",
    ["defPlat04"] = "defSILVER1",
    ["defPlat05"] = "defSPARKLY1",
    ["defPlat06"] = "defMARBLE1",
}

DiceControlModule.upCast = function(obj, dist, offset, multi)
    local dist = dist or 1
    local offset = offset or 0
    local multi = multi or 1
    local oPos = obj.getPosition()
    local oBounds = obj.getBoundsNormalized()
    local oRot = obj.getRotation()
    local orig = { oPos[1], oPos[2] + offset, oPos[3] }
    local siz = { oBounds.size.x * multi, dist, oBounds.size.z * multi }
    local orient = { oRot[1], oRot[2], oRot[3] }
    local hits = Physics.cast({
        origin       = orig,
        direction    = { 0, 1, 0 },
        type         = 3,
        size         = siz,
        orientation  = orient,
        max_distance = 0,
        debug        = false,
    })
    local hitObjects = {}
    for _, v in pairs(hits) do
        if v.hit_object ~= obj then table.insert(hitObjects, v.hit_object) end
    end
    return hitObjects
end


DiceControlModule.getObjectInContainerByGMNote = function(container, gmnoteToFind) -- most of the script here to find out if, and if so which, item is in the container
    local takenObject = nil                                                        -- keep the scope local outside of the loop
    for _, c in ipairs(container.getObjects()) do
        if c.gm_notes == gmnoteToFind then
            takenObject = container.takeObject({ -- correct call syntax, use .takeObject() on your container
                index = c.index,                 -- c.index to get the correct index always
                position = Vector(0, 0, 0),
                smooth = false,
                callback_function = function(newBag)     -- executes when newBag finished spawning
                    newBag.translate(Vector(0, 0.08, 0)) -- moves it 1 unit straight down
                end
            })                                           -- position correctly spelled and correct case
            takenObject.setLock(true)                    -- locks it
        end
    end
    return takenObject
end

DiceControlModule.findByGMNotes = function(gmnotes) -- finds an object in the game whose .getGMNotes9) matches the gmnotes parameter
    for _, obj in pairs(getAllObjects()) do
        if obj.getGMNotes() == gmnotes then return obj end
    end
end

DiceControlModule.onObjectStateChange = function(object, old_guid)    -- object is the _new_ state
    -- clear the bag on top
    for _, foundObject in ipairs(DiceControlModule.upCast(object)) do -- for each object in the platform scripting zone..
        if foundObject.tag == "Infinite" then                         -- if an infinite bag
            local gmnotes = foundObject.getGMNotes()
            if gmnotes and gmnotes ~= "" then
                DiceControlModule.dicecontainer.putObject(foundObject)
                local lastNumber = tonumber(string.sub(gmnotes, -1)) or
                    0                                                                      -- gives us the very last character in our gmnotes - in our example "Platform 1" would give "1"
                foundObject.setPosition(Vector(-24, 1, 10) + Vector(lastNumber * 4, 0, 0)) -- sets the bag starting at 0,2,10, and adding 4 to x, multiplied by the lastNumber - so they all line up.
            end
        end
    end
    -- figure out which is the new bag
    local gmnotes = object.getGMNotes()                                                                               -- get the gm notes of the new state
    local infiniteBagString = DiceControlModule.platformToBag
        [gmnotes]                                                                                                     -- get the infiniteBagString from platformToBag e.g. "Platform 1" will give us "InfiniteBag 1"
    if not infiniteBagString then return end                                                                          -- if the object's gm notes is not a key in platformToBag then we don't want to run any more code

    local newBag = DiceControlModule.getObjectInContainerByGMNote(DiceControlModule.dicecontainer, infiniteBagString) -- a simple function to find an object that matches the infiniteBagString (see below)

    if not newBag then
        log("Error: No associated bag found - has it been deleted?")
        return
    end                                                           --

    newBag.setPosition(object.getPosition() + Vector(0, 0.08, 0)) -- put the new bag 2 units above the platform
end

EventSub.Register('onObjectStateChange', DiceControlModule.onObjectStateChange)

return DiceControlModule

end)
__bundle_register("Player.Players", function(require, _LOADED, __bundle_register, __bundle_modules)
local Players = {}

-- Spieler
-- Function to get player by color
Players.getPlayerByColor = function(color)
    for _, player in pairs(Player.getPlayers()) do
        if player.color == color then
            return player
        end
    end
    return nil
end

Players.getPlayerName = function(player_color)
    local player = Players.getPlayerByColor(player_color)
    if player ~= nil then
        return player.steam_name or player_color
    end
    return player_color or "no one"
end

-- Function to check if two players are on the same team
Players.areAllies = function(color1, color2)
    if (color1 == color2) then
        return true
    end
    local player1 = Players.getPlayerByColor(color1)
    local player2 = Players.getPlayerByColor(color2)

    if player1 == nil or player2 == nil then
        print("One or both players not found.")
        return false
    end

    return player1.team == player2.team
end

return Players

end)
__bundle_register("Player.HotkeyManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Hotkey module, By Eirik W. Munthe (eirikmun)
local EventSub = require("TTS_Lib.EventSub.EventSub")
local ObjType = require("TTS_Lib.ObjType.ObjType")
local H = {}

H.arcCheckFixedArcs = function(player_color, hovered_object, world_position, key_down_up)
    if hovered_object and ObjType.IsOfType(hovered_object, 'ship') then
        local fixed_arcs = hovered_object.call("GetFixedArcs")
        if #fixed_arcs > 0 then
            hovered_object.setDescription(Global.getTable("arcToCmnd")[fixed_arcs[1]])
        end
    end
end

H.arcCheckTurretArcs = function(player_color, hovered_object, world_position, key_down_up)
    if hovered_object and ObjType.IsOfType(hovered_object, 'ship') then
        hovered_object.setDescription("turret")
    end
end

H.TlAndRangeCheck = function(player_color, hovered_object, world_position, key_down_up)
    if hovered_object and ObjType.IsOfType(hovered_object, 'ship') then
        hovered_object.setDescription("r3a")
        proxyPerformAction({ hovered_object, 'Target Lock', player_color })
    end
end

H.onLoad = function()
    addHotkey("Arc Check, Fixed arcs", H.arcCheckFixedArcs, false)
    addHotkey("Arc Check, Turret arcs", H.arcCheckTurretArcs, false)
    addHotkey("R3 and TL", H.TlAndRangeCheck, false)
end

EventSub.Register('onLoad', H.onLoad)

return H

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
__bundle_register("Player.ConfigManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by Eirik 'Flippster' Munthe
--
--
-- X-Wing configuration manager module,
-- Stores global table configurations, and per-player configurations
-- ~~~~~~
local EventSub = require("TTS_Lib.EventSub.EventSub")

ConfigManager = {
    PlayerConfigs = {},
    SetCallbacks = {},
    DefaultValues = {
        TargetLockColorMode = "ShipColorId",
        TargetLockDisplayName = "true"
    }
}

ConfigManager.GetPlayerName = function(player_color)
    local player = Player[player_color]
    return "[" .. Color.fromString(player.color):toHex(false) .. "]" .. player.steam_name .. "[-]"
end

ConfigManager.GetConfig = function(player_color, param_name)
    if ConfigManager.PlayerConfigs[player_color] then
        return ConfigManager.PlayerConfigs[player_color][param_name] or ConfigManager.DefaultValues[param_name]
    end
    return ConfigManager.DefaultValues[param_name] or nil
end

ConfigManager.SetConfig = function(player_color, param_name, value)
    if value then
        if ConfigManager.PlayerConfigs[player_color] == nil then
            ConfigManager.PlayerConfigs[player_color] = {}
        end
        ConfigManager.PlayerConfigs[player_color][param_name] = value
        printToAll( ConfigManager.GetPlayerName(player_color) .. " changed " .. param_name .. " configuration to " .. tostring(value), color(0.1, 1, 1))
        if ConfigManager.SetCallbacks[param_name] ~= nil then
            ConfigManager.SetCallbacks[param_name](player_color, value)
        end
    end
end

return ConfigManager

end)
__bundle_register("Player.ContextGui", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by Eirik 'Flippster' Munthe
-- Issues, history at: https://github.com/JohnnyCheese/TTS_X-Wing2.0
--
-- Module for handling object mouse over and contextual gui menus
-- ~~~~~~
local EventSub = require("TTS_Lib.EventSub.EventSub")

ContextGui = {}

ContextGui.playerTable = {}

ContextGui.onTimout = function(player_color, hovered_object)
    local prev_object = ContextGui.playerTable[player_color].context_object
    if prev_object ~= nil and prev_object.getVar("onContextClose") ~= nil then
        prev_object.call("onContextClose")
    end
    if hovered_object.getVar("onContextOpen") ~= nil then
        hovered_object.call("onContextOpen", player_color)
        ContextGui.playerTable[player_color].context_object = hovered_object
    end
end

ContextGui.onObjectHover = function(player_color, hovered_object)
    if ContextGui.playerTable[player_color] == nil then
        ContextGui.playerTable[player_color] = {}
    end
    local prev_object = ContextGui.playerTable[player_color].hover_object
    ContextGui.playerTable[player_color].hover_object = hovered_object
    if ContextGui.playerTable[player_color].timerid ~= nil then
        Wait.stop(ContextGui.playerTable[player_color].timerid)
    end
    if (prev_object ~= nil) and (prev_object.getVar("onHoverLeave") ~= nil) then
        prev_object.call("onHoverLeave", player_color)
    end
    if hovered_object ~= nil then
        if (hovered_object.getVar("onContextOpen") ~= nil) then
            ContextGui.playerTable[player_color].timerid = Wait.time(
                function() ContextGui.onTimout(player_color, hovered_object) end, 1)
        end
        if (hovered_object.getVar("onHoverEnter") ~= nil) then
            hovered_object.call("onHoverEnter", player_color)
        end
    end
end

EventSub.Register('onObjectHover', ContextGui.onObjectHover)

return ContextGui

end)
__bundle_register("Ship.ShipVerification", function(require, _LOADED, __bundle_register, __bundle_modules)
local Dim = require("Dim")

ShipVerification = {}

ShipVerification.colliders = {
    small =
    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Small_base_Collider.obj',
    medium =
    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Medium_base_Collider.obj',
    large =
    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Large_base_Collider.obj',
    huge =
    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/colliders/Huge_base_Collider.obj'
}

ShipVerification.VerifyShipBase = function(ship)
    if ship.getScale() ~= Dim.mm_ship_scale then
        printToAll("Ship " .. ship.getName() .. " has wrong scale, don't scale the ships please!", color(1, 0.2, 0.2))
        ship.setScale(Dim.mm_ship_scale)
    end
    local size = ship.getTable("Data").Size
    if size == nil then
        printToAll("Ship " .. ship.getName() .. " does not have size data! Please spawn a proper ship", color(1, 0.2, 0.2))
        return false
    else
        if ship.getCustomObject().collider ~= ShipVerification.colliders[size] then
            printToAll("Ship " .. ship.getName() .. " does not have proper collission data! Please spawn a proper ship", color(1, 0.2, 0.2))
            return false
        end
    end
    return true
end

return ShipVerification

end)
__bundle_register("Ship.ShipProxy", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by Eirik 'Flippster' Munthe
-- Issues, history at: https://github.com/JohnnyCheese/TTS_X-Wing2.0
--
-- Module for handling ship proxies, used in barrel rolls and more
-- ~~~~~~
local Dim = require("Dim")
local EventSub = require("TTS_Lib.EventSub.EventSub")
local AnnModule = require("Player.Announcements")

local ShipProxyInstance = {
    state        = nil,
    proxy_table  = {},
    proxy_status = {},
}

function ShipProxyInstance:new()
    o = {}
    setmetatable(o, self)
    self.__index = self

    self.state = "init"
    return o
end

function ShipProxyInstance:setActive()
    self.state = "active"
end

function ShipProxyInstance:ready()
    if not self.proxy_table then return false end

    for _, proxy in pairs(self.proxy_table) do
        if proxy.getGUID() ~= "" then return true end
    end

    return false
end

function ShipProxyInstance:add(position, proxy)
    if not proxy then
        return
    end

    self.proxy_table[position] = proxy
end

function ShipProxyInstance:destroy()
    self.state = "term"

    for position, proxy in pairs(self.proxy_table) do
        proxy.destruct()
        self.proxy_table[position] = nil
    end
end

ShipProxyModule = {}
ShipProxyModule.proxyTable = {}
ShipProxyModule.hiddenShips = {}
ShipProxyModule.finalPosOffset = {
    small = Vector(0, 0, Dim.Convert_mm_igu(10)),
    medium = Vector(0, 0, Dim.Convert_mm_igu(20)),
    large = Vector(0, 0, Dim.Convert_mm_igu(20))
}

ShipProxyModule.barrelRollOffset = {}
ShipProxyModule.barrelRollOffset = {
    small = Vector(Dim.Convert_mm_igu(80), 0, 0),
    medium = Vector(Dim.Convert_mm_igu(80), 0, 0),
    large = Vector(Dim.Convert_mm_igu(100), 0, 0)
}

ShipProxyModule.proxyXmlGui = {}
ShipProxyModule.proxyXmlGui.markShip = [[
<Defaults>
    <Button class="InvisibleButton" color="#22222255" outline="#BBBBBB" outlineSize="2 2" fontSize="22" textColor="#FFFFFF" fontStyle="Bold"/>
</Defaults>
<Panel id="Center"
    width="200"
    height="200"
    position="0 0 -20"
    rotation="0 0 180"
    color="#aaffaa00"
    onMouseExit="hideBtn"
    active="false">

    <Button id="Select" class="InvisibleButton" offsetXY="0 0" width="225" height="225" active="true" onClick="select">
    </Button>
</Panel>

]]
ShipProxyModule.proxyXmlGui.finalPos = [[
<Defaults>
    <Button class="InvisibleButton" color="#22222255" outline="#BBBBBB" outlineSize="2 2" fontSize="22" textColor="#FFFFFF" fontStyle="Bold"/>
</Defaults>
<Panel id="Center"
    width="200"
    height="200"
    position="0 0 -20"
    rotation="0 0 180"
    color="#aaffaa00"
    onMouseExit="hideBtn"
    active="false">

    <Button id="Select" class="InvisibleButton" offsetXY="0 0" width="225" height="225" active="true" onClick="select">
    </Button>
</Panel>

]]


ShipProxyModule.proxyScripts = {}
ShipProxyModule.proxyScripts.markShip = [[

sizeScale = {
    small = {width = 1, height = 1},
    medium = {width = 1.5, height = 1.5},
    large = {width = 2.0, height = 2.0},
    huge = {width = 2.0, height = 5}
}

function onLoad(save_state)
    self.AddContextMenuItem("Return ship", function() Global.call("UnMarkShip", {shipGUID = self.getVar("shipGUID"), proxy = self})
end, false)
end

function onContextOpen(player)
    self.UI.setAttribute("Select", "width", tostring(225 * sizeScale[self.getVar("size")].width))
    self.UI.setAttribute("Select", "height", tostring(225 * sizeScale[self.getVar("size")].height))
    self.UI.show("Center")
end

function select(player)
    Global.call("UnMarkShip", {shipGUID = self.getVar("shipGUID"), proxy = self})
end
]]

ShipProxyModule.proxyScripts.finalPos = [[

sizeScale = {
    small = {width = 1, height = 1},
    medium = {width = 1.5, height = 1.5},
    large = {width = 2.0, height = 2.0},
    huge = {width = 2.0, height = 5}
}

function onLoad(save_state)

end

function onHoverEnter(player)
    self.UI.setAttribute("Select", "width", tostring(225 * sizeScale[self.getVar("size")].width))
    self.UI.setAttribute("Select", "height", tostring(225 * sizeScale[self.getVar("size")].height))
    self.UI.show("Center")
    self.setColorTint(hoverColor)
end

function onHoverLeave(player)
    self.UI.hide("Center")
    self.setColorTint(defaultColor)
end

function select(player)
    Global.call("SelectFinalPos", {shipGUID = shipGUID, proxy = self, move_code = move_code})
end
]]

function MarkShip(args)
    local finpos = { pos = args.ship.getPosition(), rot = args.ship.getRotation() }
    local proxy = ShipProxyModule.spawnProxy(args.ship, true, finpos, false, "markShip")

    ShipProxyModule.proxyTable[args.ship.getGUID()] = ShipProxyModule.proxyTable[args.ship.getGUID()] or {}
    table.insert(ShipProxyModule.proxyTable[args.ship.getGUID()], proxy)
end

function UnMarkShip(args)
    local pos = ShipProxyModule.hiddenShips[args.shipGUID]
    local ship = getObjectFromGUID(args.shipGUID)
    if pos ~= nil and ship ~= nil then
        ship.setPosition(pos)
        ship.interactable = true
        ShipProxyModule.hiddenShips[args.shipGUID] = nil
    end
    DeleteShipProxies({ ship_guid = args.shipGUID })
    ShipProxyModule.proxyTable[args.shipGUID] = nil;
end

function StartBarrelRoll(args)
    local ship = args.ship
    local direction = args.direction
    local code = ''
    if direction == "right" then
        code = 'rr'
    elseif direction == "left" then
        code = 'rl'
    end
    local offsets = { code .. '1', code .. '2', code .. '3' }

    local collide = true
    for _, v in ipairs(offsets) do
        local proxy, result = ShipProxyModule.CreateMoveProxy(v, ship)
        if result ~= 'overlap' then
            collide = false
        end

        if proxy then
            ShipProxyModule.proxyTable[args.ship.getGUID()] = ShipProxyModule.proxyTable[args.ship.getGUID()] or {}
            table.insert(ShipProxyModule.proxyTable[args.ship.getGUID()], proxy)
        end
    end

    if collide then
        local info = MoveData.DecodeInfo(code, ship)
        local annInfo = { type = 'overlap', note = info.collNote, code = info.code }
        AnnModule.Announce(annInfo, 'all', ship)
    end
end

local function executeFailure(move_code, ship, finType)
    if finType == 'overlap' then
        local info = MoveData.DecodeInfo(move_code:sub(1, -2), ship)
        local annInfo = { type = 'overlap', note = info.collNote, code = info.code }
        AnnModule.Announce(annInfo, 'all', ship)

        return
    end

    MoveModule.PerformMove(move_code, ship)
end

function SpawnProxyOptions(args)
    local ship          = getObjectFromGUID(args.ship_guid)
    local move_codes    = args.move_codes or {}
    local base_position = args.base_position or 'center'

    local ok = nil
    local finType = nil
    local ship_proxies  = ShipProxyInstance:new()
    for position, move_code in pairs(move_codes) do
        local proxy, finPos = ShipProxyModule.CreateMoveProxy(move_code, ship)
        if finPos.finType == 'move' and finPos.finPart == 'max' then
            ok = true
        else
            finType = finPos.finType
        end

        ship_proxies:add(position, proxy)
    end

    if not ok then
        executeFailure(move_codes[base_position], ship, finType)

        return nil, false
    end

    Wait.condition(function() ship_proxies:setActive() end, function() return ship_proxies:ready() end)

    ShipProxyModule.proxyTable[ship.getGUID()] = ShipProxyModule.proxyTable[ship.getGUID()] or {}
    table.insert(ShipProxyModule.proxyTable[ship.getGUID()], ship_proxies)
    return ship_proxies, true
end

ShipProxyModule.CreateMoveProxy = function(move_code, ship)
    local info = MoveData.DecodeInfo(move_code, ship)
    local finalPos = MoveModule.GetFinalPosData(move_code, ship)

    if finalPos.finType == 'overlap' then
        return nil, finalPos
    end
    if finalPos.finPart ~= 'max' then
        return nil, finalPos
    end

    local templateData = {
        origin = ship.getPosition(),
        orientation = ship.getRotation(),
        dir = info.dir,
        speed = info.speed,
        type = info.type,
        shipSize = info.size,
        extra = info.extra
    }

    local collisions = MoveModule.CheckMineAndObstacleCollisions(ship, finalPos.finPos, false, templateData)

    local didCollide = false
    if collisions[1] ~= nil then
        didCollide = true
    end

    local proxy = ShipProxyModule.spawnProxy(ship, false, finalPos.finPos, didCollide, "finalPos", move_code)
    return proxy, finalPos
end

function SelectFinalPos(args)
    local ship = getObjectFromGUID(args.shipGUID)
    local move_code = args.move_code
    MoveModule.PerformMove(move_code, ship)

    DeleteShipProxies({ ship_guid = args.shipGUID })
end

ShipProxyModule.StartFinalPositionSelection = function(ship, positionOffset)
    local size = ship.getTable('Data').Size or "small"
    local offset = ShipProxyModule.finalPosOffset[size]
    for _, off in pairs({ offset, vector(0, 0, 0), vector(0, 0, 0) - offset }) do
        ShipProxyModule.spawnProxy(ship, false, positionOffset + off, color(0, 0.1, 1, 0.2), "finalPos")
    end
end

function DeleteShipProxies(args)
    local ship_guid = args.ship_guid

    for _ = 1, table.size(ShipProxyModule.proxyTable[ship_guid]) do
        local proxy = table.remove(ShipProxyModule.proxyTable[ship_guid])
        if proxy.destroy then
            proxy:destroy()
        else
            proxy.destruct()
        end
    end
end

ShipProxyModule.proxyModels = {
    collider = {
        small =
        '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/colliders/Small_base_proxy_collider.obj',
        medium =
        '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/colliders/Medium_base_proxy_collider.obj',
        large =
        '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/colliders/Large_base_proxy_collider.obj',
        huge =
        '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/colliders/Huge_base_proxy_collider.obj'
    },
    model = {
        small = '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/ships/proxy/small.obj',
        medium = '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/ships/proxy/medium.obj',
        large = '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/ships/proxy/large.obj',
        huge = '{verifycache}https://github.com/JohnnyCheese/TTS_X-Wing2.0/raw/master/assets/ships/proxy/huge.obj',
    },
}

ShipProxyModule.spawnProxy = function(ship, hide, finpos, didCollide, script, move_code)
    if hide and ShipProxyModule.hiddenShips[ship.getGUID()] ~= nil then
        return
    end

    local proxy = spawnObject({
        type         = "Custom_Model",
        position     = finpos.pos,
        rotation     = finpos.rot,
        scale        = ship.getScale(),
        sound        = false,
        snap_to_grid = false,
    })
    local size = ship.getTable("Data").Size or 'small'
    proxy.setCustomObject({
        type = 0,
        material = 3,
        collider = ShipProxyModule.proxyModels.collider[size],
        mesh = ShipProxyModule.proxyModels.model[size],
    })
    proxy.addTag("ProxyInstance")

    local defaultColor = {}
    local hoverColor = {}
    if didCollide then
        defaultColor = color(1.0, 0.3, 0.3, 0.1)
        hoverColor = color(1.0, 1.0, 0.5, 0.5)
    else
        defaultColor = color(0.3, 0.3, 1.0, 0.1)
        hoverColor = color(0.5, 1.0, 0.5, 0.5)
    end
    proxy.setColorTint(defaultColor)
    proxy.setTable("defaultColor", defaultColor)
    proxy.setTable("hoverColor", hoverColor)

    proxy.setLock(true)
    proxy.setLuaScript(ShipProxyModule.proxyScripts[script])
    proxy.UI.setXml(ShipProxyModule.proxyXmlGui[script])
    proxy.setVar("shipGUID", ship.getGUID())
    proxy.setVar("size", size)
    proxy.setVar("move_code", move_code)

    if hide then
        ShipProxyModule.hiddenShips[ship.getGUID()] = ship.getPosition()
        ship.setPosition(vector(0, -3, 0))
        ship.interactable = false
        ship.setLock(true)
        local playerColors = getSelectingPlayers(ship)
        for _, player in ipairs(playerColors) do
            ship.removeFromPlayerSelection(player)
        end
    end

    return proxy
end

ShipProxyModule.onLoad = function()
    for _, obj in pairs(getAllObjects()) do
        if obj.hasTag("ProxyInstance") then
            destroyObject(obj)
        end
    end
end

EventSub.Register('onLoad', ShipProxyModule.onLoad)

return ShipProxyInstance

end)
__bundle_register("Game.Mechanic.ArcCheck", function(require, _LOADED, __bundle_register, __bundle_modules)
local ObjectiveTokenData = require("Marker.Scenario.ObjectiveTokenData")
local Vect = require("TTS_Lib.Vector.Vector")
local Dim = require("Dim")

ArcCheck = {}
ArcCheck.initialized = false
ArcCheck.arc_check_rulers = {}
ArcCheck.current_arc = "none"

ArcCheck.model_cache = {}

ArcCheck.arc_line_segments = {}
ArcCheck.arc_line_segments.small = {}
ArcCheck.arc_line_segments.medium = {}
ArcCheck.arc_line_segments.large = {}
ArcCheck.arc_line_segments.huge = {}
ArcCheck.arc_line_segments.objective = {}

ArcCheck.bullseye_data = {
    pos = {
        small = Vector(0, 0, Dim.Convert_mm_igu(170)),
        medium = Vector(0, 0, Dim.Convert_mm_igu(180)),
        large = Vector(0, 0, Dim.Convert_mm_igu(190)),
        huge = Vector(0, 0, Dim.Convert_mm_igu(110.5)),
        objective = nil
    },
    size = Vector(Dim.Convert_mm_igu(14), 0.1, Dim.Convert_mm_igu(300))
}

ArcCheck.Initialize = function()
    -- Arc values based on Muon's assessments (vassal)
    if ArcCheck.initialized == false then
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.small, 81.24, 20, 20)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.medium, 82.8, 30, 30)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.large, 83.52, 40, 40)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.huge, 82.9, 40, 110.5)
        ArcCheck.arc_line_segments.objective = ObjectiveTokenData.arc_line_segments
        ArcCheck.initialized = true
    end
end

--[[ArcCheck.Initialize = function() -- Arc values matching TTS ruler objects
    if ArcCheck.initialized == false then
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.small, 79.1, 20, 20)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.medium, 82.35, 30, 30)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.large, 82.9, 40, 40)
        ArcCheck.CalculateArcLineSegments(ArcCheck.arc_line_segments.huge, 82.9, 40, 110.5 )
        ArcCheck.initialized = true
    end
end]]


ArcCheck.CalculateArcLineSegments = function(table, degree, size_w, size_l)
    size_w = Dim.Convert_mm_igu(size_w)
    size_l = Dim.Convert_mm_igu(size_l)
    local edge_arc = Vect.AngleDeg2D({ -size_w, 0, size_l }, { size_w, 0, size_l })
    --print("Size_W:" .. tostring(size_w) .. " size_l:"..size_l .. " edge_arc=".. tostring(edge_arc))
    if size_w == size_l then
        -- Rectangular base sizes (small, medium and large ships)
        --print("Rectangular:".. tostring(size_w)..","..tostring(size_l))
        local r = math.rad(degree / 2)
        local a = math.tan(r) * size_l
        table.front = {
            segments = { { Vector(-a, 0, size_l), Vector(a, 0, size_l) } }, -- Front segment
            degrees = { direction = 0, spread = degree / 2 }
        }
        table.back = {
            segments = { { Vector(-a, 0, -size_l), Vector(a, 0, -size_l) } }, -- Front segment
            degrees = { direction = 180, spread = degree / 2 }
        }
        table.left = {
            segments = { { Vector(-a, 0, -size_l), Vector(-size_w, 0, -size_l) }, -- back segment
                { Vector(-size_w, 0, -size_l), Vector(-size_w, 0, size_l) },      -- left edge
                { Vector(-size_w, 0, size_l),  Vector(-a, 0, size_l) }            -- front segment
            },
            degrees = { direction = -90, spread = (180 - degree) / 2 }
        }
        table.right = {
            segments = { { Vector(a, 0, -size_l), Vector(size_w, 0, -size_l) }, -- back segment
                { Vector(size_w, 0, -size_l), Vector(size_w, 0, size_l) },      -- right edge
                { Vector(size_w, 0, size_l),  Vector(a, 0, size_l) }            -- front segment
            },
            degrees = { direction = 90, spread = (180 - degree) / 2 }
        }
    else
        -- Long base size (huge ships)
        --print("Long:".. tostring(size_w)..","..tostring(size_l))
        local r = math.rad(90 - degree / 2)
        local a = math.tan(r) * size_w
        table.front = {
            segments = { { Vector(-size_w, 0, a), Vector(-size_w, 0, size_l) }, -- left segment
                { Vector(-size_w, 0, size_l), Vector(size_w, 0, size_l) },      -- front edge
                { Vector(size_w, 0, size_l),  Vector(size_w, 0, a) } },         -- right segment
            degrees = { direction = 0, spread = degree / 2 }
        }
        table.back = {
            segments = { { Vector(-size_w, 0, -a), Vector(-size_w, 0, -size_l) }, -- left segment
                { Vector(-size_w, 0, -size_l), Vector(size_w, 0, -size_l) },      -- back edge
                { Vector(size_w, 0, -size_l),  Vector(size_w, 0, -a) } },         -- right segment
            degrees = { direction = 180, spread = degree / 2 }
        }
        table.left = {
            segments = { { Vector(-size_w, 0, -a), Vector(-size_w, 0, a) } }, -- left segment
            degrees = { direction = -90, spread = (180 - degree) / 2 }
        }
        table.right = {
            segments = { { Vector(size_w, 0, -a), Vector(size_w, 0, a) } }, -- right segment
            degrees = { direction = 90, spread = (180 - degree) / 2 }
        }
    end
    table.bullseye = {
        segments = { { Vector(-ArcCheck.bullseye_data.size[1] / 2, 0, size_l), Vector(ArcCheck.bullseye_data.size[1] / 2, 0, size_l) } }, -- Bullseye segments
        degrees = { direction = 0, spread = 0, bullseye = true }
    }
    table.fullfront = {
        segments = { { Vector(-size_w, 0, 0), Vector(-size_w, 0, size_l) }, -- left segment
            { Vector(-size_w, 0, size_l), Vector(size_w, 0, size_l) },      -- front edge
            { Vector(size_w, 0, size_l),  Vector(size_w, 0, 0) }            -- right segment
        },
        degrees = { direction = 0, spread = 90 }
    }
    table.fullback = {
        segments = { { Vector(-size_w, 0, 0), Vector(-size_w, 0, -size_l) }, -- left segment
            { Vector(-size_w, 0, -size_l), Vector(size_w, 0, -size_l) },     -- back edge
            { Vector(size_w, 0, -size_l),  Vector(size_w, 0, 0) }            -- right segment
        },
        degrees = { direction = 180, spread = 90 }
    }
    table.full = {
        segments = { { Vector(-size_w, 0, size_l), Vector(size_w, 0, size_l) }, -- front edge
            { Vector(size_w, 0, size_l),   Vector(size_w, 0, -size_l) },        -- right edge
            { Vector(size_w, 0, -size_l),  Vector(-size_w, 0, -size_l) },       -- back edge
            { Vector(-size_w, 0, -size_l), Vector(-size_w, 0, size_l) }         -- left edge
        },
        degrees = { direction = 0, spread = 180 }
    }
end

function ArcCheck.CheckArc(args)
    -- Remove player selection to prevent accidental deletion.
    local playerColors = getSelectingPlayers(args.ship)
    for _, player in ipairs(playerColors) do
        args.ship.removeFromPlayerSelection(player.color)
    end

    range = args.range or 3
    -- Iterate over the potential targets and display their statuses.
    local spawnedRulers = {}
    if args.arctype ~= "full" then
        printToAll(args.ship.getName() .. ' checks for targets in the ' .. args.arctype .. ' arc:', Color(1.0, 1.0, 0.2, 0.9))
    end
    targets = ArcCheck.GetTargetsInRelationToArc(args.ship, args.arctype, nil, range, args.include_friendly_ships)

    table.sort(targets, ArcCheck.SortTargetsByDesirability)
    local found = false
    for _, target in pairs(targets) do
        ship = target.ship
        if target.in_arc == false then
            printToAll(' - ' .. ship.getName() .. ' not in arc')
        elseif target.closest.range > range then
            printToAll(' - ' .. ship.getName() .. ' not in range (' .. range .. ')')
        else
            found = true
            ship.setLock(true)
            table.insert(spawnedRulers, ArcCheck.SpawnObstructionRuler(target.closest))
            if target.other_closest ~= nil then
                table.insert(spawnedRulers, ArcCheck.SpawnObstructionRuler(target.other_closest))
            end

            if args.arctype == "full" then
                printToAll(" - " .. ship.getName() .. " in range", Color(1.0, 1.0, 0.2, 0.9))
            else
                obstructedtext = ' is'
                if (target.obstructed == 'likely_unobstructed') then
                    obstructedtext = ' is most likely UNOBSTRUCTED'
                elseif (target.obstructed == 'obstructed') then
                    obstructedtext = ' is OBSTRUCTED'
                elseif (target.obstructed == 'likely_obstructed') then
                    obstructedtext = ' is most likely OBSTRUCTED'
                elseif (target.obstructed == 'chosen_obstructed') then
                    obstructedtext = ' can be chosen to be OBSTRUCTED'
                end

                multipletext = ''
                if target.multiple_points == true then
                    multipletext = ' has multiple closest points and'
                end

                bullseyetext = ''
                if target.bullseye == true then
                    bullseyetext = ' in bullseye'
                end
                printToAll( " - " ..  ship.getName() ..  multipletext .. obstructedtext ..
                    ' at range ' .. tostring(target.closest.range) .. bullseyetext, Color(1.0, 1.0, 0.2, 0.9))
            end
        end
    end

    if found == false then
        printToAll(' - No valid targets', Color(1.0, 1.0, 0.2, 0.9))
    end
    return spawnedRulers
end

--[[ GetTargetsInRelationToArc
This function returns a table containing all non-friendly ships within 900mm and
information based on the provided arc type for each one.

ship: TTS Object, the ship whose arc will be tested.
arc: Table or String. The arc/s of the ship being tested. If a string, it is an
    arc description such as 'front', 'bullseye', etc. See DataPad for full list.
    If a table, it is a list of arc descriptions. Note that a single string
    is expanded (so "frontback" becomes "front", "back"), but table entries are
    not.
fixed_targets: [optional]A list of TTS Objects, if passed in these are the only
    ships that will be checked.

returns a table of targets, each containing the following:
    ship: TTS Object, the ship being targetted
    bullseye: Boolean, true if the target is in the ship's bullseye
    closest: Table, the closest points and the range between the ship and the
        target. See ArcCheck.GetDistanceBetweenLineSegments
    in_arc: Boolean, true if the target is in the specified arc.
    obstructed: String, the state of the obstruction between the ship and the
        target. One of:
        - 'unobstructed' (no obstruction)
        - 'obstructed' (definite obstruction)
        - 'likely_unobstructed' (multiple points, but none are obstructed)
        - 'likely_obstructed' (multiple points, but both are obstructed)
        - 'chosen_obstructed' (multiple points, but only one is obstructed)
    multiple_points: Boolean, true if there is more than one closest point.
        This occurs when the two ships have the same rotation. I this is true,
        then 'other_closest' will be non-nil.
    other_closest: Table, the other closest point. See 'closest' and
        'multiple_points'. This is nil if only one closest point.
--]]
ArcCheck.GetTargetsInRelationToArc = function(ship, arc, fixed_targets, range, include_friendly_ships)
    if ArcCheck.initialized == false then
        ArcCheck.Initialize()
    end

    range = range or 3
    local arc_parts = {}
    local arc_table = {}
    if type(arc) == 'string' then
        arc_table = { arc }
    else
        arc_table = arc;
    end
    for _, arc in pairs(arc_table) do
        if arc == "frontback" then
            table.insert(arc_parts, "front")
            table.insert(arc_parts, "back")
        elseif arc == "leftright" then
            table.insert(arc_parts, "left")
            table.insert(arc_parts, "right")
        elseif arc == "all" then
            table.insert(arc_parts, "front")
            table.insert(arc_parts, "back")
            table.insert(arc_parts, "left")
            table.insert(arc_parts, "right")
        else
            table.insert(arc_parts, arc)
        end
    end
    ship.setLock(true)
    local shipSize = ship.getTable("Data").Size or 'small'

    local potential_targets = fixed_targets or
        ArcCheck.GetPotentialTargets(ship, (range + 1) * 250, true, include_friendly_ships or false)
    local bullseye_targets = ArcCheck.GetBullseyeTargets(ship, ArcCheck.bullseye_data.pos[shipSize])

    local own_line_segments = {}
    for _, arc in ipairs(arc_parts) do
        local segments = ArcCheck.GetOwnArcLineSegments(ship, ArcCheck.arc_line_segments[shipSize][arc]["segments"])
        for _, segment in ipairs(segments) do
            table.insert(own_line_segments, segment)
        end
    end

    targets = {}
    local found = false
    for _, pt in pairs(potential_targets) do
        target = { ['ship'] = pt, ['bullseye'] = false }
        for _, bt in pairs(bullseye_targets) do
            if bt == pt then
                target.bullseye = true
            end
        end
        local target_line_segments = {}
        for _, arc in ipairs(arc_parts) do
            local segments = ArcCheck.GetTargetLineSegmentsInArc(ship, pt,
                ArcCheck.arc_line_segments[shipSize][arc]["degrees"])
            for _, segment in ipairs(segments) do
                table.insert(target_line_segments, segment)
            end
        end

        if #target_line_segments ~= 0 then
            local other = nil
            local closest = nil
            closest, other = ArcCheck.GetDistanceBetweenLineSegments(own_line_segments, target_line_segments)
            target.in_arc = true
            target.obstructed = 'unobstructed'
            target.closest = closest
            target.multiple_points = false

            if closest.range <= range then
                found = true
                target.closest.obstructions = ArcCheck.CheckObstruction(closest, target.ship, ship)
                target.closest.in_bullseye = target.bullseye
                if other ~= nil then
                    target.obstructed = 'likely_unobstructed'
                    target.multiple_points = true

                    other.obstructions = ArcCheck.CheckObstruction(other, target.ship, ship)
                    other.in_bullseye = target.bullseye
                    target.other_closest = other
                end

                if #closest.obstructions ~= 0 then
                    if other ~= nil then
                        if #other.obstructions ~= 0 then
                            target.obstructed = 'likely_obstructed'
                        else
                            target.obstructed = 'chosen_obstructed'
                        end
                    else
                        target.obstructed = 'obstructed'
                    end
                else
                    if other ~= nil and #other.obstructions ~= 0 then
                        target.obstructed = 'chosen_obstructed'
                    end
                end
            end
        else
            target.in_arc = false
        end

        table.insert(targets, target)
    end
    if found == false then
        ArcCheck.current_arc = "none"
    end

    return targets
end

--[[ ArcCheck.SortTargetsByDesirability
This is a table sorting function, used to sort the results of
GetTargetsInRelationToArc. It sorts based on desirability of selecting a target,
in the following order:
- in arc before out of arc
- closer range band before more distant range band
- less obstructed before more obstructed
- GUID as a fallback
--]]
ArcCheck.SortTargetsByDesirability = function(e1, e2)
    if e1.in_arc == true and e2.in_arc == false then
        return true
    elseif e1.in_arc == false and e2.in_arc == true then
        return false
    elseif e1.in_arc == true then
        if e1.closest.range < e2.closest.range then
            return true
        elseif e1.closest.range > e2.closest.range then
            return false
        end

        -- Gotta be a better way of doing this...
        if e1.obstructed ~= e2.obstructed then
            if e1.obstructed == 'unobstructed' then
                return true
            elseif e2.obstructed == 'unobstructed' then
                return false
            end

            if e1.obstructed == 'likely_unobstructed' then
                return true
            elseif e2.obstructed == 'likely_unobstructed' then
                return false
            end

            if e1.obstructed == 'chosen_obstructed' then
                return true
            elseif e2.obstructed == 'chosen_obstructed' then
                return false
            end

            if e1.obstructed == 'likely_obstructed' then
                return true
            elseif e2.obstructed == 'likely_obstructed' then
                return false
            end

            if e1.obstructed == 'obstructed' then
                return true
            elseif e2.obstructed == 'obstructed' then
                return false
            end
        end
    end

    return e1.ship.getGUID() > e2.ship.getGUID()
end

ArcCheck.CheckObstruction = function(data, ship, ownship)
    local collissions = Physics.cast({
        origin = data.midpoint,
        orientation = { 0, data.angle, 0 },
        direction = { 0, -0.3, 0 },
        type = 3,
        size = { 0, 0, data.length },
        max_distance = 3,
        debug = false
    })
    local hit_obstacles = {}
    for _, hit in pairs(collissions) do
        if (hit.hit_object ~= ship) and (hit.hit_object ~= ownship) and (MoveModule.SelectObstacles(hit.hit_object) or MoveModule.SelectHugeShips(hit.hit_object)) then
            table.insert(hit_obstacles, hit.hit_object)
        end
    end
    return hit_obstacles;
end

ArcCheck.SpawnObstructionRuler = function(data)
    if data.range > 0 then
        if not (ArcCheck.model_cache["ArcCheckRuler" .. data.range]) then
            ArcCheck.model_cache["ArcCheckRuler" .. data.range] = spawnObject({
                type = "Custom_Model",
                position = { 0, -1.21, 0 },
                rotation = { 0, 0, 0 },
                scale = { 0.363, 0.363, 0.5 },
                sound = false,
                snap_to_grid = false
            })
            ArcCheck.model_cache["ArcCheckRuler" .. data.range].setCustomObject({
                mesh =
                    '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/ArcCheckRuler' ..
                    data.range .. '.obj',
                material = 3
            })
            ArcCheck.model_cache["ArcCheckRuler" .. data.range].addTag('TempLayoutElement')
            ArcCheck.model_cache["ArcCheckRuler" .. data.range].interactable = false
            ArcCheck.model_cache["ArcCheckRuler" .. data.range].setLock(true)
        end
        ruler = ArcCheck.model_cache["ArcCheckRuler" .. data.range].clone()
        ruler.setRotation({ 0, data.angle + 90, 0 })
        ruler.setPosition(Vector(data.A[1], 1.21, data.A[3]))
        local tintcolor = Color(1.0, 1.0, 0.2, 1.0) -- Yellow obstructed tint
        if #data.obstructions == 0 then
            if data.in_bullseye then
                tintcolor = Color(1.0, 0.2, 1.0, 1.0) -- Purple unobstructed bullseye tint
            else
                tintcolor = Color(0.2, 0.2, 1.0, 1.0) -- Blue unobstructed tint
            end
        else
            if data.in_bullseye then
                tintcolor = Color(1.0, 0.2, 0.0, 1.0) -- orange obstructed bullseye tint
            else
                tintcolor = Color(1.0, 1.0, 0.2, 1.0) -- yellow obstructed tint
            end
        end

        ruler.setColorTint(tintcolor)
        ruler.setLock(true)
        local rigid = ruler.getComponent("Rigidbody")
        rigid.set("isKinematic", true)
        rigid.set("detectCollisions", false)
        return ruler
        --table.insert(ArcCheck.arc_check_rulers, ruler)
    end
end


-- Calculates closest distance between two set of line segments. Returns table with range, and line points
ArcCheck.GetDistanceBetweenLineSegments = function(own_line_segments, target_line_segments)
    local closest = {
        length = 10000,
        range = 0,
        midpoint = { 0, 0, 0 },
        angle = 0,
        A = { 0, 0, 0 },
        B = { 0, 0, 0 }
    }
    local other = nil
    local epsilon = 0.001 -- This to dumb down the mathematical accuracy to match the analog game experience
    for _, seg_o in pairs(own_line_segments) do
        for _, seg_t in pairs(target_line_segments) do
            for _, point in pairs(seg_t) do
                local distance = ArcCheck.GetDistanceBetweenLineSegmentAndPoint(seg_o, point, false)
                if not ArcCheck.CheckEqualLineSegments(distance.A, distance.B, closest.A, closest.B) then
                    if (distance.length <= (closest.length + epsilon)) then
                        if math.abs(distance.length - closest.length) < epsilon then
                            --print("Real close: " .. tostring(distance.length).. " - " .. tostring(distance.length - closest.length))
                            if distance.length < closest.length then
                                other = closest
                                closest = distance
                            else
                                other = distance
                            end
                        else
                            --print("Closer: " .. tostring(distance.length) .. " - " .. tostring(distance.length - closest.length))
                            closest = distance
                            other = nil
                        end
                    end
                elseif distance.length < closest.length then
                    --print("Equal lines, and closer")
                    closest = distance
                    other = nil
                else
                    --print("Equal lines, farther")
                end
            end
            for _, point in pairs(seg_o) do
                local distance = ArcCheck.GetDistanceBetweenLineSegmentAndPoint(seg_t, point, true)
                if not ArcCheck.CheckEqualLineSegments(distance.A, distance.B, closest.A, closest.B) then
                    if (distance.length <= (closest.length + epsilon)) then
                        if math.abs(distance.length - closest.length) < epsilon then
                            --print("Real close2: " .. tostring(distance.length).. " - " .. tostring(distance.length - closest.length))
                            if distance.length < closest.length then
                                other = closest
                                closest = distance
                            else
                                other = distance
                            end
                        else
                            --print("Closer2: " .. tostring(distance.length) .. " - " .. tostring(distance.length - closest.length))
                            closest = distance
                            other = nil
                        end
                    end
                elseif distance.length < closest.length then
                    --print("Equal lines, and closer")
                    closest = distance
                    other = nil
                else
                    --print("Equal lines, farther")
                end
            end
        end
    end
    return closest, other
end

ArcCheck.GetAngleBetweenPoints = function(A, B, C)
    local BA = Vect.Between(B, A)
    local BC = Vect.Between(B, C)
    return Vect.AngleDeg(BA, BC)
end

ArcCheck.CheckEqualLineSegments = function(line1A, line1B, line2A, line2B)
    local epsilon = 0.02
    if Vect.Distance(line1A, line2A) < epsilon then
        return true
    elseif Vect.Distance(line1B, line2B) < epsilon then
        return true
    elseif Vect.Distance(line1A, line2B) < epsilon then
        return true
    elseif Vect.Distance(line1B, line2A) < epsilon then
        return true
    end
    return false
end


-- Gets the closest point on a line segment to a point
ArcCheck.GetDistanceBetweenLineSegmentAndPoint = function(segment, point, reverse)
    local P = {}
    -- Check if the angle at the first segment point is larger than 90 degrees, the point bust be it, and the endpoint will be closest point
    if (math.abs(ArcCheck.GetAngleBetweenPoints(segment[2], segment[1], point)) >= 90) then
        P = segment[1]
    elseif (math.abs(ArcCheck.GetAngleBetweenPoints(segment[1], segment[2], point)) >= 90) then
        -- Similarily for the second segment point
        P = segment[2]
    else
        -- The closest point is somewhere in between, along the normal of the line segment
        local u = Vect.ToUnit(Vect.Between(segment[1], segment[2]))
        local baseline_norm = Vector(-u[3], u[2], u[1])
        local d = Vect.DotProd(Vect.Between(point, segment[1]), baseline_norm)
        P = Vect.Sum(point, Vect.Scale(baseline_norm, d))
    end

    if reverse then
        A = point
        B = P
    else
        A = P
        B = point
    end
    local distance = Vect.Distance(P, point)
    local range = math.floor(Dim.Convert_igu_mm(distance / 100)) + 1

    local midpoint = Vect.Middle(A, B)
    midpoint[2] = 1.52

    local AB = Vect.Between(A, B)
    local angle = Vect.AngleDeg(AB, Vector(0, 0, 1))
    if AB[1] < 0 then
        angle = -angle
    end

    return {
        length = distance,
        A = A,
        B = B,
        range = range,
        midpoint = midpoint,
        angle = angle
    }
end

-- Returns list of line segments which are within a given arc type
ArcCheck.GetOwnArcLineSegments = function(ship, segments)
    local outsegments = {}
    for _, segment in pairs(segments) do
        table.insert(outsegments,
            { Vect.Sum(ship.getPosition(), Vect.RotateDeg(segment[1], ship.getRotation()[2] + 180)),
                Vect.Sum(ship.getPosition(), Vect.RotateDeg(segment[2], ship.getRotation()[2] + 180)) })
    end
    return outsegments
end

-- Finds all potential ships within a little more than range 3 from the ship
ArcCheck.GetPotentialTargets = function(ship, length, include_enemy_ships, include_friendly_ships)
    return ArcCheck.GetShipsWithinRange(ship, length, include_enemy_ships, include_friendly_ships)
end

-- Finds all targets in bullseye
ArcCheck.GetBullseyeTargets = function(ship, pos, length)
    if pos == nil then
        -- This is a non bullseye remote
        return {}
    end
    if length ~= nil then
        length = Dim.Convert_mm_igu(length)
    end
    local castSize = Vector(ArcCheck.bullseye_data.size[1], ArcCheck.bullseye_data.size[2],
        length or ArcCheck.bullseye_data.size[3])
    local collissions = Physics.cast({
        origin = Vect.Sum(ship.getPosition() + Vector(0, 0.1, 0), Vect.RotateDeg(pos, ship.getRotation()[2] + 180)),
        orientation = ship.getRotation(),
        direction = { 0, -0.03, 0 },
        type = 3,
        size = castSize,
        max_distance = 3,
        debug = false
    })
    local myOwningPlayer = ship.getVar("owningPlayer")
    local bullseye_targets = {}
    for _, hit in pairs(collissions) do
        if hit.hit_object.getGUID() ~= ship.getGUID() and MoveModule.SelectShipsAndRemotes(hit.hit_object) then
            if hit.hit_object.getVar("owningPlayer") ~= myOwningPlayer then
                -- remove false targets, where only the nub is hit
                if ArcCheck.VerifyBullseye(ship, hit.hit_object) then
                    table.insert(bullseye_targets, hit.hit_object)
                end
            end
        end
    end
    return bullseye_targets
end

ArcCheck.VerifyBullseye = function(ship, target)
    if MoveModule.SelectRemotes(target) then
        return true
    end
    local left = false
    local right = false
    local half_bullseye = (ArcCheck.bullseye_data.size[1] / 2)

    -- Translate target corners into ship object Space
    local size = Dim.Convert_mm_igu((Dim.mm_baseSize[target.getTable("Data").Size] / 2))
    local t_rotation = target.getRotation().y
    local s_rotation = ship.getRotation().y
    local target_corners = {}
    target_corners[1] = Vector(-size, 0, size)
    target_corners[2] = Vector(-size, 0, -size)
    target_corners[3] = Vector(size, 0, size)
    target_corners[4] = Vector(size, 0, -size)
    for _, target_corner in pairs(target_corners) do
        local world_corner = target_corner:rotateOver('y', t_rotation) + target.getPosition() - ship.getPosition()
        local local_corner = world_corner:rotateOver('y', -s_rotation)
        --print ("Local corner: " .. tostring(local_corner[1]) .. "," .. tostring(local_corner[2]) ..  "," .. tostring(local_corner[3]))
        if local_corner.x > -half_bullseye then
            right = true
        end
        if local_corner.x < half_bullseye then
            left = true
        end
        if left and right then
            return true
        end
    end
    return false
end


-- Finds friendly or enemy ships within a particular range
ArcCheck.GetShipsWithinRange = function(ship, range, include_enemy_ships, include_friendly_ships)
    range = range or 900
    if include_enemy_ships == nil then
        include_enemy_ships = true
    end
    if include_friendly_ships == nil then
        include_friendly_ships = false
    end

    local cast_radius = Dim.Convert_mm_igu(range)
    local collisions = Physics.cast({
        origin = ship.getPosition() + Vector(0, 0.1, 0),
        direction = { 0, -0.001, 0 },
        type = 2,
        size = { cast_radius, cast_radius, cast_radius },
        max_distance = 1,
        debug = false
    })

    local ship_owning_player = ship.getVar("owningPlayer")
    local potential_ships = {}
    for _, hit in pairs(collisions) do
        if hit.hit_object.getGUID() ~= ship.getGUID() and MoveModule.SelectShipsAndRemotes(hit.hit_object) then
            local is_enemy_ship = hit.hit_object.getVar("owningPlayer") ~= ship_owning_player
            if (include_enemy_ships and is_enemy_ship) or (include_friendly_ships and not is_enemy_ship) then
                table.insert(potential_ships, hit.hit_object)
            end
        end
    end

    return potential_ships
end

ArcCheck.GetDistanceBetweenShips = function(ship, target, arcs)
    local arcs = arcs or { 'front', 'back', 'left', 'right' }
    local ship_size = ship.getTable("Data").Size or 'small'

    local ship_line_segments = {}
    local target_line_segments = {}
    for _, arc in pairs(arcs) do
        local ship_segments = ArcCheck.GetOwnArcLineSegments(ship, ArcCheck.arc_line_segments[ship_size][arc]
            ["segments"])
        for _, ship_segment in pairs(ship_segments) do
            table.insert(ship_line_segments, ship_segment)
        end

        local target_segments = ArcCheck.GetTargetLineSegmentsInArc(ship, target,
            ArcCheck.arc_line_segments[ship_size][arc]["degrees"])
        for _, target_segment in pairs(target_segments) do
            table.insert(target_line_segments, target_segment)
        end
    end

    if #target_line_segments ~= 0 then
        local closest = nil
        closest, _ = ArcCheck.GetDistanceBetweenLineSegments(ship_line_segments, target_line_segments)
        return closest
    end

    return nil
end


-- Returns a list of line segments which are within the arc
ArcCheck.GetTargetLineSegmentsInArc = function(ship, target, arcinfo)
    local targetShipData = target.getTable("Data")
    -- Get the full line segments for the ship
    if targetShipData == nil then
        printToAll("Unable to get Data table for " .. ship.getName())
        return {}
    end
    local segments = ArcCheck.arc_line_segments[targetShipData.Size]["full"]["segments"]
    local outsegments = {}
    local arc_center_vector = Vect.RotateDeg(Vector(0, 0, -30), ship.getRotation()[2] + arcinfo.direction)
    --print("Arc_center_vector = " .. tostring(arc_center_vector[1]).."," .. tostring(arc_center_vector[2]) ..","..tostring(arc_center_vector[3]))
    if arcinfo.bullseye == nil then
        for _, segment in pairs(segments) do
            -- Calculate part of line segment within arc
            local rotated_segment = { Vect.Sum(target.getPosition(), Vect.RotateDeg(segment[1], target.getRotation()[2])),
                Vect.Sum(target.getPosition(), Vect.RotateDeg(segment[2], target.getRotation()[2])) }

            -- Check if points are in arc
            local angleoffsets = { Vect.AngleDeg(Vect.Between(ship.getPosition(), rotated_segment[1]), arc_center_vector),
                Vect.AngleDeg(Vect.Between(ship.getPosition(), rotated_segment[2]), arc_center_vector) }

            --print("Angle offsets: " .. target.getName() .. "[".. tostring(k) .. "] "..  tostring(angleoffsets[1]) .. " - " .. tostring(angleoffsets[2]) )

            if angleoffsets[1] < arcinfo.spread and angleoffsets[2] < arcinfo.spread then
                -- Both points are in arc
                --print("Both in arc")
                table.insert(outsegments, rotated_segment)
            elseif angleoffsets[1] > arcinfo.spread and angleoffsets[2] > arcinfo.spread then
                -- both outside
                if Vect.AngleDeg(Vect.Between(ship.getPosition(), Vect.Middle(rotated_segment[1], rotated_segment[2])), arc_center_vector) < arcinfo.spread then
                    -- print("Both out, in front. deg: " .. tostring(Vect.AngleDeg(Vect.Between(ship.getPosition(), Vect.Middle(rotated_segment[1], rotated_segment[2])), arc_center_vector)))
                    -- The target is infront, but both points are outside the arc.
                    local newsegment = { ArcCheck.GetLineLineIntersection(ship.getPosition(),
                        Vect.Sum(ship.getPosition(), Vect.RotateDeg(arc_center_vector, -arcinfo.spread))
                        , rotated_segment[1], rotated_segment[2]),
                        ArcCheck.GetLineLineIntersection(ship.getPosition(),
                            Vect.Sum(ship.getPosition(), Vect.RotateDeg(arc_center_vector, arcinfo.spread))
                            , rotated_segment[1], rotated_segment[2]) }
                    --print("Newsegment: ".. tostring(newsegment[1]) .. "," .. tostring(newsegment[2]))
                    table.insert(outsegments, newsegment)
                else
                    --print("Both out, behind")
                end
            else
                -- one inside, one out
                local p1 = rotated_segment[1]
                if (angleoffsets[1] > arcinfo.spread) then
                    p1 = rotated_segment[2]
                end
                local p2 = ArcCheck.GetLineLineIntersection(ship.getPosition(),
                    Vect.Sum(ship.getPosition(), Vect.RotateDeg(arc_center_vector, arcinfo.spread)), rotated_segment[1],
                    rotated_segment[2])
                if p2 == nil then
                    p2 = ArcCheck.GetLineLineIntersection(ship.getPosition(),
                        Vect.Sum(ship.getPosition(), Vect.RotateDeg(arc_center_vector, -arcinfo.spread)),
                        rotated_segment[1], rotated_segment[2])
                end
                if p2 ~= nil then
                    table.insert(outsegments, { p1, p2 })
                end
            end
        end
    else
        -- Special Bullseye handling
        local half_bullseye = ArcCheck.bullseye_data.size[1] / 2
        --print("\nBullseye check to: " ..target.getName() .. " half bullseye: " .. tostring(half_bullseye))
        for _, segment in pairs(segments) do
            local rotated_segment = { Vect.Sum(target.getPosition(), Vect.RotateDeg(segment[1], target.getRotation()[2])),
                Vect.Sum(target.getPosition(), Vect.RotateDeg(segment[2], target.getRotation()[2])) }
            local ownship_oriented_segment = { Vect.RotateDeg(Vect.Between(ship.getPosition(), rotated_segment[1]),
                -ship.getRotation()[2]),
                Vect.RotateDeg(Vect.Between(ship.getPosition(), rotated_segment[2]), -ship.getRotation()[2]) }
            local x1 = math.min(ownship_oriented_segment[1][1], ownship_oriented_segment[2][1])
            local x2 = math.max(ownship_oriented_segment[1][1], ownship_oriented_segment[2][1])
            --print("x1:" .. tostring(x1) .. " x2:" .. tostring(x2))
            --print("ownship_oriented_segment[1][3]:" .. tostring(ownship_oriented_segment[1][3]))
            if ownship_oriented_segment[1][3] < 0 then
                -- Target in front (Yeah it is backwards)
                if x1 < -half_bullseye then
                    --print("From minus")
                    x1 = -half_bullseye
                    if x2 > -half_bullseye then
                        x2 = math.min(half_bullseye, x2)
                        p1 = ArcCheck.GetLineLineIntersection(ownship_oriented_segment[1], ownship_oriented_segment[2],
                            Vector(x1, ownship_oriented_segment[1][2], 0),
                            Vector(x1, ownship_oriented_segment[1][2], -100), true)
                        p2 = ArcCheck.GetLineLineIntersection(ownship_oriented_segment[1], ownship_oriented_segment[2],
                            Vector(x2, ownship_oriented_segment[1][2], 0),
                            Vector(x2, ownship_oriented_segment[1][2], -100), true)
                        if p1 ~= nil and p2 ~= nil then
                            print("test1")
                            table.insert(outsegments,
                                { Vect.Sum(Vect.RotateDeg(p1, ship.getRotation()[2]), ship.getPosition()),
                                    Vect.Sum(Vect.RotateDeg(p2, ship.getRotation()[2]), ship.getPosition()) })
                        end
                    end
                elseif x1 < half_bullseye then
                    --print("From plus")
                    x2 = math.min(half_bullseye, x2)
                    p1 = ArcCheck.GetLineLineIntersection(ownship_oriented_segment[1], ownship_oriented_segment[2],
                        Vector(x1, ownship_oriented_segment[1][2], 0), Vector(x1, ownship_oriented_segment[1][2], -100),
                        true)
                    p2 = ArcCheck.GetLineLineIntersection(ownship_oriented_segment[1], ownship_oriented_segment[2],
                        Vector(x2, ownship_oriented_segment[1][2], 0), Vector(x2, ownship_oriented_segment[1][2], -100),
                        true)
                    if p1 ~= nil and p2 ~= nil then
                        --print("test2")
                        table.insert(outsegments,
                            { Vect.Sum(Vect.RotateDeg(p1, ship.getRotation()[2]), ship.getPosition()),
                                Vect.Sum(Vect.RotateDeg(p2, ship.getRotation()[2]), ship.getPosition()) })
                    end
                end
            end
        end
    end
    return outsegments
end

ArcCheck.GetLineLineIntersection = function(p0, p1, p2, p3, expect_intersection)
    local max = 1
    local min = 0
    if expect_intersection then
        max = 1.00001
        min = -0.00001
    end

    local s1_x = p1[1] - p0[1]
    local s1_y = p1[3] - p0[3]
    local s2_x = p3[1] - p2[1]
    local s2_y = p3[3] - p2[3]

    local s = (-s1_y * (p0[1] - p2[1]) + s1_x * (p0[3] - p2[3])) / (-s2_x * s1_y + s1_x * s2_y)
    local t = (s2_x * (p0[3] - p2[3]) - s2_y * (p0[1] - p2[1])) / (-s2_x * s1_y + s1_x * s2_y)
    if (s >= min and s <= max and t >= min and t <= max) then
        -- Collision detected
        return Vector(p0[1] + (t * s1_x), p0[2], p0[3] + (t * s1_y))
    end
    print("S:" .. tostring(s) .. " t:" .. tostring(t))

    return nil -- no collision
end

return ArcCheck

end)
__bundle_register("Marker.Scenario.ObjectiveTokenData", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Objective style token data, By Eirik W. Munthe (eirikmun)
local O = {}
O.scale = 3.63
O.token_width = 0.18 * O.scale
O.token_height = 0.151 * O.scale
O.token_nub_height = 0.029 * O.scale
O.token_nub_length = 0.031 * O.scale
O.point_height = 0.002 * O.scale
O.outline_points = {
    vector(-O.token_height, O.point_height, -O.token_width),
    vector(O.token_height, O.point_height, -O.token_width),
    vector(O.token_height + O.token_nub_height, O.point_height, -(O.token_width - O.token_nub_height)),
    vector(O.token_height + O.token_nub_height, O.point_height,
        -(O.token_width - O.token_nub_height - O.token_nub_length)),
    vector(O.token_height + 0.7 * O.token_nub_height, O.point_height,
        -(O.token_width - O.token_nub_height - 1.48 * O.token_nub_length)),
    vector(O.token_height, O.point_height, -(O.token_width - O.token_nub_height - 1.70 * O.token_nub_length)),
    vector(O.token_height, O.point_height, (O.token_width - O.token_nub_height - 1.70 * O.token_nub_length)),
    vector(O.token_height + 0.7 * O.token_nub_height, O.point_height,
        (O.token_width - O.token_nub_height - 1.48 * O.token_nub_length)),
    vector(O.token_height + O.token_nub_height, O.point_height, (O.token_width - O.token_nub_height - O.token_nub_length)),
    vector(O.token_height + O.token_nub_height, O.point_height, (O.token_width - O.token_nub_height)),
    vector(O.token_height, O.point_height, O.token_width),
    vector(-O.token_height, O.point_height, O.token_width),
    vector(-(O.token_height + O.token_nub_height), O.point_height, (O.token_width - O.token_nub_height)),
    vector(-(O.token_height + O.token_nub_height), O.point_height,
        (O.token_width - O.token_nub_height - O.token_nub_length)),
    vector(-(O.token_height + 0.7 * O.token_nub_height), O.point_height,
        (O.token_width - O.token_nub_height - 1.48 * O.token_nub_length)),
    vector(-(O.token_height), O.point_height, (O.token_width - O.token_nub_height - 1.70 * O.token_nub_length)),
    vector(-(O.token_height), O.point_height, -(O.token_width - O.token_nub_height - 1.70 * O.token_nub_length)),
    vector(-(O.token_height + 0.7 * O.token_nub_height), O.point_height,
        -(O.token_width - O.token_nub_height - 1.48 * O.token_nub_length)),
    vector(-(O.token_height + O.token_nub_height), O.point_height,
        -(O.token_width - O.token_nub_height - O.token_nub_length)),
    vector(-(O.token_height + O.token_nub_height), O.point_height, -(O.token_width - O.token_nub_height)),
}

O.hashmark_points = {
    left = vector(0, O.point_height, -O.token_width),
    right = vector(0, O.point_height, O.token_width),
    front = vector(O.token_height, O.point_height, 0),
    back = vector(-O.token_height, O.point_height, 0),

    frontleft = O.outline_points[2]:lerp(O.outline_points[3], 0.5),
    frontright = O.outline_points[10]:lerp(O.outline_points[11], 0.5),
    backleft = O.outline_points[20]:lerp(O.outline_points[1], 0.5),
    backright = O.outline_points[12]:lerp(O.outline_points[13], 0.5),
}

O.arc_line_segments = {}
O.arc_line_segments.full = {
    segments = {
        { O.outline_points[1],  O.outline_points[2] },
        { O.outline_points[2],  O.outline_points[3] },
        { O.outline_points[3],  O.outline_points[4] },
        { O.outline_points[4],  O.outline_points[5] },
        { O.outline_points[5],  O.outline_points[6] },
        { O.outline_points[6],  O.outline_points[7] },
        { O.outline_points[7],  O.outline_points[8] },
        { O.outline_points[8],  O.outline_points[9] },
        { O.outline_points[9],  O.outline_points[10] },
        { O.outline_points[10], O.outline_points[11] },
        { O.outline_points[11], O.outline_points[12] },
        { O.outline_points[12], O.outline_points[13] },
        { O.outline_points[13], O.outline_points[14] },
        { O.outline_points[14], O.outline_points[15] },
        { O.outline_points[15], O.outline_points[16] },
        { O.outline_points[16], O.outline_points[17] },
        { O.outline_points[17], O.outline_points[18] },
        { O.outline_points[18], O.outline_points[19] },
        { O.outline_points[19], O.outline_points[20] },
        { O.outline_points[20], O.outline_points[1] },
    },
    degrees = { direction = 0, spread = 180 }
}

O.arc_line_segments.fullback = {
    segments = {
        { O.hashmark_points.left, O.outline_points[2] },
        { O.outline_points[2],    O.outline_points[3] },
        { O.outline_points[3],    O.outline_points[4] },
        { O.outline_points[4],    O.outline_points[5] },
        { O.outline_points[5],    O.outline_points[6] },
        { O.outline_points[6],    O.outline_points[7] },
        { O.outline_points[7],    O.outline_points[8] },
        { O.outline_points[8],    O.outline_points[9] },
        { O.outline_points[9],    O.outline_points[10] },
        { O.outline_points[10],   O.outline_points[11] },
        { O.outline_points[11],   O.hashmark_points.right },
    },
    degrees = { direction = 90, spread = 90 }
}
O.arc_line_segments.fullfront = {
    segments = {
        { O.hashmark_points.right, O.outline_points[12] },
        { O.outline_points[12],    O.outline_points[13] },
        { O.outline_points[13],    O.outline_points[14] },
        { O.outline_points[14],    O.outline_points[15] },
        { O.outline_points[15],    O.outline_points[16] },
        { O.outline_points[16],    O.outline_points[17] },
        { O.outline_points[17],    O.outline_points[18] },
        { O.outline_points[18],    O.outline_points[19] },
        { O.outline_points[19],    O.outline_points[20] },
        { O.outline_points[20],    O.outline_points[1] },
        { O.outline_points[1],     O.hashmark_points.left },
    },
    degrees = { direction = -90, spread = 90 }
}

O.arc_line_segments.back = {
    segments = {
        { O.hashmark_points.frontleft, O.outline_points[3] },
        { O.outline_points[3],         O.outline_points[4] },
        { O.outline_points[4],         O.outline_points[5] },
        { O.outline_points[5],         O.outline_points[6] },
        { O.outline_points[6],         O.outline_points[7] },
        { O.outline_points[7],         O.outline_points[8] },
        { O.outline_points[8],         O.outline_points[9] },
        { O.outline_points[9],         O.outline_points[10] },
        { O.outline_points[10],        O.hashmark_points.frontright },
    },
    degrees = { direction = 90, spread = 44 }
}

O.arc_line_segments.front = {
    segments = {
        { O.hashmark_points.backright, O.outline_points[13] },
        { O.outline_points[13],        O.outline_points[14] },
        { O.outline_points[14],        O.outline_points[15] },
        { O.outline_points[15],        O.outline_points[16] },
        { O.outline_points[16],        O.outline_points[17] },
        { O.outline_points[17],        O.outline_points[18] },
        { O.outline_points[18],        O.outline_points[19] },
        { O.outline_points[19],        O.outline_points[20] },
        { O.outline_points[20],        O.hashmark_points.backleft },
    },
    degrees = { direction = -90, spread = 44 }
}

O.arc_line_segments.right = {
    segments = {
        { O.hashmark_points.backleft, O.outline_points[1] },
        { O.outline_points[1],        O.outline_points[2] },
        { O.outline_points[2],        O.hashmark_points.frontleft },
    },
    degrees = { direction = 0, spread = 45 }
}

O.arc_line_segments.left = {
    segments = {
        { O.hashmark_points.frontright, O.outline_points[11] },
        { O.outline_points[11],         O.outline_points[12] },
        { O.outline_points[12],         O.hashmark_points.backright },
    },
    degrees = { direction = 180, spread = 45 }
}

O.arc_line_segments.bullseye = nil


return O

end)
__bundle_register("Game.HotAC.AI.BehaviourDB", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ~~~~~~
-- Script by shiprib
-- Issues, history at: https://github.com/JohnnyCheese/TTS_X-Wing2.0
--
-- Module for storing different AI behaviour engines and individual ship
-- behaviours
-- ~~~~~~

local BehaviourDB = {}
BehaviourDB.GetRuleSet = function()
    return BehaviourDB.rule_sets[1]
end

BehaviourDB.rule_sets = {}

--[[ A "rule set" is an AI ruleset that fits with the HotAC template defined by
the 0.7 version of Heroes of the Aturi Cluster by Josh Derksen:
http://dockingbay416.com/campaign/
HotAC 0.7 is for v1 of X-Wing however there have been several v2 adaptations
published.
]]

--[[ Each behaviour set is represented by a table in the following format:
name: String used to identify which set this is. This should contain the
    author and the date of last publication
usesBullseyeArc: A boolean, true if this behaviour set uses the bullseye arc.
degreesToArc: A function that the AI calls to convert the angle from its ship
    to its target into the name of the arc in its maneuver lookup table. This
    is here, rather than generalised, because different behaviour sets have
    different numbers of arcs.
    It takes a single argument (float), which is the angle from the AI ship to
    its target. Sample parameter values are:
        -180: directly behind
        -135: behind and to the left
        -90: directly to the left
        0: directly ahead
        90: directly to the right
        180: directly behind (identical to -180)
    It returns a table with the following keys:
        target_arc: String, the name of the arc. This can be anything, as long
            as it matches the arc names in the ship lookup tables.
        arc_parts: Table of strings, one or two of "front", "back", "left", or
            "right". These correspond to the sides of the AI ship that we needs
            to do range-checking from. These should be the two closest sides to
            the target arc.
flipArc: A function that takes one arc and flips it left-to-right. HotAC AI
    tables typically only cover the right half of the arc spectrum and rely
    on flipping the right arcs when the target is to the left.
    Takes a single argument (string), the name of the arc to flip
    Returns a string, which is the opposite of the specified arc.
targetSelectionFunctions: A table containing custom target selection functions.
    TODO: This has not been implemented yet!
ships: A table containing the AI data for each ship. This table is keyed with
the ID numbers found in the Datapad Lua script. The format for ships is below.
]]

--[[ Each ship is represted by a table with the following format:
target_selection: An ordered table containing the function names used for
    choosing a target, sorted by priority. There is a base set of functions
    defined in the core AI module, these are:
        'ClosestInArc': selects the closest ship, in the front arc, at range 1-3
        'Closest': selects the closest ship. Treats range 0 as range 1 directly
            behind.
move_table: A table containing the ship's move data, organised into arcs and
    distances.
    The first depth of tbe table, the arc, is defined by the ruleset in
        the function "degreesToArc". The only one specified by the underlying
        system is 'bullseye', which is only used if 'usesBullseyeArc' is true.
    The second depth of the table, the distance, is one of four:
        'near': the target is at range 0 or 1, or at range 2 and is moving
            towards the AI ship.
        'far': the target is at range 3, or at range 2 and is moving away from
            the AI ship.
        'distant': the target is at range 4 or beyond.
        'stress': the AI ship is stressed, and the target's range is irrelevant.
]]

-- This is the upgrade of the HotAC-style AI to X-wing v2, ultimately published
-- by Justin Gan. The AIs cover all three Rebellion-era factions and are made
-- for the broader Flight Group Alpha ruleset.
-- see: https://www.facebook.com/groups/872507722883025/permalink/1970166016450518/
BehaviourDB.rule_sets[1] = {}
BehaviourDB.rule_sets[1].name = 'XW-v2-FGA-v7-Gan-2020-04-07'
BehaviourDB.rule_sets[1].usesBullseyeArc = true
BehaviourDB.rule_sets[1].degreesToArc = function(angle_to_target)
    result = {}
    if angle_to_target < -135 then
        result.target_arc = 'back_left'
        result.arc_parts = { 'back', 'left' }
    elseif angle_to_target < -90 then
        result.target_arc = 'left_back'
        result.arc_parts = { 'left', 'back' }
    elseif angle_to_target < -45 then
        result.target_arc = 'left_front'
        result.arc_parts = { 'left', 'front' }
    elseif angle_to_target < 0 then
        result.target_arc = 'front_left'
        result.arc_parts = { 'front', 'left' }
    elseif angle_to_target < 45 then
        result.target_arc = 'front_right'
        result.arc_parts = { 'front', 'right' }
    elseif angle_to_target < 90 then
        result.target_arc = 'right_front'
        result.arc_parts = { 'right', 'front' }
    elseif angle_to_target < 135 then
        result.target_arc = 'right_back'
        result.arc_parts = { 'right', 'back' }
    else
        result.target_arc = 'back_right'
        result.arc_parts = { 'back', 'right' }
    end

    return result;
end
BehaviourDB.rule_sets[1].flipArc = function(arc)
    if string.find(arc, 'left') then
        arc = string.gsub(arc, 'left', 'right')
    elseif string.find(targetArc, 'right') then
        arc = string.gsub(arc, 'right', 'left')
    end

    return arc
end

BehaviourDB.rule_sets[1].GetShipBehaviour = function(ship)
    return BehaviourDB.rule_sets[1].GetShipBehaviourById(ship.getTable('Data').shipId, ship.getTable('Data').Faction)
end

BehaviourDB.rule_sets[1].GetShipBehaviourById = function(ship_id, faction_id)
    ship_behaviour = BehaviourDB.rule_sets[1].ships[ship_id]

    if ship_behaviour == nil or ship_behaviour.factions == nil then
        return ship_behaviour
    else
        return ship_behaviour.factions[faction_id]
    end
end

BehaviourDB.rule_sets[1].ships = {}

--------------------
-- Imperial Ships --
--------------------

-- TIE/ln Fighter
---- This logic is shared between Imperial and Rebel. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['tielnfighter'] = {}
BehaviourDB.rule_sets[1].ships['tielnfighter'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['tielnfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl2', [4] = 'br2', [5] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' }
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [4] = 's2', [6] = 's3' }
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr1', [4] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'br2' }
    },
    right_back = {
        near = { [1] = 'k3', [2] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2' }
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [4] = 'tr3' },
        distant = { [1] = 'k3', [5] = 'tr1' },
        stress = { [1] = 'br2', [6] = 'tr3' }
    }
}
BehaviourDB.rule_sets[1].ships['tielnfighter'].action_selection = {
    [1] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true },
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [5] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- TIE/in Interceptor
BehaviourDB.rule_sets[1].ships['tieininterceptor'] = {}
BehaviourDB.rule_sets[1].ships['tieininterceptor'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['tieininterceptor'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [2] = 'br3s', [4] = 'bl3s', [6] = 's2' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'tl2', [2] = 'tr2', [3] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl3s', [3] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'bl2', [2] = 'br2', [4] = 's2', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'bl3s', [5] = 'tr1' },
        far = { [1] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [3] = 'bl2', [4] = 'br2', [6] = 's4' },
    },
    right_back = {
        near = { [1] = 'bl3s', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'bl3s', [5] = 'tr2' },
        distant = { [1] = 'bl3s', [4] = 'tr1' },
        stress = { [1] = 'tl2', [2] = 'tr2', [5] = 'bl2', [6] = 's4' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'bl3s', [5] = 'tr2' },
        far = { [1] = 'br3s', [3] = 'bl3s' },
        distant = { [1] = 'bl3s', [4] = 'tr1' },
        stress = { [1] = 'tl2', [4] = 'tr2', [6] = 's4' },
    },
}
BehaviourDB.rule_sets[1].ships['tieininterceptor'].action_selection = {
    [1] = { -- (target moved) Focus > boost or focus > barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled/boosted and focused to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = {
            [1] = { focus = false, boost = true },
            [2] = { focus = false, barrelRoll = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- (target moved) Boost > barrel roll or barrel roll > boost to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = {
            [1] = { boost = false, barrelRoll = true },
            [2] = { barrelRoll = false, boost = true }
        },
        postconditions = { inTargetsArc = false, hasShot = true },
    },
    [3] = { -- (target moved) Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { targetMoved = true, hasShot = true },
        action = 'focus'
    },
    [4] = { -- (target moved) Evade
        description = "%s evaded.",
        preconditions = { targetMoved = true },
        action = 'evade'
    },
    [5] = { -- (target not moved) Boost > barrel roll or barrel roll > boost to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { targetMoved = false, hasShot = false },
        action = {
            [1] = { boost = false, barrelRoll = true },
            [2] = { barrelRoll = false, boost = true }
        },
        postconditions = { hasShot = true },
    },
    [6] = { -- (target not moved) Focus
        description = "%s focused.",
        preconditions = { targetMoved = false },
        action = 'focus'
    },
}

-- TIE Advanced x1
BehaviourDB.rule_sets[1].ships['tieadvancedx1'] = {}
BehaviourDB.rule_sets[1].ships['tieadvancedx1'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tieadvancedx1'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl1', [2] = 'br2', [3] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br1', [3] = 'br2', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr3t', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [4] = 'tr3' },
        stress = { [1] = 'br1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tr3t', [5] = 'tr2' },
        far = { [1] = 'tl3t', [3] = 'tr3t' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['tieadvancedx1'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Focus > barrel roll to avoid target's arc and still get a shot
        description = { text = "%s focused and barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = { focus = false, barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- (target moved) Focus > barrel roll to get a shot
        description = { text = "%s focused and barrel rolled to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = false },
        action = { focus = false, barrelRoll = true },
        postconditions = { hasShot = true },
    },
    [5] = { -- (target moved) Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/sa Bomber
BehaviourDB.rule_sets[1].ships['tiesabomber'] = {}
BehaviourDB.rule_sets[1].ships['tiesabomber'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiesabomber'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'k3', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k5', [2] = 'k3', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'k3', [5] = 'tr3' },
        far = { [1] = 'k3', [4] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['tiesabomber'].action_selection = {
    [1] = { --  Reload ordnance if no charges left (no shot)
        pass_through = true,
        preconditions = { hasShot = false },
        description =
        "If %s has no charges on its upgrades, then undo the following action and take a red Reload action.",
    },
    [2] = { --  Barrel roll > target lock to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s barrel rolled and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { inTargetsArc = false, hasShot = true, targetWithinRange = true },
    },
    [3] = { --  Barrel roll > target lock to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { inTargetsArc = false, hasShot = true },
    },
    [4] = { --  Barrel roll > target lock to get a shot (with the > target lock)
        description = "%s barrel rolled and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { hasShot = true, targetWithinRange = true },
    },
    [5] = { --  Barrel roll > target lock to get a shot (without the > target lock)
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { hasShot = true },
    },
    [6] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [7] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [8] = { --  Reload ordnance if no charges left (no shot or defense)
        pass_through = true,
        preconditions = { inTargetsArc = false, hasShot = false },
        description = "If %s has no charges on upgrades, then undo the following action and take a red Reload action.",
    },
    [9] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/de Defender
BehaviourDB.rule_sets[1].ships['tiededefender'] = {}
BehaviourDB.rule_sets[1].ships['tiededefender'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiededefender'].action_selection = {}
BehaviourDB.rule_sets[1].ships['tiededefender'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl1', [4] = 'br1', [5] = 's2' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl1', [2] = 'br1', [3] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'br2', [4] = 'tr3' },
        distant = { [1] = 'tr1', [2] = 'tr3' },
        stress = { [1] = 'br1', [4] = 's2', [5] = 'tr3' },
    },
    right_back = {
        near = { [1] = 'k4', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'tr1', [3] = 'tr3' },
        stress = { [1] = 'br1', [5] = 'tr3' },
    },
    back_right = {
        near = { [1] = 'k4', [5] = 'tr3' },
        far = { [1] = 'k4', [5] = 'tr1' },
        distant = { [1] = 'tr1', [4] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['tiededefender'].action_selection = {
    [1] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true, inEnemyArc = false },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Boost or barrel roll to get a shot at range 1
        description = "%s barrel rolled/boosted to get a close range shot.",
        preconditions = { targetMoved = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } },
    },
    [3] = { -- (target moved) Boost or barrel roll to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = true },
    },
    [4] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [5] = { -- Evade, if not already
        description = "%s evaded.",
        preconditions = { evading = false },
        action = 'evade'
    },
    [6] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, inEnemyArc = false, hasShot = true },
        action = 'targetLock'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}
BehaviourDB.rule_sets[1].ships['tiededefender'].special_rules = { 'fullThrottle' }

-- TIE/ph Phantom
BehaviourDB.rule_sets[1].ships['tiephphantom'] = {}
-- Need to add decloaking in the system phase
BehaviourDB.rule_sets[1].ships['tiephphantom'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['tiephphantom'].action_selection = {}
BehaviourDB.rule_sets[1].ships['tiephphantom'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 'bl1', [5] = 'br1', [6] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [3] = 's2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'k3', [4] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k4', [3] = 'k3' },
        distant = { [1] = 'k3', [4] = 'tr1' },
        stress = { [1] = 'br2', [5] = 's2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['tiephphantom'].action_selection = {
    [1] = { -- Cloak if no shot
        description = "%s cloaked.",
        preconditions = { hasShot = false },
        action = 'cloak'
    },
    [2] = { -- Evade if not already evading
        description = "%s evaded.",
        preconditions = { evading = false },
        action = 'evade'
    },
    [3] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false },
    },
    [4] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- T-4a Lambda-class Shuttle
BehaviourDB.rule_sets[1].ships['lambdaclasst4ashuttle'] = {}
BehaviourDB.rule_sets[1].ships['lambdaclasst4ashuttle'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['lambdaclasst4ashuttle'].action_selection = {}
BehaviourDB.rule_sets[1].ships['lambdaclasst4ashuttle'].move_table = {
    bullseye = {
        near = { [1] = 's0', [4] = 'bl1', [5] = 'br1', [6] = 's1' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 'br1', [5] = 's1', [6] = 'tr2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'br1', [4] = 'tr2' },
        far = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
        distant = { [1] = 'tr2', [2] = 'br2' },
        stress = { [1] = 'br1', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'br1', [4] = 'tr2' },
        far = { [1] = 'br1', [3] = 'tr2' },
        distant = { [1] = 'br1', [3] = 'tr2' },
        stress = { [1] = 'br1', [6] = 's1' },
    },
    back_right = {
        near = { [1] = 's0', [3] = 'br1', [4] = 'tr2', [5] = 'br2' },
        far = { [1] = 'br1', [3] = 'tr2' },
        distant = { [1] = 'br1', [3] = 'tr2' },
        stress = { [1] = 'br1', [6] = 's1' },
    },
}
BehaviourDB.rule_sets[1].ships['lambdaclasst4ashuttle'].action_selection = {
    [1] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [2] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [3] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [4] = { -- Coordinate the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = 'coordinate'
    },
    [5] = { -- Jam the target
        description = { text = "%s jammed %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = { jam = true },
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- VT-49 Decimator
BehaviourDB.rule_sets[1].ships['vt49decimator'] = {}
BehaviourDB.rule_sets[1].ships['vt49decimator'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['vt49decimator'].action_selection = {}
BehaviourDB.rule_sets[1].ships['vt49decimator'].move_table = {
    bullseye = {
        near = { [1] = 'tl2', [3] = 'tr2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl1', [3] = 'tl2', [6] = 'bl2' },
        far = { [1] = 'br1', [4] = 'br2', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'bl1', [2] = 'br1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'br2', [4] = 's2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [5] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'tr1', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'tr1', [3] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'br1', [3] = 'tr2', [5] = 'tr3' },
        far = { [1] = 'tl2', [3] = 'tr2' },
        distant = { [1] = 'tl2', [2] = 'tr3' },
        stress = { [1] = 'br1', [4] = 's1', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['vt49decimator'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [4] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [5] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [6] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [7] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = { coordinate = true }
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- TIE/rb Heavy
BehaviourDB.rule_sets[1].ships['tierbheavy'] = {}
BehaviourDB.rule_sets[1].ships['tierbheavy'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tierbheavy'].move_table = {
    bullseye = {
        near = { [1] = 's1', [3] = 's2', [4] = 'tl2', [5] = 'tr2', [6] = 's4' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'tr3t', [3] = 'br1', [4] = 'bl2', [5] = 'br2', [6] = 'tl2' },
        far = { [1] = 'br1', [2] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 's1', [3] = 'bl2', [4] = 'br2', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 'tr3t', [3] = 'bl1', [4] = 'tr1', [5] = 'bl2', [6] = 's2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's1', [6] = 's2' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'bl1', [5] = 's1', [6] = 'bl2' },
        far = { [1] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 's1', [2] = 'bl1', [3] = 'bl2', [5] = 'br2', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 'tr3t', [4] = 's1', [5] = 'bl1', [6] = 'bl2' },
        far = { [1] = 'tr3t', [4] = 's1', [5] = 'bl1', [6] = 'tr2' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 's1', [3] = 'bl2', [5] = 'br2', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['tierbheavy'].action_selection = {
    [1] = { -- Rotate turret > Calculate (stress) to get a shot
        description = "%s rotated its turret and calculated to get a shot.",
        preconditions = { hasShot = false },
        action = { calculate = true, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [5] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [6] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [7] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [8] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true },
    },
    [9] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false },
    },
    [10] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/ca Punisher
BehaviourDB.rule_sets[1].ships['tiecapunisher'] = {}
BehaviourDB.rule_sets[1].ships['tiecapunisher'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiecapunisher'].move_table = {
    bullseye = {
        near = { [1] = 's0', [2] = 'k4', [4] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 'k4', [4] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl1', [2] = 'br1^', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 'k4', [5] = 'bl1', [6] = 'tr2' },
        far = { [1] = 'k4', [5] = 'tr2' },
        distant = { [1] = 'k4', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [2] = 'bl1', [4] = 'br1' },
    },
    back_right = {
        near = { [1] = 'k4', [5] = 's1', [6] = 'tr2' },
        far = { [1] = 'k4', [5] = 'tr2' },
        distant = { [1] = 'k4', [3] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [6] = 's1' },
    },
}
BehaviourDB.rule_sets[1].ships['tiecapunisher'].action_selection = {
    [1] = { --  Boost > target lock to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s boosted and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = false },
        action = { boost = false, targetLock = true },
        postconditions = { inTargetsArc = false, hasShot = true, targetWithinRange = true },
    },
    [2] = { --  Boost > target lock to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = true },
        action = { boost = false },
        postconditions = { inTargetsArc = false, hasShot = true },
    },
    [3] = { --  Boost > target lock to get a shot (with the > target lock)
        description = "%s boosted and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = { boost = false, targetLock = true },
        postconditions = { hasShot = true, targetWithinRange = true },
    },
    [4] = { --  Boost > target lock to get a shot (without the > target lock)
        description = "%s boosted to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = { boost = false },
        postconditions = { hasShot = true },
    },
    [5] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [6] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [7] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a reload action.",
    },
    [8] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true },
    },
    [9] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false },
    },
    [10] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/ag Aggressor
BehaviourDB.rule_sets[1].ships['tieagaggressor'] = {}
BehaviourDB.rule_sets[1].ships['tieagaggressor'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tieagaggressor'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [3] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [3] = 's1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'br1', [3] = 's1', [4] = 'br2', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 's1', [2] = 'bl2', [3] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4~', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k4', [5] = 'tr2' },
        distant = { [1] = 'k4', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 's1', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k4', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k4', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 's1', [2] = 'bl2', [3] = 'br2', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['tieagaggressor'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Barrel roll > Evade (stress) to get a shot and defend
        description = "%s barrel rolled into an evade (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false, evade = true },
        postconditions = { hasShot = true, inTargetsArc = true },
    },
    [6] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [7] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE Advanced v1
BehaviourDB.rule_sets[1].ships['tieadvancedv1'] = {}
BehaviourDB.rule_sets[1].ships['tieadvancedv1'].target_selection = {
    [1] = 'ClosestInArcLowerInitiative',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tieadvancedv1'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl1', [4] = 'br1', [5] = 's2' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl1', [2] = 'br1', [3] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'tr1', [6] = 'br2' },
        far = { [1] = 'br1', [3] = 'br2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr1', [4] = 'tr2' },
        far = { [1] = 'tr1', [3] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [4] = 'br1', [6] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr2t', [5] = 'tr2' },
        distant = { [1] = 'tr2t', [4] = 'tr3' },
        stress = { [1] = 'tr1', [5] = 'br1', [6] = 'br2' },
    },
    back_right = {
        near = { [1] = 'tl2t', [3] = 'tr2t', [5] = 'tr2' },
        far = { [1] = 'tl2t', [3] = 'tr2t' },
        distant = { [1] = 'tr2t', [4] = 'tr2' },
        stress = { [1] = 'tr1', [4] = 'br1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['tieadvancedv1'].action_selection = {
    [1] = { -- (target moved) Boost or barrel roll > Focus (stress) to avoid Target arc and still get a shot
        description = "%s barrel rolled/boosted into a focus (stress) to avoid target's arc and still get a shot.",
        preconditions = { targetMoved = true, inTargetsArc = true, hasShot = true },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false },
    },
    [2] = { -- (target moved) Boost or barrel roll > Focus (stress) to get a shot
        description = "%s barrel rolled/boosted into a focus (stress) to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = true },
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, inEnemyArc = false, hasShot = true },
        action = 'targetLock'
    },
    [4] = { -- (target moved) Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { targetMoved = true, hasShot = true },
        action = 'focus'
    },
    [5] = { -- (target moved) Evade
        description = "%s evades.",
        preconditions = { targetMoved = true },
        action = 'evade'
    },
    [6] = { -- (target not moved) Boost or barrel roll > Focus (stress) to get a shot
        description = "%s barrel rolled/boosted into a focus (stress) to get a shot.",
        preconditions = { targetMoved = false, hasShot = false },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = true },
    },
    [7] = { -- (target not moved) Focus
        description = "%s focused.",
        preconditions = { targetMoved = false },
        action = 'focus'
    }
}

-- Alpha-class Star Wing
BehaviourDB.rule_sets[1].ships['alphaclassstarwing'] = {}
BehaviourDB.rule_sets[1].ships['alphaclassstarwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['alphaclassstarwing'].move_table = {
    bullseye = {
        near = { [1] = 's1', [3] = 'bl1', [4] = 'br1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [6] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's1', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [3] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'br1', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'br1', [3] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 's1', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'br2', [2] = 'tr2', [4] = 's3', [5] = 'tr3' },
        far = { [1] = 'tr2', [4] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'bl2', [2] = 'br2', [5] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['alphaclassstarwing'].action_selection = {
    [1] = { -- SLAM if no shot and target outside of range 2
        description = "%s took a SLAM action. Perform the appropriate SLAM movement manually.",
        preconditions = { hasShot = false, targetWithinRange = { arguments = { maxRange = 2 }, requiredResult = false } },
        action = 'disarm'
    },
    [2] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a Reload action.",
    },
    [5] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE Reaper
BehaviourDB.rule_sets[1].ships['tierereaper'] = {}
BehaviourDB.rule_sets[1].ships['tierereaper'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['tierereaper'].action_selection = {}
BehaviourDB.rule_sets[1].ships['tierereaper'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 'bl1', [2] = 'br1', [3] = 's1', [5] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 'bl1s', [3] = 'br1', [5] = 's1' },
        far = { [1] = 's1', [2] = 'br1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl1s', [4] = 'br1', [5] = 'tr1' },
        far = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [6] = 'tr2' },
        distant = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2', [5] = 'br3' },
        stress = { [1] = 'br1', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'br1s', [3] = 'bl1s', [6] = 'br1' },
        far = { [1] = 'bl1s', [4] = 'br1', [5] = 'tr1' },
        distant = { [1] = 'bl1s', [4] = 'br1', [5] = 'tr2' },
        stress = { [1] = 's1', [3] = 'br1' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 'br1s', [3] = 'bl1s', [6] = 'br1' },
        far = { [1] = 'br1s', [2] = 'bl1s', [5] = 'br1', [6] = 'tr1' },
        distant = { [1] = 'bl1s', [4] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 'br1', [5] = 's1' },
    },
}
BehaviourDB.rule_sets[1].ships['tierereaper'].action_selection = {
    [1] = { --  manual Ailerons prompt
        pass_through = true,
        description = "If not stressed, perform the Ailerons movement manually before clicking Move & Act.",
    },
    [2] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [3] = { -- Jam the target
        description = { text = "%s jammed %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = 'jam'
    },
    [4] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true },
        action = 'evade'
    },
    [5] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated (stress) %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { ['hasCoordinateTarget'] = true },
        action = { ['coordinate'] = true }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- TIE/sk Striker
BehaviourDB.rule_sets[1].ships['tieskstriker'] = {}
BehaviourDB.rule_sets[1].ships['tieskstriker'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['tieskstriker'].move_table = {
    bullseye = {
        near = { [1] = 'br2s', [2] = 'bl2s', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'bl2s', [3] = 'br1', [5] = 's1' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [2] = 'br1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl2s', [3] = 'br1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [4] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'tr1', [2] = 'br2', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k1', [2] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'k1', [2] = 'bl2s', [5] = 'tr1' },
        distant = { [1] = 'bl2s', [3] = 'tr1', [5] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k1', [4] = 'br2s', [5] = 'bl2s' },
        far = { [1] = 'k1', [3] = 'br2s', [4] = 'bl2s', [6] = 'tr2' },
        distant = { [1] = 'k1', [3] = 'bl2s', [5] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'br3' },
    },
}
BehaviourDB.rule_sets[1].ships['tieskstriker'].action_selection = {
    [1] = { --  manual Ailerons prompt
        pass_through = true,
        description = "If not stressed, perform the Ailerons movement manually before clicking Move & Act.",
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true },
    },
    [5] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [6] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true },
        action = 'evade'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- Gauntlet Fighter
---- This logic is shared between Imperial, Rebel, Scum, Republic, and Separatist. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['gauntletfighter'] = {}
BehaviourDB.rule_sets[1].ships['gauntletfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['gauntletfighter'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's2', [4] = 'tl2', [5] = 'tr2', [6] = 's4' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's2', [5] = 'bl2', [6] = 'br2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 'tl2', [5] = 'br3', [6] = 'bl3' },
        far = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [4] = 'bl1', [6] = 'tl2' },
        far = { [1] = 'br1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'bl1', [5] = 'br2', [6] = 'bl2' },
    },
    right_back = {
        near = { [1] = 's0', [4] = 'bl1', [5] = 's2', [6] = 'bl3' },
        far = { [1] = 's0', [4] = 'bl1', [5] = 'tr2' },
        distant = { [1] = 's0', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'bl1', [4] = 'br2', [5] = 'bl2', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 's0', [4] = 'br1', [5] = 's2', [6] = 's4' },
        far = { [1] = 's0', [4] = 's2', [5] = 'tr2' },
        distant = { [1] = 's0', [3] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'bl1', [3] = 'br2', [4] = 'bl2', [5] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['gauntletfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Reinforce (stress) the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced (stress) fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceFore'] = true }
    },
    [6] = { -- Reinforce (stress) the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced (stress) aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceAft'] = true }
    },
    [7] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = { coordinate = true }
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}


-----------------
-- Rebel Ships --
-----------------

-- Z-95-AF4 Headhunter. This is split by faction because the Rebel and S&V Z-95s
-- have slightly different tables.
BehaviourDB.rule_sets[1].ships['z95af4headhunter'] = {}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions = {}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[1] = {}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[1].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[1].move_table = {
    bullseye = {
        near = { [1] = 'k3', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'k3', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'k3', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr3' },
        stress = { [1] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 's1', [3] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[1].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl2', [2] = 'br2', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[1].action_selection = {
    [1] = { -- Target lock if not in enemy's arc
        description = { text = "%s target locked %s outside target's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll (stress) to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- T-65 X-Wing
BehaviourDB.rule_sets[1].ships['t65xwing'] = {}
BehaviourDB.rule_sets[1].ships['t65xwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['t65xwing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr3t', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [4] = 'tr3' },
        stress = { [1] = 'br1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tr3t', [5] = 'tr2' },
        far = { [1] = 'tl3t', [3] = 'tr3t' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['t65xwing'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 's1', [3] = 'bl1', [4] = 'br1', [5] = 's2' }
}
BehaviourDB.rule_sets[1].ships['t65xwing'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- (target moved) Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true },
    },
    [5] = { -- (target moved) Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- BTL-A4 Y-Wing
---- This logic is shared between Rebel and Scum. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['btla4ywing'] = {}
BehaviourDB.rule_sets[1].ships['btla4ywing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['btla4ywing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [2] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [5] = 'bl2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [4] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'bl2', [5] = 's2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br2', [5] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [3] = 'tr2' },
        distant = { [1] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [4] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's1', [3] = 'tr2', [5] = 's2' },
        far = { [1] = 'br1', [3] = 'tr2' },
        distant = { [1] = 'k4', [3] = 'tr2' },
        stress = { [1] = 'br1', [4] = 's1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['btla4ywing'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 's1', [2] = 'bl1', [4] = 'br1', [6] = 's2' }
}
BehaviourDB.rule_sets[1].ships['btla4ywing'].action_selection = {
    [1] = { -- Target lock if charges left
        description = { text = "%s target locked %s. If %s has no charges on its upgrades, then undo this action and perform it manually.", strings = { 'ship', 'target', 'ship' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    -- Previous Rotate action (not working - no primary turret arc)
    --  [2] = { -- Rotate turret to get a shot
    --      description = "%s rotated its turret to get a shot.",
    --      preconditions = {hasShot = {arguments = {['includeArcs'] = {'front'}}, requiredResult = false}},
    --      action = {rotateTurret = {mount = 'main'}},
    --      postconditions = {hasShot = {arguments = {['includeArcs'] = {'front'}}, requiredResult = true}},
    --  },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { --  Reload ordnance (stress) if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its upgrades, then undo the following action and take a red Reload action.",
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- RZ-1 A-Wing
BehaviourDB.rule_sets[1].ships['rz1awing'] = {}
BehaviourDB.rule_sets[1].ships['rz1awing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['rz1awing'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [2] = 'br3s', [4] = 'bl3s', [6] = 's2' },
        far = { [1] = 's2', [3] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'bl3s', [4] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'tr2', [2] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl3s', [4] = 'tr1' },
        far = { [1] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'br2', [6] = 'tr3' },
    },
    right_back = {
        near = { [1] = 'bl3s', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'br3s', [3] = 'bl3s', [4] = 'tr2' },
        distant = { [1] = 'bl3s', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'bl3s', [5] = 'tr2' },
        far = { [1] = 'bl3s', [3] = 'tr2' },
        distant = { [1] = 'bl3s', [4] = 'tr2' },
        stress = { [1] = 'tr2', [5] = 'tr3', [6] = 's5' },
    },
}
BehaviourDB.rule_sets[1].ships['rz1awing'].flee_table = {
    edge = { bullseye = 's5' },
    hyper = { [1] = 'bl2', [2] = 'br2', [3] = 's4', [5] = 's5' }
}
BehaviourDB.rule_sets[1].ships['rz1awing'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target not moved) Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { targetMoved = false, hasShot = true },
        action = 'focus'
    },
    [3] = { -- (target not moved) Evade
        description = "%s evaded.",
        preconditions = { targetMoved = false },
        action = 'evade'
    },
    [4] = { -- (target moved) Boost or barrel roll to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- (target moved) Focus > Boost (stress) to get a shot at range 1
        description = "%s focused into a boost (stress) to get a close range shot.",
        preconditions = { targetMoved = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = { focus = false, boost = true },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [6] = { -- (target moved) Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- (target moved) Target lock if charges left
        description = { text = "%s target locked %s. If %s has no charges on its upgrades, then undo this action and perform it manually.", strings = { 'ship', 'target', 'ship' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [8] = { -- (target moved) Focus
        description = "%s focused.",
        preconditions = { targetMoved = true },
        action = 'focus'
    }
}

-- A/SF-01 B-Wing
BehaviourDB.rule_sets[1].ships['asf01bwing'] = {}
BehaviourDB.rule_sets[1].ships['asf01bwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['asf01bwing'].move_table = {
    bullseye = {
        near = { [1] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k2', [2] = 'br1', [6] = 'bl2' },
        far = { [1] = 'br1', [4] = 'br2', [6] = 'br3' },
        distant = { [1] = 'br2', [5] = 'br3' },
        stress = { [1] = 'br1', [4] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'tr1', [3] = 'br1', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [6] = 'br2' },
        distant = { [1] = 'tr2', [4] = 'br2' },
        stress = { [1] = 'br1', [5] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k2', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k2', [2] = 'tr1t', [5] = 'tr2' },
        distant = { [1] = 'tr1t', [3] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k2', [3] = 'tl1t', [5] = 'tr2' },
        far = { [1] = 'k2', [3] = 'tr1t' },
        distant = { [1] = 'tr1t', [4] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['asf01bwing'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 's1', [3] = 'bl1', [4] = 'br1', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['asf01bwing'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Focus > barrel roll (stress) to avoid target's arc and still get a shot
        description = { text = "%s focused and barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = { focus = false, barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- (target moved) Focus > barrel roll (stress) to get a shot
        description = { text = "%s focused and barrel rolled to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = false },
        action = { focus = false, barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- (target moved) Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- YT-2400 Light Freighter
BehaviourDB.rule_sets[1].ships['yt2400lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['yt2400lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['yt2400lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'tl2', [5] = 'tr2' },
        far = { [1] = 's1', [2] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [3] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl1', [3] = 'tl2', [6] = 'bl2' },
        far = { [1] = 'br1', [4] = 'br2', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [3] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'bl2', [4] = 's2' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'br1', [6] = 's1' },
    },
    right_back = {
        near = { [1] = 's1', [4] = 'bl1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k4', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [4] = 'tr2' },
        far = { [1] = 'tr1', [3] = 'tr2' },
        distant = { [1] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'tr1', [3] = 'br1' },
    },
}
BehaviourDB.rule_sets[1].ships['yt2400lightfreighter'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl1', [3] = 'br1', [4] = 's1', [5] = 's2' }
}
BehaviourDB.rule_sets[1].ships['yt2400lightfreighter'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target moved) Target lock if target is in turret arc at range 2
        description = "%s target locked target at range 2 in turret arc.",
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = { arguments = { maxRange = 2 }, { ['minRange'] = 2 }, requiredResult = true }, hasShot = { arguments = { maxRange = 2 }, requiredResult = true } },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Barrel roll (stress) to get target at range 2 and in turret arc
        description = "%s barrel rolled to get target in turret arc at range 2.",
        preconditions = { targetMoved = true, targetWithinRange = { arguments = { maxRange = 2 }, { ['minRange'] = 2 }, requiredResult = false } },
        action = { barrelRoll = true },
        postconditions = { targetWithinRange = { arguments = { maxRange = 2 }, { ['minRange'] = 2 }, requiredResult = true }, hasShot = { arguments = { maxRange = 2 }, requiredResult = true } },
    },
    [4] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Modified YT-1300 Light Freighter
BehaviourDB.rule_sets[1].ships['modifiedyt1300lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['modifiedyt1300lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['modifiedyt1300lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 'tl2', [3] = 'tr2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl1', [3] = 'tl2', [6] = 'bl2' },
        far = { [1] = 'br1', [4] = 'br2', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [2] = 'bl2', [3] = 'br2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'bl2', [4] = 's2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [2] = 'br2' },
    },
    right_back = {
        near = { [1] = 'bl3s', [3] = 'br1', [4] = 'tr2' },
        far = { [1] = 'k4', [2] = 'bl3s', [5] = 'tr2' },
        distant = { [1] = 'bl3s', [4] = 'tr2' },
        stress = { [1] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr2' },
        far = { [1] = 'br3s', [3] = 'bl3s' },
        distant = { [1] = 'bl3s', [4] = 'tr2' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['modifiedyt1300lightfreighter'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl2', [2] = 'br2', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['modifiedyt1300lightfreighter'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- Boost (stress) to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { hasShot = false },
        action = { boost = true },
        postconditions = { hasShot = true }
    },
    [3] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [4] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- VCX-100 Light Freighter
BehaviourDB.rule_sets[1].ships['vcx100lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['vcx100lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['vcx100lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [2] = 's1', [3] = 'tl2', [5] = 'tr2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'br1', [3] = 'bl2', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [2] = 'bl2', [3] = 'br2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'bl2', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'tr2', [2] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr1', [3] = 'tr2' },
        distant = { [1] = 'k4', [4] = 'tr2' },
        stress = { [1] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tl2', [5] = 'tr2' },
        far = { [1] = 'k4', [3] = 'tr2' },
        distant = { [1] = 'k4', [4] = 'tr2' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['vcx100lightfreighter'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 's1', [2] = 'bl2', [4] = 'br2', [6] = 's2' }
}
BehaviourDB.rule_sets[1].ships['vcx100lightfreighter'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [5] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- ARC-170 Starfighter
---- This logic is shared between Rebel and Republic. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['arc170starfighter'] = {}
BehaviourDB.rule_sets[1].ships['arc170starfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['arc170starfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'bl2', [4] = 'tl2', [5] = 'bl3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'bl2', [4] = 'br2', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [3] = 'bl2', [5] = 'tl2', [6] = 'bl3' },
        far = { [1] = 'br1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [4] = 'br3', [6] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'bl1', [4] = 'br2', [6] = 'bl2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'bl1', [5] = 's1', [6] = 'bl2' },
        far = { [1] = 'k4', [3] = 'tr2' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl1', [2] = 'br1', [4] = 'bl2', [5] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [4] = 'bl1', [5] = 's1', [6] = 's2' },
        far = { [1] = 'k4', [3] = 'bl1', [4] = 's1', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k4', [3] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [5] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['arc170starfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Attack Shuttle
BehaviourDB.rule_sets[1].ships['attackshuttle'] = {}
BehaviourDB.rule_sets[1].ships['attackshuttle'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['attackshuttle'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [2] = 's2', [3] = 'br2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'br1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [4] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 'k4', [4] = 'tr1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr1', [4] = 'tr2' },
        distant = { [1] = 'k4', [2] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 's1', [2] = 'br1', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 'k4', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k4', [4] = 'tr2' },
        distant = { [1] = 'k4', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['attackshuttle'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll > Evade (stress) to get a shot and defend
        description = "%s barrel rolled into an evade (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false, evade = true },
        postconditions = { hasShot = true, inTargetsArc = true }
    },
    [5] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [6] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true },
        action = 'evade'
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Auzituck Gunship
BehaviourDB.rule_sets[1].ships['auzituckgunship'] = {}
BehaviourDB.rule_sets[1].ships['auzituckgunship'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['auzituckgunship'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 'bl1', [4] = 'br1', [5] = 's1' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [2] = 'bl1', [3] = 'br1', [4] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 's1', [5] = 'br1' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'br1', [4] = 's1', [5] = 'br2', [6] = 'tr2' },
        far = { [1] = 'br1', [3] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [6] = 's1' },
    },
    right_back = {
        near = { [1] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [3] = 'br1', [4] = 'tr2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'br1', [2] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['auzituckgunship'].action_selection = {
    [1] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [2] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [3] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true },
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false },
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- E-Wing
BehaviourDB.rule_sets[1].ships['ewing'] = {}
BehaviourDB.rule_sets[1].ships['ewing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['ewing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl3s', [4] = 'br3s', [5] = 's1' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [2] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [4] = 's3', [5] = 's4' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'br3s', [4] = 'bl3s', [6] = 'tr1' },
        far = { [1] = 'br1', [2] = 'tr1', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'br3s', [4] = 'bl3s', [6] = 'tr1' },
        far = { [1] = 'k4', [2] = 'bl3s', [5] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl3s', [2] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [4] = 'br3s', [5] = 'bl3s' },
        far = { [1] = 'k4', [3] = 'bl3s', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's4', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['ewing'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inTargetsArc = false, hasShot = false, targetWithinRange = false },
        action = 'targetLock'
    },
    [2] = { --  (target moved) Boost or Barrel roll > target lock (stress) to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s barrel rolled/boosted and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, targetMoved = true, targetLocked = false },
        action = {
            [1] = { boost = false, targetLock = true },
            [2] = { barrelRoll = false, targetLock = true },
        },
        postconditions = { inTargetsArc = false, hasShot = { arguments = { ['minRange'] = 2 }, requiredResult = true }, targetWithinRange = true },
    },
    [3] = { --  (target moved) Boost or Barrel roll to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s barrel rolled/boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, targetMoved = true, hasShot = true, targetLocked = true },
        action = {
            [1] = { boost = false, },
            [2] = { barrelRoll = false, }
        },
        postconditions = { inTargetsArc = false, hasShot = true }
    },
    [4] = { --  Boost or Barrel roll > target lock (stress) to get a shot (with the > target lock)
        description = "%s barrel rolled and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = {
            [1] = { boost = false, targetLock = true },
            [2] = { barrelRoll = false, targetLock = true },
        },
        postconditions = { hasShot = { arguments = { ['minRange'] = 2 }, requiredResult = true }, targetWithinRange = true },
    },
    [5] = { --  Boost or Barrel roll  to get a shot (without the > target lock)
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = {
            [1] = { boost = false, },
            [2] = { barrelRoll = false, }
        },
        postconditions = { hasShot = true }
    },
    [6] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [7] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [8] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true },
        action = 'evade'
    },
    [9] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Sheathipede-class Shuttle
BehaviourDB.rule_sets[1].ships['sheathipedeclassshuttle'] = {}
BehaviourDB.rule_sets[1].ships['sheathipedeclassshuttle'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['sheathipedeclassshuttle'].move_table = {
    bullseye = {
        near = { [1] = 's1r', [2] = 'k4', [3] = 's1', [4] = 'bl3', [5] = 'br3', [6] = 's4' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [6] = 's4' },
        stress = { [1] = 's1', [2] = 's2', [4] = 's3', [5] = 'bl3', [6] = 'br3' },
    },
    front_right = {
        near = { [1] = 's1r', [2] = 'br1', [3] = 'bl2', [4] = 'tl2', [5] = 'bl3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [2] = 'br2', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 's1r', [2] = 'k3', [3] = 'bl1', [4] = 'tl2', [5] = 'tr2', [6] = 'bl2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'bl2', [4] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'bl1', [6] = 's1' },
        far = { [1] = 'k3', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [2] = 's2', [3] = 'bl2', [5] = 'br2^', [6] = 's3' },
    },
    back_right = {
        near = { [1] = 's1r', [2] = 'k3', [3] = 'bl1', [5] = 's1', [6] = 'bl2' },
        far = { [1] = 's1r', [2] = 'k3', [4] = 'bl1', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 's1', [3] = 'bl2', [5] = 'br2', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['sheathipedeclassshuttle'].action_selection = {
    [1] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [2] = { -- Coordinate the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = 'coordinate'
    },
    [3] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}

-- UT-60D U-Wing
BehaviourDB.rule_sets[1].ships['ut60duwing'] = {}
BehaviourDB.rule_sets[1].ships['ut60duwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['ut60duwing'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's1', [4] = 'tl2', [5] = 'tr2', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [4] = 's1', [6] = 'br1' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [5] = 'br1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2' },
        distant = { [1] = 'tr2', [5] = 'br3' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [5] = 'tr2', [6] = 's4' },
        far = { [1] = 's0', [5] = 'tr2' },
        distant = { [1] = 's0', [3] = 'tr2' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [5] = 'tr2', [6] = 's4' },
        far = { [1] = 's0', [5] = 'tr2' },
        distant = { [1] = 's0', [3] = 'tr2' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'bl2', [4] = 'br2', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['ut60duwing'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = { coordinate = true }
    },
    [5] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}

-- BTL-S8 K-Wing
BehaviourDB.rule_sets[1].ships['btls8kwing'] = {}
BehaviourDB.rule_sets[1].ships['btls8kwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['btls8kwing'].move_table = {
    bullseye = {
        near = { [1] = 's1', [3] = 'tl2', [4] = 'tr2', [5] = 'bl3', [6] = 'br3' },
        far = { [1] = 's1^', [3] = 's2^', [6] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl2', [2] = 'tl2', [4] = 'tr2', [5] = 'bl3', [6] = 'br3' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'bl1', [2] = 'br1', [4] = 's1', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [3] = 'bl2', [4] = 'tl2', [6] = 'bl3' },
        far = { [1] = 'br1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'br2', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'bl1', [3] = 's1', [4] = 's2', [5] = 'bl2', [6] = 'tl2' },
        far = { [1] = 'bl1', [3] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [6] = 'br3' },
        stress = { [1] = 's1', [3] = 'bl1', [5] = 'br1', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 's1', [3] = 'bl1', [5] = 's2', [6] = 'bl2' },
        far = { [1] = 'bl1', [3] = 's1', [5] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2' },
        stress = { [1] = 's1', [2] = 'bl1', [4] = 'br1', [5] = 's2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['btls8kwing'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- SLAM if no shot and target outside of range 2
        description = "%s took a SLAM action. Perform the appropriate SLAM movement manually.",
        preconditions = { hasShot = false, targetWithinRange = { arguments = { maxRange = 2 }, requiredResult = false } },
        action = 'disarm'
    },
    [3] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a Reload action.",
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}


----------------
-- Scum Ships --
----------------

-- The Z-95 Scum has slightly different AI from the Rebel one (less self-preservation)
-- Z-95-AF4 Headhunter. This is already defined in the Rebel section, so we have
-- to add a new faction to the existing one.
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[3] = {}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[3].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[3].move_table = {
    bullseye = {
        near = { [1] = 'k3', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'k3', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'k3', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr3' },
        stress = { [1] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 's1', [3] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[3].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl2', [2] = 'br2', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['z95af4headhunter'].factions[3].action_selection = {
    [1] = { -- Target lock if not in enemy's arc
        description = { text = "%s target locked %s outside target's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [3] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [4] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- M3-A Interceptor
BehaviourDB.rule_sets[1].ships['m3ainterceptor'] = {}
BehaviourDB.rule_sets[1].ships['m3ainterceptor'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['m3ainterceptor'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'k3', [5] = 'bl1', [6] = 'br1' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'k3', [4] = 'tr1', [6] = 'br1' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [3] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'tr2', [6] = 'br2' },
        distant = { [1] = 'tr1', [3] = 'tr2' },
        stress = { [1] = 'tr1', [2] = 'br1' },
    },
    right_back = {
        near = { [1] = 'k5', [2] = 'k3', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr1' },
        stress = { [1] = 'tr1', [3] = 'br1' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k3', [4] = 'tr2' },
        distant = { [1] = 'k3', [5] = 'tr1' },
        stress = { [1] = 'br1', [3] = 'tr2', [5] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['m3ainterceptor'].flee_table = {
    edge = { bullseye = 's5' },
    hyper = { [1] = 'bl1', [3] = 'br1', [5] = 's2', [6] = 's3' }
}
BehaviourDB.rule_sets[1].ships['m3ainterceptor'].action_selection = {
    [1] = { -- Target lock if charges left
        description = { text = "%s target locked %s. If %s has no charges on its upgrades, then undo this action and perform it manually.", strings = { 'ship', 'target', 'ship' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false },
        postconditions = { hasShot = true }
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- Khiraxz Fighter
BehaviourDB.rule_sets[1].ships['kihraxzfighter'] = {}
BehaviourDB.rule_sets[1].ships['kihraxzfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['kihraxzfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl1', [5] = 'br1' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr2t', [4] = 'tr1' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'tr1', [3] = 'br1', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr2t', [5] = 'tr1' },
        distant = { [1] = 'tr2t', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'br1', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tr2t', [5] = 'tr2' },
        far = { [1] = 'tl2t', [3] = 'tr2t' },
        distant = { [1] = 'tr2t', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'br1', [4] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['kihraxzfighter'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl2', [3] = 'br2', [5] = 's2', [6] = 's3' }
}
BehaviourDB.rule_sets[1].ships['kihraxzfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s focused and barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = { barrelRoll = false },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- (target moved) Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { targetMoved = true, hasShot = true },
        action = 'focus'
    },
    [5] = { -- (target moved) Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- StarViper-class Attack Platform
BehaviourDB.rule_sets[1].ships['starviperclassattackplatform'] = {}
BehaviourDB.rule_sets[1].ships['starviperclassattackplatform'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['starviperclassattackplatform'].move_table = {
    bullseye = {
        near = { [1] = 'br3s', [2] = 'bl3s', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl3s', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl3s', [3] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [6] = 'br2' },
        distant = { [1] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'bl3s', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br3s', [2] = 'bl3s', [5] = 'tr2' },
        distant = { [1] = 'br3s', [4] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'br3s', [3] = 'bl3s', [5] = 'tr1' },
        far = { [1] = 'br3s', [3] = 'bl3s' },
        distant = { [1] = 'br3s', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'tr2', [5] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['starviperclassattackplatform'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl2', [2] = 'br2', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['starviperclassattackplatform'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Boost or barrel roll > Focus/Calc (stress) to avoid Target arc and still get a shot
        description =
        "%s barrel rolled/boosted into a focus/calculate (stress) to avoid target's arc and still get a shot.",
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Boost or barrel roll > Focus/Calc (stress) to get a shot at range 1
        description = "%s barrel rolled/boosted into a focus/calculate (stress) to get a close range shot.",
        preconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [4] = { -- Boost or barrel roll > Focus/Calc (stress) to get a shot
        description = "%s barrel rolled/boosted into a focus/calculate (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    }
}

-- Fang Fighter
---- This logic is shared between Scum and Rebel. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['fangfighter'] = {}
BehaviourDB.rule_sets[1].ships['fangfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['fangfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl2', [4] = 'br2', [5] = 's2' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl2', [2] = 'br2', [3] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [4] = 's2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr2t', [5] = 'tr2' },
        distant = { [1] = 'tr2t', [4] = 'tr3' },
        stress = { [1] = 'tr2', [5] = 'br2' },
    },
    back_right = {
        near = { [1] = 'tl2t', [3] = 'tr2t', [5] = 'tr2' },
        far = { [1] = 'tl2t', [3] = 'tr2t' },
        distant = { [1] = 'tr2t', [4] = 'tr2' },
        stress = { [1] = 'tr2', [4] = 'br2', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['fangfighter'].flee_table = {
    edge = { bullseye = 's5' },
    hyper = { [1] = 'tl2', [2] = 'tr2', [3] = 'bl2', [5] = 'br2' }
}
BehaviourDB.rule_sets[1].ships['fangfighter'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Boost or barrel roll > Focus (stress) to avoid Target arc and still get a shot
        description = "%s barrel rolled/boosted into a focus (stress) to avoid target's arc and still get a shot.",
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Boost or barrel roll > Focus (stress) to get a shot at range 1
        description = "%s barrel rolled/boosted into a focus (stress) to get a close range shot.",
        preconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [4] = { -- Boost or barrel roll > Focus (stress) to get a shot
        description = "%s barrel rolled/boosted into a focus (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, focus = true },
            [2] = { barrelRoll = false, focus = true }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- HWK-290 Light Freighter
---- This logic is shared between Scum and Rebel. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['hwk290lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['hwk290lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['hwk290lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 's0', [4] = 'bl1', [5] = 'br1', [6] = 's1' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 's1', [5] = 'br1', [6] = 'tl2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'tr2', [4] = 'bl2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br1', [3] = 'tr2' },
        distant = { [1] = 'br1', [3] = 'tr2' },
        stress = { [1] = 'br1', [5] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [3] = 'br1', [5] = 'tr2', [6] = 'br3' },
        far = { [1] = 'br1', [3] = 'tr2' },
        distant = { [1] = 'br1', [4] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['hwk290lightfreighter'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl1', [2] = 'br1', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['hwk290lightfreighter'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Target Lock > Rotate turret (stress) to get a shot
        description = { text = "%s target locked %s and rotated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = false },
        action = { targetLock = true, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Focus > Rotate turret (stress) to get a shot
        description = "%s focused and rotated to get a shot.",
        preconditions = { hasShot = false },
        action = { focus = true, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true }
    },
    [5] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [6] = { -- Boost (stress) to get a shot
        description = { text = "%s boosted to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = false },
        action = { boost = true },
        postconditions = { hasShot = true }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Firespray-Class Patrol Craft
---- This logic is shared between Scum and CIS. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['firesprayclasspatrolcraft'] = {}
BehaviourDB.rule_sets[1].ships['firesprayclasspatrolcraft'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['firesprayclasspatrolcraft'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's1', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr3t', [4] = 'tr1' },
        far = { [1] = 'tr1', [3] = 'br1', [5] = 'tr2' },
        distant = { [1] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'tr1', [2] = 'bl1', [4] = 'br1' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [5] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tr3t', [5] = 'tr2' },
        far = { [1] = 'tl3t', [3] = 'tr3t' },
        distant = { [1] = 'tr3t', [4] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['firesprayclasspatrolcraft'].flee_table = {
    edge = { bullseye = 's4' },
    hyper = { [1] = 'bl1', [2] = 'br1', [3] = 's2', [5] = 's3' }
}
BehaviourDB.rule_sets[1].ships['firesprayclasspatrolcraft'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Boost to get a shot
        description = { text = "%s boosted to get a shot.", strings = { 'ship' } },
        preconditions = { targetMoved = true, hasShot = false },
        action = { boost = false },
        postconditions = { hasShot = true }
    },
    [4] = { -- (target moved) Boost to get within Range 1 and still get a shot
        description = "%s boosted to get a close range shot.",
        preconditions = { hasShot = { arguments = { ['minRange'] = 2 }, requiredResult = true } },
        action = { boost = false },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [5] = { -- (target moved) Boost to avoid target's arc
        description = { text = "%s boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'boost',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Reinforce (stress) the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { hasShot = false, inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceFore'] = true }
    },
    [7] = { -- Reinforce (stress) the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { hasShot = false, inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceAft'] = true }
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Modified TIE/Ln Fighter (Mining Guild)
BehaviourDB.rule_sets[1].ships['modifiedtielnfighter'] = {}
BehaviourDB.rule_sets[1].ships['modifiedtielnfighter'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['modifiedtielnfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k3', [3] = 'bl2', [4] = 'br2', [5] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [6] = 's5' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' },
    },
    front_right = {
        near = { [1] = 'k3', [3] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k3', [2] = 'tr1', [4] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k3', [2] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k3', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [4] = 'tr3' },
        distant = { [1] = 'k3', [5] = 'tr1' },
        stress = { [1] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['modifiedtielnfighter'].flee_table = {
    edge = { nearest = 's5' },
}
BehaviourDB.rule_sets[1].ships['modifiedtielnfighter'].action_selection = {
    [1] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true },
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [5] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- Customized YT-1300 Light Freighter
BehaviourDB.rule_sets[1].ships['customizedyt1300lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['customizedyt1300lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['customizedyt1300lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [2] = 'bl3s', [3] = 'br3s', [4] = 's1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'br1', [5] = 'tl2', [6] = 'bl3' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 's1', [2] = 'bl1', [3] = 'br1', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl3s', [3] = 'bl1', [4] = 'bl2', [5] = 'tr2', [6] = 'tl2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'bl1', [4] = 'br1', [6] = 's3' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 'tr2' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl1', [3] = 'br1', [4] = 's1', [5] = 's2', [6] = 's3' },
    },
    back_right = {
        near = { [1] = 'k4', [2] = 'br3s', [3] = 'bl3s', [5] = 'bl1', [6] = 's1' },
        far = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl1', [3] = 'br1', [4] = 's1', [5] = 's2', [6] = 's3' },
    },
}

BehaviourDB.rule_sets[1].ships['customizedyt1300lightfreighter'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- Boost (stress) to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = { boost = true },
        postconditions = { hasShot = true }
    },
    [4] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Aggressor Assault StarFighter
BehaviourDB.rule_sets[1].ships['aggressorassaultfighter'] = {}
BehaviourDB.rule_sets[1].ships['aggressorassaultfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['aggressorassaultfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl3s', [4] = 'br3s', [5] = 's1', [6] = 's2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'bl3s', [5] = 's1', [6] = 'br1' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'bl3s', [5] = 'tr1' },
        far = { [1] = 'br1', [2] = 'tr1', [4] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'tr1', [2] = 'br2', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [6] = 'br3' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'bl3s', [5] = 'tr1' },
        far = { [1] = 'k4', [2] = 'br3s', [5] = 'tr1' },
        distant = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr1', [5] = 'tr2' },
        stress = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [6] = 'bl3' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'br3s', [4] = 'bl3s', [6] = 'tr2' },
        far = { [1] = 'k4', [3] = 'bl3s', [4] = 'br3s', [6] = 'tr1' },
        distant = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br1', [3] = 'br2', [5] = 'br3', [6] = 'bl3' },
    },
}
BehaviourDB.rule_sets[1].ships['aggressorassaultfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Boost to avoid target's arc and still get a shot
        description = { text = "%s boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = 'boost',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Calculate x2 if you have a shot
        description = "%s has a shot so calculated.",
        preconditions = { hasShot = true },
        action = { calculate = false, calculate = false }
    },
    [5] = { -- (target moved) Boost to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = 'boost',
        postconditions = { hasShot = true }
    },
    [6] = { -- (target moved) Boost to avoid target's arc
        description = { text = "%s boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'boost',
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [8] = { -- Calculate x2
        description = "%s calculated.",
        action = { calculate = false, calculate = false }
    }
}

-- Escape Craft
BehaviourDB.rule_sets[1].ships['escapecraft'] = {}
BehaviourDB.rule_sets[1].ships['escapecraft'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['escapecraft'].move_table = {
    bullseye = {
        near = { [1] = 'k3', [2] = 's0', [4] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k3', [2] = 's0', [3] = 'br1', [5] = 's1', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [3] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k3', [2] = 's0', [3] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'tr2', [3] = 'br2', [4] = 'br3' },
        stress = { [1] = 'br1', [6] = 's1' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 's0', [5] = 'br1', [6] = 'tr2' },
        far = { [1] = 'k3', [3] = 'br1', [4] = 'tr2', [6] = 'br3' },
        distant = { [1] = 'k3', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 's1', [3] = 'br1' },
    },
    back_right = {
        near = { [1] = 'k3', [4] = 's0', [5] = 's2', [6] = 'bl3' },
        far = { [1] = 'k3', [3] = 'br1', [4] = 'tr2', [6] = 'br3' },
        distant = { [1] = 'k3', [3] = 'br1', [4] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['escapecraft'].action_selection = {
    [1] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [3] = { -- Coordinate the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = 'coordinate'
    },
    [4] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}

-- G-1A Starfighter
BehaviourDB.rule_sets[1].ships['g1astarfighter'] = {}
BehaviourDB.rule_sets[1].ships['g1astarfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['g1astarfighter'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 'k4', [5] = 's1' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 's0', [5] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br2', [3] = 's3', [5] = 'br3' },
        stress = { [1] = 's1', [3] = 'br1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'tr1', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'tr2', [6] = 'br2' },
        distant = { [1] = 'tr2', [5] = 'br2', [6] = 'br3' },
        stress = { [1] = 'br1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'k2', [5] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'k2', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'k2', [3] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 'k4', [3] = 'k2', [5] = 'tr2', [6] = 'tl2' },
        far = { [1] = 'k4', [2] = 'k2', [5] = 'tr2' },
        distant = { [1] = 'k2', [4] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['g1astarfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Jam the target
        description = { text = "%s jammed %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = 'jam'
    },
    [5] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}

-- Lancer-class Pursuit Craft
BehaviourDB.rule_sets[1].ships['lancerclasspursuitcraft'] = {}
BehaviourDB.rule_sets[1].ships['lancerclasspursuitcraft'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['lancerclasspursuitcraft'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 's1', [4] = 'tl3', [5] = 'tr3', [6] = 's4' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [3] = 's3', [4] = 's4', [5] = 'tl3', [6] = 'tr3' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'br1', [4] = 's1', [5] = 'bl3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 's2', [3] = 'br3', [5] = 's3', [6] = 'tr3' },
    },
    right_front = {
        near = { [1] = 'k5', [3] = 'br1', [4] = 'tr2', [5] = 'br3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [3] = 'tr3' },
        stress = { [1] = 's2', [2] = 'br3', [4] = 'tr3' },
    },
    right_back = {
        near = { [1] = 'k5', [4] = 'br1', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k5', [3] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k5', [2] = 'tr2', [3] = 'tr3' },
        stress = { [1] = 's2', [2] = 'br3', [4] = 'tr3' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'br1', [4] = 's1', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k5', [3] = 's1', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k5', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 's2', [2] = 'br3', [4] = 'tl3', [5] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['lancerclasspursuitcraft'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [5] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [6] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- M12-L Kimogila Fighter
BehaviourDB.rule_sets[1].ships['m12lkimogilafighter'] = {}
BehaviourDB.rule_sets[1].ships['m12lkimogilafighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['m12lkimogilafighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [6] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [3] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [4] = 'br1', [5] = 'tr1' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 's1', [2] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [4] = 'tr1', [5] = 'br3', [6] = 'tl3' },
        far = { [1] = 'k4', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k4', [3] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 's1', [2] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [4] = 'tr1', [5] = 'tr3', [6] = 'tl3' },
        far = { [1] = 'k4', [5] = 'tr3' },
        distant = { [1] = 'k4', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['m12lkimogilafighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true },
    },
    [5] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a Reload action.",
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Scurrg H-6 Bomber
BehaviourDB.rule_sets[1].ships['scurrgh6bomber'] = {}
BehaviourDB.rule_sets[1].ships['scurrgh6bomber'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['scurrgh6bomber'].move_table = {
    bullseye = {
        near = { [1] = 'tl3t', [2] = 'tr3t', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'tr3t', [2] = 'br1', [4] = 's1', [5] = 'bl2', [6] = 'tl2' },
        far = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br1', [3] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'tr3t', [3] = 'bl1', [5] = 'br1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [4] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'bl1', [3] = 'br1', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 'tr3t', [5] = 'bl1', [6] = 'tr2' },
        far = { [1] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [3] = 'bl1', [5] = 'br1' },
    },
    back_right = {
        near = { [1] = 'tl3t', [2] = 'tr3t', [4] = 's1', [5] = 'bl1', [6] = 'br1' },
        far = { [1] = 'tr3t', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr3t', [3] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [5] = 's1', [6] = 's2' },
    },
}

BehaviourDB.rule_sets[1].ships['scurrgh6bomber'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- YV-666 Light Freighter
BehaviourDB.rule_sets[1].ships['yv666lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['yv666lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['yv666lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 'bl1', [4] = 'br1', [5] = 's1' }
        ,
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 's1', [5] = 'br1', [6] = 's2' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 's1', [2] = 'br1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 's0', [3] = 'br1', [5] = 'br2', [6] = 'tr2' },
        far = { [1] = 'br1', [3] = 'br2', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'br1', [4] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'br1', [3] = 'tr2', [4] = 'tr3' },
        distant = { [1] = 'br1', [3] = 'tr2', [4] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [6] = 'tr3' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 'br1', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 'br1', [3] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'br1', [4] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's3', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['yv666lightfreighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [4] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [5] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- JumpMaster 5000
BehaviourDB.rule_sets[1].ships['jumpmaster5000'] = {}
BehaviourDB.rule_sets[1].ships['jumpmaster5000'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['jumpmaster5000'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl3s', [4] = 's1', [5] = 'tl2', [6] = 'bl3' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [2] = 'bl1', [3] = 's2', [4] = 'bl2', [5] = 's3', [6] = 'bl3' },
    },
    front_right = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'br1', [5] = 's1', [6] = 'tl2' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [5] = 'bl2', [6] = 's2' },
        distant = { [1] = 'bl3', [2] = 'br3', [5] = 's3', [6] = 's4' },
        stress = { [1] = 'bl1', [2] = 's1', [4] = 'bl2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 's1', [6] = 'tr1' },
        far = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [6] = 'tr2' },
        distant = { [1] = 'tr1', [2] = 'br2', [4] = 'tr2', [5] = 'br3' },
        stress = { [1] = 'bl1', [2] = 's1', [4] = 'br2', [5] = 's2' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 'br1', [6] = 'br2' },
        far = { [1] = 'k4', [2] = 'bl3s', [5] = 'br1', [6] = 'tr1' },
        distant = { [1] = 'bl3s', [4] = 'tr1', [5] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'bl1', [3] = 's1', [5] = 'bl2', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 's1', [5] = 'tl1', [6] = 'tl2' },
        far = { [1] = 'k4', [3] = 'bl3s', [5] = 's1', [6] = 'tl2' },
        distant = { [1] = 'k4', [2] = 'bl3s', [4] = 'tl1', [5] = 'tr1', [6] = 'tl2' },
        stress = { [1] = 'bl1', [2] = 's1', [4] = 'bl2', [5] = 's2', [6] = 'bl3' },
    },
    front_left = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'bl1', [5] = 's1', [6] = 'tl2' },
        far = { [1] = 'bl1', [3] = 's1', [4] = 'bl2', [6] = 's2' },
        distant = { [1] = 'bl3', [5] = 's3', [6] = 's4' },
        stress = { [1] = 'bl1', [3] = 's1', [4] = 'bl2', [5] = 's2', [6] = 's3' },
    },
    left_front = {
        near = { [1] = 'k4', [3] = 'bl1', [4] = 'bl2', [5] = 's1', [6] = 'tl1' },
        far = { [1] = 'bl1', [2] = 'tr1', [4] = 'bl2', [5] = 'tr2' },
        distant = { [1] = 'bl2', [2] = 'tl2', [6] = 'bl3' },
        stress = { [1] = 'bl1', [2] = 'bl2', [5] = 'tl2', [6] = 'bl3' },
    },
    left_back = {
        near = { [1] = 'k4', [3] = 'bl3s', [4] = 'bl1', [6] = 'tl1' },
        far = { [1] = 'k4', [3] = 'tl1', [5] = 'tl2' },
        distant = { [1] = 'tl1', [2] = 'bl2', [3] = 'tl2', [6] = 'bl3' },
        stress = { [1] = 'bl1', [3] = 'bl2', [5] = 'bl3' },
    },
    back_left = {
        near = { [1] = 'k4', [3] = 'bl3s', [5] = 'tl1', [6] = 'tl2' },
        far = { [1] = 'k4', [2] = 'bl3s', [3] = 'tl1', [5] = 'tl2' },
        distant = { [1] = 'k4', [2] = 'bl3s', [3] = 'tl1', [6] = 'tl2' },
        stress = { [1] = 'bl1', [4] = 's1', [5] = 'bl2' },
    },
}

BehaviourDB.rule_sets[1].ships['jumpmaster5000'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Target Lock > Rotate turret (stress) to get a shot
        description = { text = "%s target locked %s and rotated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = false },
        action = { targetLock = true, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Focus > Rotate turret (stress) to get a shot
        description = "%s focused and rotated to get a shot.",
        preconditions = { hasShot = false },
        action = { focus = true, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [6] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Quadrijet Transfer Spacetug
BehaviourDB.rule_sets[1].ships['quadrijettransferspacetug'] = {}
BehaviourDB.rule_sets[1].ships['quadrijettransferspacetug'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['quadrijettransferspacetug'].move_table = {
    bullseye = {
        near = { [1] = 'bl2s', [2] = 'br2s', [3] = 's2r', [4] = 'bl1r', [5] = 'br1r', [6] = 's1' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 'bl2', [2] = 'br2', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 's2r', [2] = 'bl1r', [4] = 's1', [5] = 'br1' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 'br2', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl2s', [2] = 'bl1r', [3] = 'br1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'tr1', [2] = 'tr2', [5] = 'br3' },
        stress = { [1] = 'br2', [5] = 's2', [6] = 'tr1' },
    },
    right_back = {
        near = { [1] = 'bl2s', [3] = 's2r', [4] = 'bl1r', [5] = 'tr1' },
        far = { [1] = 'bl2s', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl2s', [3] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 's2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 's2r', [2] = 'bl1r', [3] = 'br2s', [4] = 'bl2s', [6] = 'br3' },
        far = { [1] = 'bl2s', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'bl2s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'bl2', [2] = 'br2', [4] = 's2', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['quadrijettransferspacetug'].action_selection = {
    [1] = { -- Tractor range 1 front arc
        description = { text = "%s tractored %s in forward arc at range 1. Add a 2nd token if in Bullseye", strings = { 'ship', 'target' } },
        preconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = 'tractor',
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Evade (stress)
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = { evade = true }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- ST-70 Assault Ship
BehaviourDB.rule_sets[1].ships['st70assaultship'] = {}
BehaviourDB.rule_sets[1].ships['st70assaultship'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['st70assaultship'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 'k5', [5] = 's1' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [2] = 's2', [4] = 's3', [6] = 's4' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 'k5', [3] = 's1', [4] = 'br1', [5] = 'bl3', [6] = 'tr3' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [5] = 's3', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'k5', [3] = 'tr2t', [4] = 'tr1', [5] = 'tr2', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k5', [2] = 'tr2t', [5] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'k5', [2] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k5', [2] = 'tr2t', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 'k5', [3] = 'tl2t', [4] = 'tr2t', [6] = 'tr2' },
        far = { [1] = 'k5', [2] = 'tr2t', [5] = 'tr2' },
        distant = { [1] = 'tr2t', [3] = 'tr2' },
        stress = { [1] = 's1', [3] = 's2', [5] = 's3', [6] = 's4' },
    },
}

BehaviourDB.rule_sets[1].ships['st70assaultship'].action_selection = {
    [1] = { -- Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [7] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}

-- Rogue-class Starfighter
---- This logic is shared between Scum and CIS. See Z-95 for an example on how to split them if necessary.
BehaviourDB.rule_sets[1].ships['rogueclassstarfighter'] = {}
BehaviourDB.rule_sets[1].ships['rogueclassstarfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['rogueclassstarfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl1', [5] = 'br1' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [4] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'tr2t', [4] = 'tr1' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr1', [2] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'tr1', [3] = 'br1', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k5', [3] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k5', [2] = 'tr2t', [5] = 'tr1' },
        distant = { [1] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'tr1', [2] = 'br1', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'tr2t', [5] = 'tr2' },
        far = { [1] = 'tl2t', [3] = 'tr2t' },
        distant = { [1] = 'tr2t', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'br1', [4] = 'br2' },
    },
}

BehaviourDB.rule_sets[1].ships['rogueclassstarfighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [3] = { -- Focus/Calc > boost or focus/Calc > barrel roll to avoid target's arc and still get a shot
        description = { text = "%s focused/calculated and barrel rolled/boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { focuscalculate = false, boost = true },
            [2] = { focuscalculate = false, barrelRoll = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- (target moved) Focus/Calc if you have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { targetMoved = true, hasShot = true },
        action = 'focuscalculate'
    },
    [5] = { -- (target not moved) Evade > barrel roll to get a shot
        description = { text = "%s evaded and barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, hasShot = false, inTargetsArc = true },
        action = { evade = false, barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true },
        action = 'evade'
    },
    [7] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    },
}


--------------
-- FO Ships --
--------------

-- TIE/fo Fighter
BehaviourDB.rule_sets[1].ships['tiefofighter'] = {}
BehaviourDB.rule_sets[1].ships['tiefofighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiefofighter'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 'bl2', [4] = 'br2', [5] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl2s', [3] = 'tr1', [5] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'bl2s', [4] = 'tr1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'bl2s', [5] = 'tr2' },
        distant = { [1] = 'bl2s', [4] = 'tr1' },
        stress = { [1] = 'tr1', [2] = 'tr2', [6] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr2' },
        far = { [1] = 'br2s', [3] = 'bl2s' },
        distant = { [1] = 'bl2s', [4] = 'tr1' },
        stress = { [1] = 'tl2', [4] = 'tr2', [6] = 's4' },
    },
}
BehaviourDB.rule_sets[1].ships['tiefofighter'].action_selection = {
    [1] = { -- Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- TIE/sf Fighter
BehaviourDB.rule_sets[1].ships['tiesffighter'] = {}
BehaviourDB.rule_sets[1].ships['tiesffighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiesffighter'].move_table = {
    bullseye = {
        near = { [1] = 'br3s', [2] = 'bl3s', [3] = 's1', [5] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl1', [3] = 'br1', [5] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl3s', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl3s', [3] = 'tr1', [4] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [5] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'bl3s', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'br3s', [2] = 'bl3s', [5] = 'tr2' },
        distant = { [1] = 'br3s', [4] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'br3s', [3] = 'bl3s', [5] = 'tr2' },
        far = { [1] = 'br3s', [3] = 'bl3s' },
        distant = { [1] = 'br3s', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'tr2', [5] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['tiesffighter'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Target Lock > Rotate turret to get a shot
        description = { text = "%s target locked %s and rotated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = false },
        action = { targetLock = false, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [3] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Barrel roll > Rotate to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and rotated to still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = false, inTargetsArc = true },
        action = { barrelRoll = false, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [5] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [6] = { -- Focus > Rotate turret to get a shot
        description = "%s focused and rotated to get a shot.",
        preconditions = { hasShot = false },
        action = { focus = false, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true }
    },
    [7] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [8] = { -- Barrel roll > Rotate to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true }
    },
    [9] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [10] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- TIE/se Bomber
BehaviourDB.rule_sets[1].ships['tiesebomber'] = {}
BehaviourDB.rule_sets[1].ships['tiesebomber'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiesebomber'].move_table = {
    bullseye = {
        near = { [1] = 'br3s', [2] = 'bl3s', [3] = 's1', [5] = 's2', [6] = 's4' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'bl3s', [4] = 'br1', [5] = 's1', [6] = 'tl2' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl3s', [3] = 'bl1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 's1', [4] = 's2', [5] = 'tr2', [6] = 'tr3' },
    },
    right_back = {
        near = { [1] = 'bl3s', [3] = 'bl1', [4] = 'tr1', [6] = 'tr3' },
        far = { [1] = 'bl3s', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 's1', [5] = 's2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'br3s', [2] = 'bl3s', [4] = 'bl1', [5] = 's1', [6] = 'tr3' },
        far = { [1] = 'bl3s', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [4] = 'tr2', [5] = 's2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['tiesebomber'].action_selection = {
    [1] = { --  Barrel roll > target lock (stress) to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s barrel rolled and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { inTargetsArc = false, hasShot = true, targetWithinRange = true }
    },
    [2] = { --  Barrel roll > target lock (stress) to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { inTargetsArc = false, hasShot = true }
    },
    [3] = { --  Barrel roll > target lock (stress) to get a shot (with the > target lock)
        description = "%s barrel rolled and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [4] = { --  Barrel roll > target lock (stress) to get a shot (without the > target lock)
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { hasShot = true }
    },
    [5] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [6] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [7] = { -- Boost (stress) to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = { boost = true },
        postconditions = { hasShot = true }
    },
    [8] = { -- Barrel roll or boost (stress) to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { barrelRoll = false },
            [2] = { boost = true },
        },
        postconditions = { inTargetsArc = false }
    },
    [9] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its upgrades, then undo the following action and take a Reload action. Perform a linked Evade (stress) if appropriate.",
    },
    [10] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/vn Silencer
BehaviourDB.rule_sets[1].ships['tievnsilencer'] = {}
BehaviourDB.rule_sets[1].ships['tievnsilencer'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tievnsilencer'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 's2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    front_right = {
        near = { [1] = 'br2', [2] = 's2', [4] = 'bl3', [5] = 'tl3', [6] = 's5' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'tr3t', [4] = 'tr1' },
        far = { [1] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr1' },
        far = { [1] = 'tr3t', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'tr3t', [3] = 'tr1', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tl3t', [4] = 'tr3t', [6] = 'tr3' },
        far = { [1] = 'k4', [2] = 'tr3t', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr3t', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br2', [2] = 'tl2', [3] = 'tr2', [6] = 's5' },
    },
}
BehaviourDB.rule_sets[1].ships['tievnsilencer'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target not moved) Target lock > Boost (stress) or Target Lock > barrel roll (stress) if not in any arcs
        description = { text = "%s target locked %s and boosted/barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = true, targetWithinRange = true },
        action = {
            [1] = { targetLock = false, boost = true },
            [2] = { targetLock = false, barrelRoll = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus > boost (stress) or focus > barrel roll (stress) to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled/boosted and focused to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { focus = false, boost = true },
            [2] = { focus = false, barrelRoll = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Boost > barrel roll (stress) or barrel roll > boost (stress) to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, barrelRoll = true },
            [2] = { barrelRoll = false, boost = true }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [6] = { -- Boost > barrel roll (stress) or barrel roll > boost (stress) to avoid target's arc
        description = { text = "%s barrel rolled > boost/boosted > barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, barrelRoll = true },
            [2] = { barrelRoll = false, boost = true }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- TIE/wi Whisper Modified Interceptor
BehaviourDB.rule_sets[1].ships['tiewiwhispermodifiedinterceptor'] = {}
BehaviourDB.rule_sets[1].ships['tiewiwhispermodifiedinterceptor'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiewiwhispermodifiedinterceptor'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl3s', [4] = 'br3s', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 'bl3', [2] = 'br3', [3] = 's2', [4] = 's3', [5] = 's4', [6] = 's5' },
    },
    front_right = {
        near = { [1] = 'k5', [2] = 'bl3s', [4] = 'br2', [5] = 's2', [6] = 'tl2' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br2', [3] = 's2', [4] = 'br3', [5] = 's3', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl3s', [4] = 'tl1', [5] = 'tr1', [6] = 'bl2' },
        far = { [1] = 'tr2', [3] = 'br2', [4] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [3] = 'tr3' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 'br3' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr1', [5] = 's2', [6] = 'bl2' },
        far = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k4', [2] = 'bl3s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 'br3' },
    },
    back_right = {
        near = { [1] = 'k4', [2] = 'br3s', [3] = 'bl3s', [5] = 's2', [6] = 'bl2' },
        far = { [1] = 'k4', [2] = 'bl3s', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k4', [2] = 'bl3s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['tiewiwhispermodifiedinterceptor'].action_selection = {
    [1] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, inTargetsArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Focus > Jam if you have a shot
        description = "%s has a shot so focused and jammed.",
        preconditions = { hasShot = true, targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = { focus = false, jam = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Focus > Rotate to get a shot
        description = "%s focused and rotated to get a shot.",
        preconditions = { hasShot = false },
        action = { focus = false, rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll/Boost > Jam to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled/boosted to avoid %s's arc and jammed to still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, jam = false },
            [2] = { barrelRoll = false, jam = false }
        },
        postconditions = { hasShot = true, inTargetsArc = false, targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [6] = { -- Barrel roll/Boost > Rotate to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled/boosted to avoid %s's arc and rotated to still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = false, inTargetsArc = true },
        action = {
            [1] = { boost = false, rotateTurret = { mount = 'main' } },
            [2] = { barrelRoll = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [7] = { -- Barrel roll/Boost > Jam to get a shot
        description = "%s barrel rolled/boosted and jammed to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, jam = false },
            [2] = { barrelRoll = false, jam = false }
        },
        postconditions = { hasShot = true, targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [8] = { -- Barrel roll/Boost > Rotate to get a shot
        description = "%s barrel rolled/boosted and rotated to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, rotateTurret = { mount = 'main' } },
            [2] = { barrelRoll = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true }
    },
    [9] = { -- Barrel roll/Boost > Jam to avoid target's arc
        description = "%s barrel rolled/boosted and jammed to avoid target's arc.",
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, jam = false },
            [2] = { barrelRoll = false, jam = false }
        },
        postconditions = { inTargetsArc = false, targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [10] = { -- Barrel roll/Boost > Rotate to avoid target's arc
        description = "%s barrel rolled/boosted and rotated to avoid target's arc.",
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, rotateTurret = { mount = 'main' } },
            [2] = { barrelRoll = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { inTargetsArc = false }
    },
    [11] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    },
}

-- Upsilon-class Shuttle
BehaviourDB.rule_sets[1].ships['upsilonclasscommandshuttle'] = {}
BehaviourDB.rule_sets[1].ships['upsilonclasscommandshuttle'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['upsilonclasscommandshuttle'].action_selection = {}
BehaviourDB.rule_sets[1].ships['upsilonclasscommandshuttle'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 'br1', [4] = 's1', [5] = 'tl2', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [3] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'br1', [3] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'br3', [5] = 'tr3' },
        stress = { [1] = 's1', [3] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [3] = 'tr1', [4] = 'br1', [5] = 'tl2', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [5] = 'br3', [6] = 'tr3' },
        stress = { [1] = 's1', [3] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 's2', [3] = 'tl2', [4] = 'tr2', [5] = 'bl3', [6] = 'br3' },
        far = { [1] = 'tr1', [2] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr1', [2] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's2', [3] = 'br2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['upsilonclasscommandshuttle'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- Reinforce the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceFore'
    },
    [3] = { -- Reinforce the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = 'reinforceAft'
    },
    [4] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Coordinate the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = 'coordinate'
    },
    [6] = { -- Jam the target
        description = { text = "%s jammed %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = 'jam'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- Xi-class Light Shuttle
BehaviourDB.rule_sets[1].ships['xiclasslightshuttle'] = {}
BehaviourDB.rule_sets[1].ships['xiclasslightshuttle'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['xiclasslightshuttle'].action_selection = {}
BehaviourDB.rule_sets[1].ships['xiclasslightshuttle'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 's1', [4] = 'br1', [6] = 'tl2' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'br1', [4] = 'tl2', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 's1', [3] = 'tl2', [4] = 'tr2', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'br3', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [3] = 's1', [4] = 'tl2', [5] = 'tr2', [6] = 'br3' },
        far = { [1] = 'br2', [2] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['xiclasslightshuttle'].action_selection = {
    [1] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [2] = { -- Jam the target
        description = { text = "%s jammed %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = 'jam'
    },
    [3] = { -- (target not moved) Target lock (stress) if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = { targetLock = true }
    },
    [4] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = { coordinate = true }
    },
    [5] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- TIE/ba Interceptor
BehaviourDB.rule_sets[1].ships['tiebainterceptor'] = {}
BehaviourDB.rule_sets[1].ships['tiebainterceptor'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['tiebainterceptor'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl2s', [4] = 'br2s', [5] = 's2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'bl2s', [4] = 'br1', [6] = 'br2' },
        far = { [1] = 'br1', [2] = 's2', [3] = 'br2', [5] = 's3', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [3] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [2] = 'tr1', [5] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k5', [3] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'bl2s', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl2s', [3] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [2] = 'tr1', [6] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'br2s', [4] = 'bl2s', [6] = 'tr3' },
        far = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr1' },
        stress = { [1] = 'br1', [2] = 'tr1', [6] = 'br2' },
    },
}
BehaviourDB.rule_sets[1].ships['tiebainterceptor'].action_selection = {
    [1] = { -- (target moved) Focus > Lock (Deplete/Strain) if you have a shot
        description = "%s has a shot so Focused into Target Lock, taking a Strain.",
        preconditions = { ['targetMoved'] = true, hasShot = true, targetLocked = false },
        action = { ['focus'] = false, ['targetLock'] = false, ['strain'] = false }
    },
    [2] = { --  (target moved) Boost or Barrel roll > Lock (Deplete/Strain) to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s barrel rolled/boosted and target locked to avoid %s's arc and still get a shot, taking a Strain.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, ['targetMoved'] = true, targetLocked = false },
        action = {
            [1] = { ['boost'] = false, ['targetLock'] = false, ['strain'] = false },
            [2] = { ['barrelRoll'] = false, ['targetLock'] = false, ['strain'] = false }
        },
        postconditions = { inTargetsArc = false, hasShot = { arguments = { ['minRange'] = 2 }, requiredResult = true }, targetWithinRange = true },
    },
    [3] = { -- (target moved) Focus > Lock (Deplete/Strain) to get a shot at range 1
        description = "%s focused into a target lock to get a close range shot, taking a Strain.",
        preconditions = { ['targetMoved'] = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = { ['focus'] = false, ['barrelRoll'] = false, ['strain'] = false },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [4] = { -- Boost > barrel roll (Deplete/Strain) to get a shot
        description = "%s boosted into barrel rolled to get a shot, taking a Strain.",
        preconditions = { hasShot = false },
        action = { ['boost'] = false, ['barrelRoll'] = false, ['strain'] = false },
        postconditions = { hasShot = true }
    },
    [5] = { -- (target not moved) Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { ['targetMoved'] = false, hasShot = true, targetLocked = true },
        action = 'focus'
    },
    [6] = { -- (target moved) Barrel roll or boost or Boost > barrel roll (Deplete/Strain) to avoid target's arc
        description = { text = "%s barrel roll/boosted/boosted into barrel roll (taking a Deplete) to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { ['targetMoved'] = true, inTargetsArc = true },
        action = {
            [1] = { ['boost'] = false },
            [2] = { ['barrelRoll'] = false },
            [3] = { ['boost'] = false, ['barrelRoll'] = false, ['deplete'] = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}


----------------------
-- Resistance ships --
----------------------

-- Scavenged YT-1300
BehaviourDB.rule_sets[1].ships['scavengedyt1300lightfreighter'] = {}
BehaviourDB.rule_sets[1].ships['scavengedyt1300lightfreighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['scavengedyt1300lightfreighter'].move_table = {
    bullseye = {
        near = { [1] = 'bl3s', [2] = 'br3s', [3] = 's1', [4] = 'tl3', [5] = 'tr3', [6] = 's4' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'bl3s', [3] = 'bl2', [4] = 'tl2', [5] = 's3', [6] = 'tr3' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br3', [5] = 's3', [6] = 's4' },
        stress = { [1] = 'bl2', [3] = 'br2', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl3s', [2] = 'bl1', [3] = 'bl2', [4] = 's2', [5] = 'br3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'bl2', [3] = 's2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'bl3s', [3] = 'bl1', [4] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'bl3s', [3] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [2] = 'bl2', [4] = 'br2', [6] = 's2' },
    },
    back_right = {
        near = { [1] = 'br3s', [2] = 'bl3s', [4] = 'bl1', [5] = 'tr2' },
        far = { [1] = 'bl3s', [3] = 'tr2', [4] = 'tr3' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [2] = 'bl2', [4] = 'br2', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['scavengedyt1300lightfreighter'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Rotate turret (stress) to get a shot
        description = "%s rotated its turret to get a shot. Add Stress manually",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [5] = { -- Boost (stress) to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = { boost = true },
        postconditions = { hasShot = true },
    },
    [6] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- T-70 X-Wing
BehaviourDB.rule_sets[1].ships['t70xwing'] = {}
BehaviourDB.rule_sets[1].ships['t70xwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['t70xwing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [5] = 's1', [6] = 'tr3' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'tr3t', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr2', [6] = 'tl3' },
        far = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [2] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'tr2', [4] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tl3t', [4] = 'tr3t', [6] = 'tr3' },
        far = { [1] = 'k4', [2] = 'tr3t', [5] = 'tr3' },
        distant = { [1] = 'tr3t', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'bl1', [2] = 'br1', [4] = 'bl2', [5] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['t70xwing'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Boost to avoid target's arc and still get a shot
        description = { text = "%s boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = 'boost',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- (target moved) Boost to get a shot
        description = "%s boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = 'boost',
        postconditions = { hasShot = true }
    },
    [6] = { -- (target moved) Boost to avoid target's arc
        description = { text = "%s boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'boost',
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- BTL-NR2 Y-Wing
BehaviourDB.rule_sets[1].ships['btanr2ywing'] = {}
BehaviourDB.rule_sets[1].ships['btanr2ywing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['btanr2ywing'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'br1', [5] = 's1', [6] = 'bl3' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3', [6] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'br1', [4] = 'bl2', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k5', [3] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k5', [2] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'bl1', [2] = 'br1', [5] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k5', [4] = 's1', [5] = 's2', [6] = 'tr2' },
        far = { [1] = 'k5', [3] = 'br1', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k5', [3] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 'br1', [4] = 's1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['btanr2ywing'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [3] = { -- (target moved) Target lock (stress)
        description = { text = "%s target locked (stress) %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = { targetLock = true }
    },
    [4] = { -- (target moved) Boost (stress) or barrel roll (stress) to get a shot at range 1
        description = "%s barrel rolled/boosted (stress) to get a close range shot.",
        preconditions = { targetMoved = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = true },
            [2] = { barrelRoll = true }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } },
    },
    [5] = { -- (target moved) Boost (stress) or barrel roll (stress) to get a shot
        description = "%s barrel rolled/boosted (stress) to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = true },
            [2] = { barrelRoll = true }
        },
        postconditions = { hasShot = true }
    },
    [6] = { -- Barrel roll (stress) or boost (stress) to avoid target's arc
        description = { text = "%s barrel roll/boosted (stress) to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = true },
            [2] = { barrelRoll = true }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- MG-100 StarFortress SF-17
BehaviourDB.rule_sets[1].ships['mg100starfortress'] = {}
BehaviourDB.rule_sets[1].ships['mg100starfortress'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['mg100starfortress'].move_table = {
    bullseye = {
        near = { [1] = 's0', [3] = 's1', [4] = 's3', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's2', [2] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [3] = 'bl1', [4] = 'br1', [5] = 'bl2', [6] = 'tl2' },
        far = { [1] = 's1', [2] = 'br1', [4] = 's2', [5] = 'br2' },
        distant = { [1] = 'br2', [3] = 's3', [5] = 'br3' },
        stress = { [1] = 's1', [2] = 'bl1', [3] = 'br1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'tr1', [2] = 'bl1', [3] = 'br1', [4] = 'bl2', [5] = 'br2', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'tr2', [6] = 'br2' },
        distant = { [1] = 'tr2', [4] = 'br2', [6] = 'br3' },
        stress = { [1] = 'bl1', [3] = 'br1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'bl1', [3] = 'br1', [4] = 's1', [5] = 'tr2' },
        far = { [1] = 's1', [2] = 'bl1', [3] = 'br1', [5] = 'tr2' },
        distant = { [1] = 'br2', [3] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 's1', [3] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 's1', [3] = 'bl1', [4] = 'br1', [5] = 's2', [6] = 'tr2' },
        far = { [1] = 's0', [2] = 's1', [3] = 'br1', [4] = 'tl2', [5] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tl2', [3] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 'br1', [4] = 's1', [6] = 's2' },
    },
}
BehaviourDB.rule_sets[1].ships['mg100starfortress'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [5] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a Reload action.",
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Resistance Transport
BehaviourDB.rule_sets[1].ships['resistancetransport'] = {}
BehaviourDB.rule_sets[1].ships['resistancetransport'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['resistancetransport'].action_selection = {}
BehaviourDB.rule_sets[1].ships['resistancetransport'].move_table = {
    bullseye = {
        near = { [1] = 's0', [2] = 'bl1r', [3] = 'br1r', [4] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 'bl1r', [4] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br2', [3] = 's3', [4] = 'br3', [6] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 's0', [2] = 'bl1r', [4] = 'tr1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'br2', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'bl1r', [4] = 'br1', [5] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'bl1r', [3] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'bl1r', [3] = 'br2', [4] = 'tr2' },
        stress = { [1] = 's1', [2] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 'br1r', [3] = 'bl1r', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'br1r', [2] = 'bl1r', [4] = 'tl2', [5] = 'tr2' },
        distant = { [1] = 'bl1r', [2] = 'tr1', [3] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['resistancetransport'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [4] = { -- Focus if have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [5] = { -- Coordinate (stress) the nearest friendly (unstressed) ship
        description = { text = "%s coordinated (stress) %s.", strings = { 'ship', 'coordinate' } },
        preconditions = { hasCoordinateTarget = true },
        action = { coordinate = true }
    },
    [6] = { -- Jam (stress) the target
        description = { text = "%s jammed (stress) %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = { jam = true }
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

-- Resistance Transport Pod
BehaviourDB.rule_sets[1].ships['resistancetransportpod'] = {}
BehaviourDB.rule_sets[1].ships['resistancetransportpod'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['resistancetransportpod'].move_table = {
    bullseye = {
        near = { [1] = 'k3', [2] = 's1', [4] = 's2', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k3', [3] = 'br1', [5] = 's1', [6] = 'tl2' },
        far = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 'br3' },
        distant = { [1] = 'br2', [3] = 's3', [5] = 'br3', [6] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'k3', [3] = 'br1', [4] = 'tr1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'br2', [3] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'tr1', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k3', [2] = 'tr1', [4] = 'tr2' },
        distant = { [1] = 'k3', [2] = 'br2', [3] = 'tr2' },
        stress = { [1] = 's1', [2] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k3', [4] = 'tl2', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr1', [4] = 'tr2' },
        distant = { [1] = 'k3', [2] = 'tr1', [3] = 'tr2' },
        stress = { [1] = 'bl1', [3] = 'br1', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['resistancetransportpod'].action_selection = {
    [1] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [2] = { -- (target moved) Target lock (stress)
        description = { text = "%s target locked (stress) %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = { targetLock = true }
    },
    [3] = { -- Barrel roll (stress) to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Jam (stress) the target
        description = { text = "%s jammed (stress) %s.", strings = { 'ship', 'target' } },
        preconditions = { targetWithinRange = { arguments = { maxRange = 1 }, requiredResult = true } },
        action = { jam = true }
    },
    [7] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    }
}

-- RZ-2 A-Wing
BehaviourDB.rule_sets[1].ships['rz2awing'] = {}
BehaviourDB.rule_sets[1].ships['rz2awing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['rz2awing'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 's2', [4] = 'tl3', [5] = 'tr3', [6] = 's5' },
        far = { [1] = 's2', [4] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [2] = 'bl3', [3] = 'br3', [4] = 's3', [5] = 's4', [6] = 's5' },
    },
    front_right = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'bl3', [4] = 'br3', [5] = 'tr3', [6] = 's4' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [4] = 's4', [6] = 's5' },
        stress = { [1] = 'br2', [3] = 's2', [4] = 'bl3', [5] = 'br3', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'tr1', [5] = 'bl2', [6] = 's3' },
        far = { [1] = 'br2', [3] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [2] = 'tr2', [5] = 'br3', [6] = 's3' },
    },
    right_back = {
        near = { [1] = 'k5', [2] = 'bl3s', [4] = 'tr1', [5] = 'bl2', [6] = 's2' },
        far = { [1] = 'k5', [2] = 'bl3s', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'bl3s', [3] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'bl2', [2] = 'tr2', [6] = 'br3' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'br3s', [4] = 'bl3s', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k5', [2] = 'bl3s', [4] = 'tl2', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k5', [2] = 'bl3s', [3] = 'tr1', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br2', [2] = 'tl2', [4] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['rz2awing'].action_selection = {
    [1] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, inTargetsArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock > Boost/Rotate (stress) to get a shot
        description = { text = "%s target locked %s and boosted/rotated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, inTargetsArc = false, targetWithinRange = true, hasShot = false },
        action = {
            [1] = { targetLock = false, boost = true },
            [2] = { targetLock = true, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Focus > Boost/Rotate (stress) to get a shot
        description = "%s focused and boosted/rotated to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { focus = false, boost = true },
            [2] = { focus = true, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [6] = { -- Barrel roll > Boost/Rotate to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and boosted/rotated to still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = false, inTargetsArc = true },
        action = {
            [1] = { barrelRoll = false, boost = true },
            [2] = { barrelRoll = true, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [7] = { -- (target moved) Boost or barrel roll or barrel roll > Boost to get a shot
        description = "%s barrel rolled/boosted or both to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false },
            [3] = { barrelRoll = false, boost = true }
        },
        postconditions = { hasShot = true }
    },
    [8] = { -- (target not moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = false },
        action = 'targetLock'
    },
    [9] = { -- (target not moved) Target lock > Boost/Rotate (stress) to get a shot
        description = { text = "%s target locked %s and boosted/rotated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = false },
        action = {
            [1] = { targetLock = false, boost = true },
            [2] = { targetLock = true, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [10] = { -- Boost or barrel roll or barrel roll > Boost avoid target's arc
        description = "%s barrel rolled/boosted or both to avoid arcs.",
        preconditions = { inEnemyArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false },
            [3] = { barrelRoll = false, boost = true }
        },
        postconditions = { inEnemyArc = false }
    },
    [11] = { -- Evade
        description = "%s evaded.",
        action = 'evade'
    }
}

-- Fireball
BehaviourDB.rule_sets[1].ships['fireball'] = {}
BehaviourDB.rule_sets[1].ships['fireball'].target_selection = { [1] = 'ClosestInArc', [2] = 'Closest' }
BehaviourDB.rule_sets[1].ships['fireball'].move_table = {
    bullseye = {
        near = { [1] = 's1', [4] = 's2', [5] = 'bl3', [6] = 'br3' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [6] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'tr3t', [2] = 's1', [3] = 'br1', [5] = 'tl2', [6] = 'br3' },
        far = { [1] = 'br1', [3] = 's2', [4] = 'br2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3', [6] = 's4' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2' },
    },
    right_front = {
        near = { [1] = 'tr3t', [3] = 'br1', [4] = 'tr1', [6] = 'br3' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 'br1', [4] = 's1', [5] = 's2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'tr1', [6] = 'br3' },
        far = { [1] = 'tr3t', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'tr3t', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's1', [3] = 'br1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'tl3t', [2] = 'tr3t', [5] = 'tr2', [6] = 'br3' },
        far = { [1] = 'tr3t', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'tr3t', [3] = 'tr1', [5] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['fireball'].action_selection = {
    [1] = { -- SLAM if no shot and target outside of range 2
        description = "%s took a SLAM action. Perform the appropriate SLAM movement manually.",
        preconditions = { hasShot = false, targetWithinRange = { arguments = { maxRange = 2 }, requiredResult = false } },
        action = 'disarm'
    },
    [2] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false },
        postconditions = { hasShot = true }
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [5] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    }
}


--------------------
-- Republic ships --
--------------------

-- BTL-B Y-Wing
BehaviourDB.rule_sets[1].ships['btlbywing'] = {}
BehaviourDB.rule_sets[1].ships['btlbywing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['btlbywing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [3] = 's1', [6] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [4] = 's1', [5] = 'bl2', [6] = 'tl2' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'bl1', [3] = 's1', [4] = 'tl2', [5] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'bl1', [4] = 's1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'br1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 's1', [4] = 'tr2', [5] = 's2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 's1', [4] = 'tr2', [6] = 'br3' },
        far = { [1] = 'k4', [3] = 'tr2' },
        distant = { [1] = 'k4', [3] = 'tr2' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['btlbywing'].action_selection = {
    [1] = { --  manual Rotate (upgrade) prompt
        pass_through = true,
        description =
        "If %s has a turret indicator and can get a shot by rotating, then undo the following action and take a Rotate action.",
    },
    [2] = { -- Target lock if charges left
        description = { text = "%s target locked %s. If %s has no charges on its missile or torpedo upgrades, then undo this action and perform it manually.", strings = { 'ship', 'target', 'ship' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus/Calc if have a shot
        description = "%s has a shot so focused/calculated.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { --  Reload ordnance (stress) if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a red Reload action.",
    },
    [6] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    }
}

-- V-19 Torrent Starfighter
BehaviourDB.rule_sets[1].ships['v19torrentstarfighter'] = {}
BehaviourDB.rule_sets[1].ships['v19torrentstarfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['v19torrentstarfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k3', [3] = 's1', [4] = 's2', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [6] = 's3' },
    },
    front_right = {
        near = { [1] = 'k3', [3] = 'br1', [5] = 's1', [6] = 'tl2' },
        far = { [1] = 'br1', [2] = 's2', [3] = 'br2', [5] = 's3', [6] = 'br3' },
        distant = { [1] = 's3', [3] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 's1', [4] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k3', [2] = 'tr2t', [3] = 'tr1', [5] = 'br1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [6] = 'br3' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k3', [3] = 'tr2t', [5] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'k3', [2] = 'tr2t', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k3', [2] = 'tr2t', [3] = 'br2', [4] = 'tr2' },
        stress = { [1] = 'br1', [5] = 's1', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k3', [2] = 'tl2t', [3] = 'tr2t', [5] = 'tl2', [6] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr2t', [5] = 'tr2' },
        distant = { [1] = 'k3', [2] = 'tr2t', [3] = 'tr2' },
        stress = { [1] = 'bl1', [2] = 'br1', [5] = 's1', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['v19torrentstarfighter'].action_selection = {
    [1] = { -- Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll > Evade (stress) to get a shot and defend
        description = "%s barrel rolled into an evade (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false, evade = true },
        postconditions = { hasShot = true, inTargetsArc = true }
    },
    [5] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [6] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Nimbus-class V-Wing
BehaviourDB.rule_sets[1].ships['nimbusclassvwing'] = {}
BehaviourDB.rule_sets[1].ships['nimbusclassvwing'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['nimbusclassvwing'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 's2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 'br1', [5] = 's2', [6] = 'tr3' },
        far = { [1] = 'br2', [3] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 'br2', [3] = 's2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'br2', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'k2', [5] = 'tr1', [6] = 'tr3' },
        far = { [1] = 'k4', [2] = 'k2', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'k2', [2] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 'k4', [2] = 'k2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k2', [4] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br2', [2] = 'tl2', [4] = 'tr2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['nimbusclassvwing'].action_selection = {
    [1] = { --  Boost > target lock (stress) to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s boosted and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = false },
        action = { boost = false, targetLock = true },
        postconditions = { inTargetsArc = false, hasShot = true, targetWithinRange = true }
    },
    [2] = { --  Boost > target lock (stress) to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s boosted to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = true },
        action = { boost = false },
        postconditions = { inTargetsArc = false, hasShot = true }
    },
    [3] = { --  Boost > target lock (stress) to get a shot (with the > target lock)
        description = "%s boosted and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = { boost = false, targetLock = true },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [4] = { --  Boost > target lock (stress) to get a shot (without the > target lock)
        description = "%s boosted to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = { boost = false },
        postconditions = { hasShot = true }
    },
    [5] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        inTargetsArc = false,
        hasShot = true,
        action = 'targetLock'
    },
    [6] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [7] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Delta-7 Aethersprite
BehaviourDB.rule_sets[1].ships['delta7aethersprite'] = {}
BehaviourDB.rule_sets[1].ships['delta7aethersprite'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['delta7aethersprite'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl2s', [4] = 'br2s', [5] = 's2', [6] = 's5' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'bl2s', [5] = 'br1' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [5] = 'br3' },
        stress = { [1] = 'br1', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'k4', [2] = 'bl2s', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl2s', [3] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'tr1', [5] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr2', [6] = 'br3' },
        far = { [1] = 'k4', [2] = 'bl2s', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k4', [2] = 'bl2s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'bl2', [3] = 'br2', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['delta7aethersprite'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target not moved) Target lock > Boost (Force) or Target Lock > barrel roll (Force) if not in any arcs
        description = { text = "%s target locked %s and boosted/barrel rolled (Force) to avoid %s's arc and still get a shot.", strings = { 'ship', 'target', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = true, targetWithinRange = true },
        action = {
            [1] = { targetLock = false, boost = false },
            [2] = { targetLock = false, barrelRoll = false }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus > boost (Force) or focus > barrel roll (Force) to avoid target's arc and still get a shot
        description = { text = "%s focused and barrel rolled/boosted (Force) to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { focus = false, boost = false },
            [2] = { focus = false, barrelRoll = false }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Boost > barrel roll (Force) or barrel roll > boost (Force) to get a shot
        description = "%s barrel rolled/boosted (Force) to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, barrelRoll = false },
            [2] = { barrelRoll = false, boost = false }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [6] = { -- Boost > barrel roll (Force) or barrel roll > boost (Force) to avoid target's arc
        description = { text = "%s barrel rolled > boost/boosted > barrel rolled (Force) to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, barrelRoll = false },
            [2] = { barrelRoll = false, boost = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [8] = { -- Evade (Force)
        description = "%s evaded (Force).",
        preconditions = { evading = false },
        action = 'evade'
    },
    [9] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Delta-7b Aethersprite
BehaviourDB.rule_sets[1].ships['delta7baethersprite'] = {}
BehaviourDB.rule_sets[1].ships['delta7baethersprite'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['delta7baethersprite'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl2s', [4] = 'br2s', [5] = 's2', [6] = 's5' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'bl2s', [5] = 'br1' },
        far = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 'br1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'br1', [3] = 'br2', [5] = 'tr2' },
        distant = { [1] = 'br2', [2] = 'tr2', [5] = 'br3' },
        stress = { [1] = 'br1', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr1' },
        far = { [1] = 'k4', [2] = 'bl2s', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl2s', [3] = 'tr1', [4] = 'tr2' },
        stress = { [1] = 'br1', [4] = 'tr1', [5] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'bl2s', [5] = 'tr2', [6] = 'br3' },
        far = { [1] = 'k4', [2] = 'bl2s', [4] = 'tr1', [5] = 'tr2' },
        distant = { [1] = 'k4', [2] = 'bl2s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br1', [2] = 'bl2', [3] = 'br2', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['delta7baethersprite'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target not moved) Target lock > Boost (Force) or Target Lock > barrel roll (Force) if not in any arcs
        description = { text = "%s target locked %s and boosted/barrel rolled (Force) to avoid %s's arc and still get a shot.", strings = { 'ship', 'target', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = true, targetWithinRange = true },
        action = {
            [1] = { targetLock = false, boost = false },
            [2] = { targetLock = false, barrelRoll = false }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus > boost (Force) or focus > barrel roll (Force) to avoid target's arc and still get a shot
        description = { text = "%s focused and barrel rolled/boosted (Force) to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { focus = false, boost = false },
            [2] = { focus = false, barrelRoll = false }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [4] = { -- Boost > barrel roll (Force) or barrel roll > boost (Force) to get a shot
        description = "%s barrel rolled/boosted (Force) to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, barrelRoll = false },
            [2] = { barrelRoll = false, boost = false }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [6] = { -- Boost > barrel roll (Force) or barrel roll > boost (Force) to avoid target's arc
        description = { text = "%s barrel rolled > boost/boosted > barrel rolled (Force) to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false, barrelRoll = false },
            [2] = { barrelRoll = false, boost = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [8] = { -- Evade (Force)
        description = "%s evaded (Force).",
        preconditions = { evading = false },
        action = 'evade'
    },
    [9] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Eta-2 Actis-class Interceptor
BehaviourDB.rule_sets[1].ships['eta2actis'] = {}
BehaviourDB.rule_sets[1].ships['eta2actis'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['eta2actis'].action_selection = {}
BehaviourDB.rule_sets[1].ships['eta2actis'].move_table = {
    bullseye = {
        near = { [1] = 'k4', [4] = 's2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k4', [4] = 's2', [5] = 'br2', [6] = 'tl3' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [4] = 's4', [6] = 's5' },
        stress = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k4', [3] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [5] = 'br3' },
    },
    right_back = {
        near = { [1] = 'k4', [3] = 'tr2t', [5] = 'tr1' },
        far = { [1] = 'k4', [2] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'k4', [2] = 'tr2t', [3] = 'tr1', [4] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'br2', [5] = 'br3' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'tl2t', [4] = 'tr2t', [6] = 'tr3' },
        far = { [1] = 'k4', [2] = 'tr2t', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k4', [2] = 'tr2t', [4] = 'tr1' },
        stress = { [1] = 'br2', [3] = 'tr2', [4] = 'br3', [6] = 's4' },
    },
}
BehaviourDB.rule_sets[1].ships['eta2actis'].action_selection = {
    [1] = { -- (target moved) Boost or barrel roll to get a shot at range 1
        description = "%s barrel rolled/boosted to get a close range shot.",
        preconditions = { targetMoved = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } },
    },
    [2] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [3] = { -- (target moved) Boost or barrel roll to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = true },
    },
    [4] = { -- Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false },
    },
    [5] = { -- Evade
        description = "%s evaded.",
        preconditions = { evading = false },
        action = 'evade'
    },
    [6] = { -- (target moved) Target lock (Force)
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- LAAT/i Gunship
BehaviourDB.rule_sets[1].ships['laatigunship'] = {}
BehaviourDB.rule_sets[1].ships['laatigunship'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['laatigunship'].move_table = {
    bullseye = {
        near = { [1] = 's0', [2] = 's1', [3] = 'tl2', [4] = 'tr2', [5] = 'bl3', [6] = 'br3' },
        far = { [1] = 's1', [3] = 's2', [6] = 's3' },
        distant = { [1] = 's3', [4] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 'bl1', [3] = 's1', [4] = 'tl2', [5] = 'tr2', [6] = 'bl3' },
        far = { [1] = 's1', [2] = 'br1', [3] = 's2', [4] = 'br2', [6] = 'br3' },
        distant = { [1] = 'br3', [5] = 's3' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'bl1', [2] = 'br1', [3] = 's1', [4] = 'bl2', [5] = 'br2', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 's1', [3] = 's2', [6] = 'bl2' },
    },
    right_back = {
        near = { [1] = 's0', [2] = 'bl1', [3] = 'br1', [4] = 's1', [5] = 'tr2' },
        far = { [1] = 's1', [2] = 'bl1', [3] = 'br1', [4] = 'tr2' },
        distant = { [1] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'bl2' },
    },
    back_right = {
        near = { [1] = 's0', [2] = 's1', [3] = 'bl1', [4] = 'tr2', [6] = 's2' },
        far = { [1] = 's0', [2] = 's1', [4] = 'bl1', [5] = 'tr2' },
        distant = { [1] = 'tr2', [6] = 'br3' },
        stress = { [1] = 's1', [4] = 's2', [6] = 'br3' },
    },
}
BehaviourDB.rule_sets[1].ships['laatigunship'].action_selection = {
    [1] = { -- Rotate turret to get a shot
        description = "%s rotated its turret to get a shot.",
        preconditions = { hasShot = false },
        action = { rotateTurret = { mount = 'main' } },
        postconditions = { hasShot = true },
    },
    [2] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [4] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [5] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a Reload action.",
    },
    [6] = { -- Reinforce (stress) the fore if within arc of two or more enemies in that full arc
        description = "%s reinforced (stress) fore.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullfront', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceFore'] = true }
    },
    [7] = { -- Reinforce (stress) the aft if within arc of two or more enemies in that full arc
        description = "%s reinforced (stress) aft.",
        preconditions = { inEnemyArc = { arguments = { arc = 'fullback', enemyCount = 2 }, requiredResult = true } },
        action = { ['reinforceAft'] = true }
    },
    [8] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Naboo Royal N-1 Starfighter
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'] = {}
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'].action_selection = {}
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'].move_table = {
    bullseye = {
        near = { [1] = 's1', [3] = 's2', [4] = 'tl3', [5] = 'tr3', [6] = 's5' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'br1', [2] = 's1', [3] = 's2', [4] = 'bl3', [5] = 'tl3', [6] = 's5' },
        far = { [1] = 'br1', [2] = 's2', [3] = 'br2', [5] = 's3', [6] = 'br3' },
        distant = { [1] = 'br3', [4] = 's4', [6] = 's5' },
        stress = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'tr3t', [3] = 'br1', [4] = 'tr2', [5] = 'br3', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [4] = 'tr2', [5] = 'br3' },
    },
    right_back = {
        near = { [1] = 'tr3t', [4] = 'tr2', [5] = 'br3', [6] = 'tr3' },
        far = { [1] = 'tr3t', [3] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr3t', [2] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'bl3', [4] = 'br3' },
    },
    back_right = {
        near = { [1] = 'tl3t', [2] = 'tr3t', [4] = 'br3', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 'tr3t', [3] = 'tr2', [4] = 'tr3' },
        distant = { [1] = 'tr3t', [3] = 'tr2', [5] = 'tr3' },
        stress = { [1] = 'br2', [3] = 'bl3', [4] = 'br3', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'].action_selection = {
    [1] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Boost or barrel roll to get a shot at range 1
        description = "%s barrel rolled/boosted to get a close range shot.",
        preconditions = { targetMoved = true, hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } },
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- (target moved) Boost or barrel roll to get a shot
        description = "%s barrel rolled/boosted to get a shot.",
        preconditions = { targetMoved = true, hasShot = false },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { hasShot = true },
    },
    [5] = { -- Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false },
    },
    [6] = { -- Evade, if not already
        description = "%s evaded.",
        preconditions = { evading = false },
        action = 'evade'
    },
    [7] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}
BehaviourDB.rule_sets[1].ships['nabooroyaln1starfighter'].special_rules = { 'fullThrottle' }


-- Clone Z-95 Headhunter.
BehaviourDB.rule_sets[1].ships['clonez95headhunter'] = {}
BehaviourDB.rule_sets[1].ships['clonez95headhunter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['clonez95headhunter'].action_selection = {}
BehaviourDB.rule_sets[1].ships['clonez95headhunter'].move_table = {
    bullseye = {
        near = { [1] = 'k3', [3] = 's1', [5] = 's2' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [4] = 's2' },
    },
    front_right = {
        near = { [1] = 'k4', [3] = 'br1', [6] = 'br2' },
        far = { [1] = 'br2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [3] = 'br2', [4] = 's2' },
    },
    right_front = {
        near = { [1] = 'k4', [2] = 'k3', [4] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'br2' },
    },
    right_back = {
        near = { [1] = 'k3', [4] = 'br1', [5] = 'tr2' },
        far = { [1] = 'k4', [2] = 'k3', [5] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr3' },
        stress = { [1] = 'tr2', [3] = 'br2' },
    },
    back_right = {
        near = { [1] = 'k4', [3] = 'k3', [5] = 'tr2' },
        far = { [1] = 'k3', [3] = 'tr2' },
        distant = { [1] = 'k3', [4] = 'tr2' },
        stress = { [1] = 's1', [3] = 'br2', [6] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['clonez95headhunter'].action_selection = {
    [1] = { -- Target lock if not in enemy's arc
        description = { text = "%s target locked %s outside target's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true, hasShot = true },
        action = 'targetLock'
    },
    [2] = { -- Barrel roll (stress) to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}


---------------
-- CIS ships --
---------------

-- Hyena-class Droid Bomber
BehaviourDB.rule_sets[1].ships['hyenaclassdroidbomber'] = {}
BehaviourDB.rule_sets[1].ships['hyenaclassdroidbomber'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['hyenaclassdroidbomber'].move_table = {
    bullseye = {
        near = { [1] = 's1', [3] = 's2', [4] = 'tl2', [5] = 'tr2', [6] = 's4' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [4] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k2', [2] = 's1', [3] = 'br1', [5] = 'tl2', [6] = 'tr3' },
        far = { [1] = 'br1', [2] = 's2', [3] = 'br2', [6] = 's3' },
        distant = { [1] = 'br2', [4] = 's4', [6] = 's5' },
        stress = { [1] = 's2', [4] = 'tl2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'k2', [2] = 'tr2t', [3] = 'br1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br2', [2] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [3] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k2', [3] = 'tr2t', [5] = 'tr1' },
        far = { [1] = 'k2', [2] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'tr2t', [2] = 'tr2', [3] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k2', [3] = 'tl2t', [4] = 'tr2t', [6] = 'tl3' },
        far = { [1] = 'k2', [3] = 'tr2t', [6] = 'tr3' },
        distant = { [1] = 'k2', [2] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'tr1', [2] = 'tl2', [3] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['hyenaclassdroidbomber'].action_selection = {
    [1] = { --  Barrel roll > target lock (stress) to avoid target arc and still get a shot (with the > target lock)
        description = { text = "%s barrel rolled and target locked to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { inTargetsArc = false, hasShot = true, targetWithinRange = true }
    },
    [2] = { --  Barrel roll > target lock (stress) to avoid target arc and still get a shot (without the > target lock)
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true, hasShot = true, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { inTargetsArc = false, hasShot = true }
    },
    [3] = { --  Barrel roll > target lock (stress) to get a shot (with the > target lock)
        description = "%s barrel rolled and target locked to get a shot.",
        preconditions = { hasShot = false, targetLocked = false },
        action = { barrelRoll = false, targetLock = true },
        postconditions = { hasShot = true, targetWithinRange = true }
    },
    [4] = { --  Barrel roll > target lock (stress) to get a shot (without the > target lock)
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false, targetLocked = true },
        action = { barrelRoll = false },
        postconditions = { hasShot = true }
    },
    [5] = { -- Calculate if you have a shot
        description = "%s has a shot so calculated.",
        preconditions = { hasShot = true },
        action = 'calculate'
    },
    [6] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [7] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [8] = { --  Reload ordnance if no charges left
        pass_through = true,
        description =
        "If %s has no charges on its missile or torpedo upgrades, then undo the following action and take a red reload action.",
    },
    [9] = { -- Calculate
        description = "%s calculated.",
        action = 'calculate'
    }
}

-- Vulture-class Droid Fighter
BehaviourDB.rule_sets[1].ships['vultureclassdroidfighter'] = {}
BehaviourDB.rule_sets[1].ships['vultureclassdroidfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['vultureclassdroidfighter'].move_table = {
    bullseye = {
        near = { [1] = 's2', [2] = 'tl2', [3] = 'tr2', [4] = 'tl3', [5] = 'tr3', [6] = 's5' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    front_right = {
        near = { [1] = 's2', [2] = 'br2', [3] = 'tl3', [4] = 'tr3', [5] = 's4', [6] = 's5' },
        far = { [1] = 's2', [2] = 'br2', [5] = 's3', [6] = 'br3' },
        distant = { [1] = 'br2', [3] = 'br3', [4] = 's4', [5] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 'k1', [3] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [5] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k1', [3] = 'tr2t', [5] = 'tr1' },
        far = { [1] = 'k1', [2] = 'tr2t', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'tr2t', [2] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr1', [2] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k1', [3] = 'tl2t', [4] = 'tr2t', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k1', [2] = 'tr2t', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'k1', [2] = 'tr2t', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'tl2', [3] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['vultureclassdroidfighter'].action_selection = {
    [1] = { -- (target moved) Barrel roll > Calculate (stress) to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled and calculated to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = { barrelRoll = true, calculate = false },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- (target moved) Barrel roll > Calculate (stress) to get a shot
        description = { text = "%s barrel rolled and calculated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = false },
        action = { barrelRoll = true, calculate = false },
        postconditions = { hasShot = true }
    },
    [3] = { -- Calculate if you have a shot
        description = "%s has a shot so calculated.",
        preconditions = { hasShot = true },
        action = 'calculate'
    },
    [4] = { -- (target not moved) Target lock if not in target's arc
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inTargetsArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [5] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        hasShot = true,
        action = 'targetLock'
    },
    [6] = { -- (target moved) Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false },
        hasShot = false
    },
    [7] = { -- Calculate
        description = "%s calculated.",
        action = 'calculate'
    }
}

-- Belbullab-22 Starfighter
BehaviourDB.rule_sets[1].ships['belbulab22starfighter'] = {}
BehaviourDB.rule_sets[1].ships['belbulab22starfighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['belbulab22starfighter'].move_table = {
    bullseye = {
        near = { [1] = 'bl3s', [3] = 'br3s', [5] = 's2', [6] = 's5' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'br3s', [2] = 'bl3s', [4] = 'br1', [6] = 's2' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 'br2', [3] = 's2', [5] = 's3' },
    },
    right_front = {
        near = { [1] = 'bl3s', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr2', [4] = 'br2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'br3', [5] = 'tr3' },
        stress = { [1] = 's2', [2] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'bl3s', [4] = 'tr1', [6] = 'br3' },
        far = { [1] = 'bl3s', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl3s', [3] = 'tr1', [4] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 's2', [2] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'br3s', [2] = 'bl3s', [5] = 'tl2', [6] = 'br3' },
        far = { [1] = 'bl3s', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'bl3s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'bl2', [2] = 'br2', [5] = 'tr2', [6] = 's3' },
    },
}
BehaviourDB.rule_sets[1].ships['belbulab22starfighter'].action_selection = {
    [1] = { -- Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- Boost or barrel roll > Focus/Calc (stress) to avoid Target arc and still get a shot
        description =
        "%s barrel rolled/boosted into a focus/calculate (stress) to avoid target's arc and still get a shot.",
        preconditions = { hasShot = true, inTargetsArc = true },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- Boost or barrel roll > Focus/Calc (stress) to get a shot at range 1
        description = "%s barrel rolled/boosted into a focus/calculate (stress) to get a close range shot.",
        preconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = false } },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = { arguments = { maxRange = 1 }, requiredResult = true } }
    },
    [4] = { -- Boost or barrel roll > Focus/Calc (stress) to get a shot
        description = "%s barrel rolled/boosted into a focus/calculate (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = {
            [1] = { boost = false, focuscalculate = true },
            [2] = { barrelRoll = false, focuscalculate = true }
        },
        postconditions = { hasShot = true }
    },
    [5] = { -- Focus/Calc if you have a shot
        description = "%s has a shot so focused/calculate.",
        preconditions = { hasShot = true },
        action = 'focuscalculate'
    },
    [6] = { -- Barrel roll or boost to avoid target's arc
        description = { text = "%s barrel roll/boosted to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = {
            [1] = { boost = false },
            [2] = { barrelRoll = false }
        },
        postconditions = { inTargetsArc = false }
    },
    [7] = { -- Focus/Calc
        description = "%s focused/calculated.",
        action = 'focuscalculate'
    }
}

-- Droid Tri-Fighter
BehaviourDB.rule_sets[1].ships['droidtrifighter'] = {}
BehaviourDB.rule_sets[1].ships['droidtrifighter'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['droidtrifighter'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [4] = 's2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'k3', [4] = 's2', [5] = 'tl3', [6] = 'tr3' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 's2', [4] = 's3', [6] = 's4' },
    },
    right_front = {
        near = { [1] = 'k5', [3] = 'tr1t', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'tr1', [2] = 'tr2', [4] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'tr3' },
    },
    right_back = {
        near = { [1] = 'k3', [2] = 'tr1t', [5] = 'tr1' },
        far = { [1] = 'k3', [2] = 'tr1t', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'tr1t', [3] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'tr2', [4] = 'tr3' },
    },
    back_right = {
        near = { [1] = 'k3', [2] = 'tl1t', [3] = 'tr1t', [5] = 'tr3' },
        far = { [1] = 'k3', [2] = 'tr1t', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr1t', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'tl2', [2] = 'tr2', [4] = 'tl3', [5] = 'tr3' },
    },
}
BehaviourDB.rule_sets[1].ships['droidtrifighter'].action_selection = {
    [1] = { -- Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Boost > Calculate (stress) to avoid target's arc and still get a shot
        description = { text = "%s boosted and calculated to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = true, inTargetsArc = true },
        action = { boost = true, calculate = true },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [3] = { -- (target moved) Boost > Calculate (stress) to get a shot
        description = { text = "%s boosted and calculated to get a shot.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, hasShot = false },
        action = { boost = false, calculate = true },
        postconditions = { hasShot = true }
    },
    [4] = { -- Calculate if you have a shot
        description = "%s has a shot so calculated.",
        preconditions = { hasShot = true },
        action = 'calculate'
    },
    [5] = { -- Barrel roll to avoid target's arc and still get a shot
        description = { text = "%s barrel rolled to avoid %s's arc and still get a shot.", strings = { 'ship', 'target' } },
        preconditions = { hasShot = true, inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [6] = { -- Barrel roll > Evade (stress) to get a shot and defend
        description = "%s barrel rolled into an evade (stress) to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = false, evade = true },
        postconditions = { hasShot = true, inTargetsArc = true }
    },
    [7] = { -- Barrel roll to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = 'barrelRoll',
        postconditions = { hasShot = true }
    },
    [8] = { -- Barrel roll to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = 'barrelRoll',
        postconditions = { inTargetsArc = false }
    },
    [9] = { -- Evade
        description = "%s evaded.",
        preconditions = { inTargetsArc = true, hasShot = false },
        action = 'evade'
    },
    [10] = { -- Calculate
        description = "%s calculated.",
        action = 'calculate'
    }
}

-- HMP Droid Gunship
BehaviourDB.rule_sets[1].ships['hmpdroidgunship'] = {}
BehaviourDB.rule_sets[1].ships['hmpdroidgunship'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['hmpdroidgunship'].move_table = {
    bullseye = {
        near = { [1] = 's0', [2] = 's1', [3] = 'bl2z', [4] = 'br2z', [5] = 'tl2z', [6] = 'tr2z' },
        far = { [1] = 's1', [2] = 's2', [5] = 's3' },
        distant = { [1] = 's3', [2] = 's4', [4] = 's5' },
        stress = { [1] = 's1', [3] = 's2', [5] = 'tl2z', [6] = 'tr2z' },
    },
    front_right = {
        near = { [1] = 's0', [2] = 's1', [3] = 'bl2z', [5] = 'tr2z', [6] = 'tr3z' },
        far = { [1] = 'bl2z', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
        distant = { [1] = 'br2', [2] = 'br3', [4] = 's3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 's1', [3] = 's2', [5] = 'tl2z', [6] = 'tr2z' },
    },
    right_front = {
        near = { [1] = 's1', [2] = 'br1', [3] = 'br2z', [4] = 'tr2z', [6] = 'tr2' },
        far = { [1] = 'tr2', [3] = 'br2', [5] = 'tr3' },
        distant = { [1] = 'br2', [2] = 'tr2', [3] = 'br3', [4] = 'tr3' },
        stress = { [1] = 's1', [2] = 'tr2', [5] = 'tr2z' },
    },
    right_back = {
        near = { [1] = 'br2z', [2] = 'tr2', [4] = 'tr2z', [6] = 'tr3z' },
        far = { [1] = 'tr2', [4] = 'tr2z', [6] = 'tr3' },
        distant = { [1] = 'tr2', [3] = 'tr2z', [4] = 'tr3' },
        stress = { [1] = 'tr2', [5] = 'tr2z' },
    },
    back_right = {
        near = { [1] = 'tr2z', [4] = 'tl3z', [5] = 'tr3z' },
        far = { [1] = 'tr2', [2] = 'tr2z', [5] = 'tr3z' },
        distant = { [1] = 'tr2', [3] = 'tr2z', [5] = 'tr3z' },
        stress = { [1] = 'tr2', [3] = 'tl2z', [4] = 'tr2z' },
    },
}
BehaviourDB.rule_sets[1].ships['hmpdroidgunship'].special_move_difficulties = {
    bl1z = 'r',
    br1z = 'r',
    bl2z = 'w',
    br2z = 'w',
    bl3z = 'r',
    br3z = 'r',
    tl2z = 'b',
    tr2z = 'b',
    tl3z = 'w',
    tr3z = 'w',
}

BehaviourDB.rule_sets[1].ships['hmpdroidgunship'].action_selection = {
    [1] = { -- Target lock if charges left
        description = { text = "%s target locked %s. If %s has no charges on its missile or torpedo upgrades, then undo this action and perform it manually.", strings = { 'ship', 'target', 'ship' } },
        preconditions = { targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { --  Reload > Calculate (stress) if no charges left and defending
        pass_through = true,
        description = "If %s has no charges on its missile or torpedo upgrades, take a Reload action.",
        preconditions = { hasShot = false, inTargetsArc = true },
        action = { calculate = true }
    },
    [3] = { -- Calculate if you have a shot
        description = "%s has a shot so calculated.",
        preconditions = { hasShot = true },
        action = 'calculate'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { --  Reload ordnance (stress) if no charges left
        pass_through = true,
        description = "If %s has no charges on its missile or torpedo upgrades, take a Reload action.",
        preconditions = { hasShot = false }
    },
    [6] = { -- Calculate
        description = "%s calculated.",
        action = 'calculate'
    }
}

-- Sith Infiltrator
BehaviourDB.rule_sets[1].ships['sithinfiltrator'] = {}
BehaviourDB.rule_sets[1].ships['sithinfiltrator'].target_selection = {
    [1] = 'LockedInRange',
    [2] = 'ClosestInArcLowerInitiative',
    [3] = 'ClosestInArc',
    [4] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['sithinfiltrator'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'br2s', [4] = 'bl2s', [5] = 's1', [6] = 's4' },
        far = { [1] = 's1', [4] = 's2' },
        distant = { [1] = 's3', [2] = 's4' },
        stress = { [1] = 's1', [3] = 's2', [5] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [3] = 'bl2s', [5] = 'br1', [6] = 's1' },
        far = { [1] = 'br1', [3] = 's1', [4] = 'br2', [6] = 's2' },
        distant = { [1] = 'br3', [5] = 's4' },
        stress = { [1] = 'br1', [2] = 's1', [3] = 'br2', [5] = 's2', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl2s', [5] = 'br1', [6] = 'tr1' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr2' },
    },
    right_back = {
        near = { [1] = 'k5', [3] = 'bl2s', [6] = 'br3' },
        far = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl2s', [2] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'tr2' },
    },
    back_right = {
        near = { [1] = 'k5', [3] = 'br2s', [4] = 'bl2s', [6] = 'tr3' },
        far = { [1] = 'k5', [2] = 'bl2s', [4] = 'tr2', [5] = 'tr3' },
        distant = { [1] = 'bl2s', [2] = 'tr1', [3] = 'tr2', [6] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'bl2', [4] = 'br2', [6] = 'tr2' },
    },
}
BehaviourDB.rule_sets[1].ships['sithinfiltrator'].action_selection = {
    [1] = { -- (target not moved) Target lock if not in any arcs
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = false, targetLocked = false, inEnemyArc = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [2] = { -- (target moved) Target lock
        description = { text = "%s target locked %s.", strings = { 'ship', 'target' } },
        preconditions = { targetMoved = true, targetLocked = false, targetWithinRange = true },
        action = 'targetLock'
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Barrel roll (stress) to get a shot
        description = "%s barrel rolled to get a shot.",
        preconditions = { hasShot = false },
        action = { barrelRoll = true },
        postconditions = { hasShot = true }
    },
    [5] = { -- Barrel roll (stress) to avoid target's arc
        description = { text = "%s barrel rolled to avoid %s's arc.", strings = { 'ship', 'target' } },
        preconditions = { inTargetsArc = true },
        action = { barrelRoll = true },
        postconditions = { inTargetsArc = false }
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    }
}

-- Nantex-class Starfighter
BehaviourDB.rule_sets[1].ships['nantexclassstarfighter'] = {}
BehaviourDB.rule_sets[1].ships['nantexclassstarfighter'].target_selection = {
    [1] = 'ClosestInArcLowerInitiative',
    [2] = 'ClosestInArc',
    [3] = 'Closest'
}
BehaviourDB.rule_sets[1].ships['nantexclassstarfighter'].move_table = {
    bullseye = {
        near = { [1] = 'k5', [3] = 'bl3s', [4] = 'br3s', [5] = 'bl2', [6] = 'br2' },
        far = { [1] = 's2', [5] = 's3' },
        distant = { [1] = 's4', [2] = 's5' },
        stress = { [1] = 's2', [4] = 's3' },
    },
    front_right = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'br1', [4] = 'tr1', [6] = 's2' },
        far = { [1] = 'br2', [3] = 's2', [4] = 'br3', [6] = 's3' },
        distant = { [1] = 'br3', [5] = 's4', [6] = 's5' },
        stress = { [1] = 'br1', [2] = 'br2', [4] = 's2', [5] = 'br3', [6] = 's3' },
    },
    right_front = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'br1', [4] = 'tr1', [5] = 'br2', [6] = 'tr2' },
        far = { [1] = 'br1', [2] = 'tr1', [3] = 'br2', [4] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'tr2', [2] = 'br3', [4] = 'tr3' },
        stress = { [1] = 'br1', [3] = 'br2', [5] = 'br3' },
    },
    right_back = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'br1', [4] = 'tr1', [6] = 'tr2' },
        far = { [1] = 'bl3s', [2] = 'br1', [3] = 'tr1', [6] = 'tr2' },
        distant = { [1] = 'bl3s', [2] = 'tr2', [4] = 'tr3' },
        stress = { [1] = 'br1', [4] = 'br2', [6] = 'br3' },
    },
    back_right = {
        near = { [1] = 'k5', [2] = 'bl3s', [3] = 'br3s', [4] = 'tr1', [5] = 'tr2', [6] = 'tr3' },
        far = { [1] = 'k5', [2] = 'bl3s', [3] = 'tr1', [5] = 'tr2', [6] = 'tr3' },
        distant = { [1] = 'k5', [2] = 'bl3s', [3] = 'tr1', [6] = 'tr2' },
        stress = { [1] = 'br1', [3] = 'tr1', [4] = 'br2', [6] = 'br3' },
    },
}
BehaviourDB.rule_sets[1].ships['nantexclassstarfighter'].action_selection = {
    --[1] = { --  manual Tractor/Rotate prompt
    --    pass_through = true,
    --    description = "If %s can get a shot with Pinpoint Tractor Array, then take a Tractor token and Rotate action.",
    --},
    [1] = { -- Tractor(br)/Rotate
        description =
        "%s can avoid target arc and get a shot with Pinpoint Tractor Array by focusing and tractoring and rotating.",
        preconditions = { hasShot = false, inTargetsArc = true },
        action = {
            [1] = { focus = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [2] = { focus = false, barrelRoll = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [3] = { focus = false, boost = false, tractorSelf = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true, inTargetsArc = false }
    },
    [2] = { -- Tractor(br)/Rotate
        description = "%s can get a shot with Pinpoint Tractor Array by focusing and tractoring and rotating.",
        preconditions = { hasShot = false },
        action = {
            [1] = { focus = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [2] = { focus = false, barrelRoll = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [3] = { focus = false, boost = false, tractorSelf = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { hasShot = true }
    },
    [3] = { -- Focus if you have a shot
        description = "%s has a shot so focused.",
        preconditions = { hasShot = true },
        action = 'focus'
    },
    [4] = { -- Tractor(br)/Rotate
        description = "%s can avoid enemy arc with Pinpoint Tractor Array by evading and tractoring and rotating.",
        preconditions = { inEnemyArc = true },
        action = {
            [1] = { evade = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [2] = { evade = false, barrelRoll = false, tractorSelf = false, rotateTurret = { mount = 'main' } },
            [3] = { evade = false, boost = false, tractorSelf = false, rotateTurret = { mount = 'main' } }
        },
        postconditions = { inEnemyArc = false }
    },
    [5] = { -- Evade
        description = "%s evaded.",
        preconditions = { inEnemyArc = true },
        action = 'evade'
    },
    [6] = { -- Focus
        description = "%s focused.",
        action = 'focus'
    },
}

return BehaviourDB

end)
__bundle_register("TTS_Lib.SaveManager.SaveManager", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Require EventSub so we can hook into onLoad
local ES = require("TTS_Lib.EventSub.EventSub")

local SaveManager = {
    moduleList = {}
}

SaveManager.Register = function(key, saveFcn, restoreFcn)
    assert(type(key) == 'string', 'SaveManager.Register: No table key provided!')
    assert(type(saveFcn) == 'function', 'SaveManager.Register: No save function provided!')
    assert(type(restoreFcn) == 'function', 'SaveManager.Register: No restore function provided!')

    if SaveManager.moduleList[key] then
        error('SaveManager.Register: Key \'' .. key .. '\' already reserved!')
    end
    SaveManager.moduleList[key] = { save = saveFcn, restore = restoreFcn }
end

SaveManager.onLoad = function(saveData)
    local saveTable = SaveManager.Decode(saveData)
    if type(saveTable) ~= 'table' then
        print('Save data is invalid or empty')
        return
    end
    local responses = {}
    for key, module in pairs(SaveManager.moduleList) do
        if saveTable[key] and (not table.empty(saveTable[key])) then
            local response = module.restore(saveTable[key])
            if response and type(response) == 'string' then
                table.insert(responses, response)
            end
        end
    end
    if #responses > 0 then
        table.insert(responses, 1, 'Attempting to restore state...')
    end
    SaveManager.Notify(responses)
end
ES.Register('onLoad', SaveManager.onLoad)

SaveManager.onSave = function()
    local saveData = {}
    for key, module in pairs(SaveManager.moduleList) do
        local moduleSave = module.save()
        if moduleSave and type(moduleSave) == 'table' and (not table.empty(moduleSave)) then
            saveData[key] = moduleSave
        end
    end
    return SaveManager.Encode(saveData)  -- Encode the table of JSON strings
end

SaveManager.Encode = function(dataTable)
    return JSON.encode(dataTable)
end

SaveManager.Decode = function(encodedData)
    return JSON.decode(encodedData)
end

SaveManager.Notify = function(responses)
    if #responses > 0 then
        printToAll(table.concat(responses, '\n'), { 0.8, 0.1, 0.8 })
    end
end

return SaveManager

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
__bundle_register("vscode/console", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Console/console++")

-- function prototype
function onExternalCommand(command) end

-- Overwrite onChat function if you rather be handled by onExternalMessage
-- function onChat(message, player) end

function onExternalMessage(data)
  if data.input ~= nil then onExternalCommand(data.input) end
  if data.command ~= nil then
    local hostPlayer
    local players = getSeatedPlayers()
    for key, value in pairs(players) do
      if Player[value].host then
        hostPlayer = Player[value]
      end
    end
    if data.command ~= '' then
      local command = ''
      local command_function = nil
      local parameters = {hostPlayer}
      local requires_admin = false
      local command_mode = console.in_command_mode[hostPlayer.steam_id]
      if command_mode and console.active then
          command, command_function, parameters, requires_admin = console.get_command(data.command, hostPlayer)
      elseif data.command:sub(1, 1) == console.command_char and console.active then
          if data.command:len() > 1 then
              command, command_function, parameters, requires_admin = console.get_command(data.command:sub(2), hostPlayer)
          else
              command, command_function, parameters, requires_admin = console.get_command(console.command_char, hostPlayer)
          end
      else
          for i, f in ipairs(console.validation_functions) do
              local valid, response = f(data.command)
              if response == nil then response = '' end
              if not valid then
                  printToColor(response, hostPlayer.color, console.invalid_color)
                  return false
              end
          end
          return true
      end
      if console.active then
          if command_function and (hostPlayer.admin or not requires_admin) then
              if command_mode then
                  data.command = console.command_char .. console.command_char .. data.command
              end
              local response, mute = command_function(unpack(parameters))
              if response ~= nil or mute ~= nil then
                  if not mute then
                      printToColor('\n'..data.command, hostPlayer.color, console.command_color)
                  end
                  if response then
                      printToColor(response, hostPlayer.color, console.output_color)
                  end
              end
              if console.in_command_mode[hostPlayer.steam_id] then console.display_prompt(hostPlayer) end
              return false
          else
              printToColor('\n'..data.command, hostPlayer.color, console.command_color)
              printToColor(console.error_bb .. "<command '" .. command .. "' not found>[-]", hostPlayer.color, console.output_color)
              return false
          end
      end
    end
  end
end

end)
__bundle_register("Console/console++", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Console/console")

if not console.plusplus then
    console.plusplus = true

    -- Change these values as you wish
    console.seperator         = '/'
    console.wildcard          = '*'
    console.literal           = '`'  -- string parameters will be treated as paths where apt unless prefixed with this
    console.result            = '~'  -- refers to the most recently returned result from a call
    console.command_seperator = ';'  -- used in batch files to seperate commands
    console.indent            = '  '
    console.crop_string_at = 20
    console.builtin_path = 'sys'
    console.table_bb    = '[EEDD88]'
    console.hidden_bb   = '[DDAAAA]'
    console.function_bb = '[AADDAA]'
    console.value_bb    = '[88EE88]'
    console.boolean_bb  = '[CCCCFF]'
    console.object_bb   = '[CCBBCC]'
    console.guid_bb     = '[BBBBBB]'

    console.autoexec         = ''
    console.autoexec_options = '-s'

    -- Exposed methods:

    function console.hide_globals(label)
        -- all globals present when you call this will be hidden under <label> (unless built-in or already hidden)
        local hidden = {}
        for global, _ in pairs(_G) do
            local found = false
            for _, globals in pairs(console.hidden_globals) do
                if globals[global] then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(hidden, global)
            end
        end
        if console.hidden_globals[label] == nil then
            console.hidden_globals[label] = {}
        end
        for _, global in ipairs(hidden) do
            console.hidden_globals[label][global] = true
        end
    end

    function console.load()
        -- call this function in an onLoad event to enable the autoexec
        console.cd = console.seperator
        for _, player in pairs(getSeatedPlayers()) do
            if Player[player].admin then
                console.commands['exec'].command_function(Player[player], console.seperator..'console'..console.seperator..'autoexec', console.autoexec_options)
                break
            end
        end
    end

    function console.update()
        -- call this function in an onUpdate event to enable the watch list
        if console.watch_list and not console.watch_list_paused then
            for variable, watch in pairs(console.watch_list) do
                if watch.throttle == 0 or watch.last_check + watch.throttle < os.clock() then
                    watch.last_check = os.clock()
                    local node, id, parent, found
                    if watch.is_guid then
                        node = getObjectFromGUID(variable)
                        found = tostring(node) ~= 'null'
                    else
                        node, id, parent, found = console.node_from_path(variable)
                    end
                    if node ~= nil and found then
                        if type(node) == 'userdata' then
                            if tostring(node) ~= 'null' then
                                local p = function (x) return math.floor(x * 100) * 0.01 end
                                local r = function (x) return math.floor(x + 0.5) end
                                local position = node.getPosition()
                                local rotation = node.getRotation()
                                if p(position.x) ~= p(watch.position.x) or r(rotation.x) ~= r(watch.rotation.x) or
                                   p(position.y) ~= p(watch.position.y) or r(rotation.y) ~= r(watch.rotation.y) or
                                   p(position.z) ~= p(watch.position.z) or r(rotation.z) ~= r(watch.rotation.z) then
                                   watch.position = position
                                   watch.rotation = rotation
                                   node = ' ∡ '..r(rotation.x)..' '..r(rotation.y)..' '..r(rotation.z) ..
                                        console.boolean_bb..'   ⊞  '..p(position.x)..'   '..p(position.y)..'   '..p(position.z)
                                   if watch.is_guid then
                                       variable = console.format_guid(variable)
                                   else
                                       variable = console.object_bb .. variable .. '[-]'
                                   end
                                   printToColor(variable .. console.value_bb .. node .. '[-]', watch.player, console.output_color)
                                end
                            end
                        elseif type(node) == 'function' then
                            local result = node(unpack(watch.parameters))
                            if watch.property and (type(result) == 'table' or type(result) == 'userdata') then
                                result = result[watch.property]
                                if type(result) == 'function' then
                                    result = result()
                                end
                            end
                            if result ~= watch.value then
                                watch.value = result
                                result = tostring(result)
                                if result:len() > console.crop_string_at then result = result:sub(1, console.crop_string_at) .. '...' end
                                if result:len() == 6 and watch.label:lower():find('guid') then result = console.format_guid(result) end
                                printToColor(watch.label .. console.value_bb .. result .. '[-]', watch.player, console.output_color)
                            end
                        else
                            if node ~= watch.value then
                                watch.value = node
                                if type(node) == 'boolean' then
                                    if node then
                                        node = 'true'
                                    else
                                        node = 'false'
                                    end
                                elseif type(node) == 'string' then
                                    if node:len() > console.crop_string_at then node = node:sub(1, console.crop_string_at):gsub('\n', ' ') .. '...' end
                                end
                                printToColor(variable .. ': ' .. console.value_bb .. node .. '[-]', watch.player, console.output_color)
                            end
                        end
                    end
                end
            end
        end
    end

    -- simple swear-blocking validation
    console.add_validation_function(
        function (message)
            local message = message:lower()
            for i, bad_word in pairs({'fuck', 'cunt'}) do
                if message:find(bad_word) then
                    return false, "No swearing!"
                end
            end
            return true
        end
    )

    -- End of exposed methods.  You shouldn't need to interact with anything below (under normal circumstances)


    -- override default prompt with one which displays current table
    function console.display_prompt(player)
        printToColor(console.cd .. ' ' .. console.command_char..console.command_char, player.color, console.prompt_color)
    end


    -- console++ follows

    console.cd = console.seperator
    console.hidden_globals = {}
    console.hide_globals(console.builtin_path)

    function console.is_hidden(label)
        for _, globals in pairs(console.hidden_globals) do
            if globals[label] then
                return true
            end
        end
        return false
    end

    function console.escape_bb(s)
        local s = tostring(s)
        if s == '' then
            return ''
        else
            local r = ''
            for c = 1, s:len() do
                local char = s:sub(c, c)
                if char == '[' then
                    r = r .. '[\u{200B}'
                elseif char == ']' then
                    r = r .. '\u{200B}]'
                else
                    r = r .. char
                end
            end
            return r
        end
    end

    function console.format_guid(guid)
        return console.guid_bb .. '⁅' .. guid .. '⁆[-]'
    end

    function console.fill_path(path)
        local path = path
        local filter = nil
        if path == nil then
            return console.cd, filter
        end
        local c = path:len()
        if path:sub(c) ~= console.seperator then
            local found = false
            while c > 0 do
                local char = path:sub(c, c)
                if char == console.wildcard then
                    found = true
                elseif char == console.seperator then
                    break
                end
                c = c - 1
            end
            if found then
                filter = '^'
                for i = c + 1, path:len() do
                    local char = path:sub(i, i)
                    if char == console.wildcard then
                        filter = filter .. '.*'
                    else
                        filter = filter .. char
                    end
                end
                filter = filter .. '$'
                path = path:sub(1, c)
            end
        end
        if path:sub(1,1) == console.seperator then
            return path, filter
        else
            return console.cd .. path, filter
        end
    end

    function console.node_from_path(path)
        local node = _G
        local id = {''}
        local parent = {nil}
        local found = true
        local depth = 0
        local stack = {}
        local hidden = nil
        local ends_with_table = {true}
        if path == 'true' then
            node = true
        elseif path == 'false' then
            node = false
        elseif path ~= console.seperator then
            for i, part in ipairs(console.split(path, console.seperator)) do
                if part == '..' then
                    if depth > 0 then
                        node = table.remove(parent)
                        table.remove(id)
                        table.remove(stack)
                        table.remove(ends_with_table)
                        depth = depth - 1
                    end
                elseif part == '.' then
                    ; -- do nothing, . = where we are
                elseif part == console.result then
                    table.insert(parent, node)
                    table.insert(id, part)
                    table.insert(stack, part)
                    node = console.returned_value
                    table.insert(ends_with_table, type(node) == 'table')
                    depth = depth + 1
                elseif node[part] ~= nil then
                    table.insert(parent, node)
                    table.insert(id, part)
                    table.insert(stack, part)
                    node = node[part]
                    table.insert(ends_with_table, type(node) == 'table')
                    depth = depth + 1
                elseif node == _G and console.hidden_globals[part] then
                    hidden = console.hidden_globals[part]
                else
                    table.insert(id, part)
                    found = false
                    break
                end
            end
        end
        path = ''
        for i, part in ipairs(stack) do
            path = path .. console.seperator .. part
        end
        if table.remove(ends_with_table) then
            path = path .. console.seperator
        end
        return node, table.remove(id), table.remove(parent), found, path, hidden
    end


    -- commands

    console.add_admin_command('cd', '[<table>]',
        'Display current table or change current table',
        function (player, path)
            if path == nil then
                return console.cd
            else
                path = tostring(path)
            end
            local location = console.fill_path(path)
            local node, id, parent, found, location = console.node_from_path(location)
            local text = nil
            if node ~= nil and found and type(node) == 'table' then
                console.cd = location
                if not console.in_command_mode[player.steam_id] then text = console.cd end
            else
                text = console.error_bb .. '<not found>[-]'
            end
            return text, false
        end
    )
    console.add_admin_command('cd..', '', 'Change current table to parent table.', 'cd', {'..'})

    console.add_admin_command('ls', '[' .. console.option .. '?afotv] [' .. console.option .. 'r[#]] [<table>]',
        'Display variables in current table or specified table',
        function (player, ...)
            local help_details = console.header_bb .. 'Options[-]\n' ..
                'Show:\n '..console.option..'f functions\n '..console.option..'o objects\n '..
                console.option..'v variables (defaults to on)\n '..console.option..'t tables (defaults to on)\n '..
                console.option..'a all\n\n' ..console.option..'r[#] recurse [# layers if specified]'
            local path = console.cd
            local display_functions = false
            local display_objects = false
            local display_variables = false
            local display_tables = false
            local display_all = false
            local recursions_left = 0
            for i, arg in ipairs({...}) do
                arg = tostring(arg)
                if arg:len() > 1 and arg:sub(1,1) == console.option then
                    local c = 2
                    while c <= arg:len() do
                        local option = arg:sub(c,c)
                        if option == 'f' then
                            display_functions = not display_functions
                        elseif option == 'o' then
                            display_objects = not display_objects
                        elseif option == 'v' then
                            display_variables = not display_variables
                        elseif option == 't' then
                            display_tables = not display_tables
                        elseif option == 'a' then
                            display_all = not display_all
                        elseif option == 'r' then
                            local n = ''
                            local j = c + 1
                            while j <= arg:len() do
                                local char = arg:sub(j, j)
                                if char:match('%d') then
                                    n = n .. char
                                else
                                    break
                                end
                                j = j + 1
                            end
                            c = j - 1
                            if n == '' then
                                recursions_left = 20
                            else
                                recursions_left = tonumber(n)
                            end
                        elseif option == '?' or option == 'h' then
                            return help_details
                        else
                            return console.error_bb .. "<option '" .. console.option .. option .. "' not recognized>[-]\n"
                        end
                        c = c + 1
                    end
                else
                    path = arg
                end
            end
            local default_variables = not (display_tables or display_objects or display_functions or display_variables)
            if display_functions or display_objects or display_variables then
                display_tables = not display_tables
            end
            if display_all then
                display_functions = true
                display_objects = true
                display_variables = true
                display_tables = true
            elseif default_variables then
                display_functions = false
                display_objects = false
                display_variables = true
                display_tables = true
            end
            local location, filter = console.fill_path(path)
            return console.ls(player, location, filter, display_functions, display_objects, display_variables, display_tables, recursions_left)
        end
    )
    console.add_admin_command('dir', nil, nil, 'ls')
    console.add_admin_command(console.result, '', "Calls 'ls "..console.option.."a "..console.result.."'", 'ls', {console.option..'a', console.result})

    function console.ls(player, path, filter, display_functions, display_objects, display_variables, display_tables, recursions_left, indent)
        local text = ''
        local indent = indent or ''
        local node, id, parent, found, location, hidden = console.node_from_path(path)
        local paths = {}
        if node ~= nil and (found or hidden) then
            if type(node) == 'table' then
                local tables = {}
                local entries = {}
                for k, v in pairs(node) do
                    if (node ~= _G or (not hidden and not console.is_hidden(k)) or (hidden and hidden[k])) and (filter == nil or k:match(filter)) then
                        if type(v) == 'table' then
                            local t = console.table_bb .. k .. '[-]'
                            table.insert(tables, t)
                            paths[t] = path .. console.seperator .. k
                        else
                            if type(v) == 'function' then
                                if display_functions then
                                    table.insert(entries, console.function_bb .. k .. '[-]()')
                                end
                            elseif type(v) == 'userdata' then
                                if display_objects then
                                    local tag = tostring(v)
                                    if tag:find('(LuaGameObjectScript)') and not tag:gsub('(LuaGameObjectScript)',''):find('Script ') then
                                        tag = v.tag .. ' ' .. console.format_guid(v.getGUID())
                                    end
                                    if type(k) == 'number' and math.floor(k) == k then k = string.format('%04d', k) end
                                    table.insert(entries, console.object_bb .. k .. '[-]: '  .. tag)
                                end
                            elseif display_variables then
                                if type(v) == 'boolean' then
                                    if v then
                                        v = 'true'
                                    else
                                        v = 'false'
                                    end
                                    table.insert(entries, k .. ': ' .. console.boolean_bb .. v .. '[-]')
                                else
                                    local is_guid = false
                                    if type(v) == 'string' then
                                        if v:len()> console.crop_string_at then v = v:sub(1, console.crop_string_at):gsub('\n', ' ') .. '...' end
                                        if type(k) == 'string' and k:lower():find('guid') and v:len() == 6 then
                                            is_guid = true
                                        end
                                    end
                                    if is_guid then
                                        table.insert(entries, k .. ': ' .. console.format_guid(v) .. '[-]')
                                    else
                                        table.insert(entries, k .. ': ' .. console.value_bb .. console.escape_bb(v) .. '[-]')
                                    end
                                end
                            end
                        end
                    end
                end
                local cmp = function (a, b)
                    if not a then
                        return true
                    elseif not b then
                        return false
                    else
                        local la = a:len()
                        local lb = b:len()
                        local c = 1
                        repeat
                            if c > la and c <= lb then
                                return true
                            elseif c > lb and c <= la then
                                return false
                            elseif c > la then
                                return false
                            else
                                local ba = a:sub(c, c):byte()
                                local bb = b:sub(c, c):byte()
                                if ba < bb then
                                    return true
                                elseif bb < ba then
                                    return false
                                end
                            end
                            c = c + 1
                        until false
                    end
                end
                table.sort(tables, cmp)
                table.sort(entries, cmp)
                local cr = ''
                if display_tables then
                    for i, t in ipairs(tables) do
                        text = text .. cr .. indent .. t .. console.seperator
                        if recursions_left ~= 0 then
                            text = text .. '\n' .. console.ls(player, paths[t], filter,
                                display_functions, display_objects, display_variables, display_tables,
                                recursions_left-1, indent..console.indent)
                        end
                        cr = '\n'
                    end
                    if node == _G and not hidden then
                        for label, _ in pairs(console.hidden_globals) do
                            if (filter == nil or label:match(filter)) then -- and label ~= console.builtin_path
                                text = text .. cr .. indent .. console.hidden_bb .. label .. console.seperator .. '[-]'
                                cr = '\n'
                            end
                        end
                    end
                end
                for _, entry in ipairs(entries) do
                    text = text .. cr .. indent .. entry
                    cr = '\n'
                end
            elseif type(node) == 'userdata' then
                local tag = tostring(node)
                if tag ~= 'null' and tag:find('(LuaGameObjectScript)') and not tag:gsub('(LuaGameObjectScript)',''):find('Script ') then
                    tag = node.tag .. ' ' .. console.format_guid(node.getGUID())
                end
                text = indent .. console.object_bb .. id .. '[-]: ' .. tag
            elseif type(node) == 'function' then
                text = indent .. console.function_bb .. id .. '[-]()'
            elseif type(node) == 'boolean' then
                if node then
                    text = indent .. id .. ': ' .. console.boolean_bb .. 'true[-]'
                else
                    text = indent .. id .. ': ' .. console.boolean_bb .. 'false[-]'
                end
            else
                if type(id) == 'string' and id:lower():find('guid') and type(node) == 'string' and node:len() == 6 then
                    text = indent .. id .. ': ' .. console.format_guid(node) .. '[-]'
                else
                    text = indent .. id .. ': ' .. console.value_bb .. console.escape_bb(node) .. '[-]'
                end
            end
        else
            text = indent .. console.error_bb .. '<not found>[-]'
        end
        return text
    end

    console.add_admin_command('call', '<function> [<parameter>...]',
        'Call function with parameters and display result.',
        function (player, ...)
            local path = nil
            local parameters = {}
            for i, arg in ipairs({...}) do
                if i == 1 then
                    path = tostring(arg)
                else
                    if type(arg) == 'string' then
                        if arg:len() > 2 and arg:sub(1,1) == console.literal then
                            arg = arg:sub(2)
                        else
                            local node, id, parent, found = console.node_from_path(console.fill_path(arg))
                            if node ~= nil and found then
                                arg = node
                            end
                        end
                    end
                    table.insert(parameters, arg)
                end
            end
            if path == nil then
                return console.error_bb .. '<you must supply a function>[-]'
            end
            local location = console.fill_path(path)
            local node, id, parent, found, location = console.node_from_path(location)
            local text = nil
            if node ~= nil and found and type(node) == 'function' then
                console.returned_value = node(unpack(parameters))
                text = tostring(console.returned_value)
                if console.deferred_assignment then
                    local da = console.deferred_assignment
                    if da.command == 'set' then
                        if da.parent[da.id] ~= nil then
                            if da.force or type(console.returned_value) == type(da.parent[da.id]) then
                                da.parent[da.id] = console.returned_value
                                text = text .. '\n' .. console.header_bb .. "<set '" .. da.id .. "'>[-]"
                            else
                                text = text .. '\n' .. console.error_bb .. "<cannot set '" .. da.id .. "': it is of type '" .. type(da.parent[da.id]) .. "'>[-]"
                            end
                        else
                            text = text .. '\n' .. console.error_bb .. "<cannot set '" .. da.id .. "': it does not exist>[-]"
                        end
                    elseif da.command == 'add' then
                        if da.parent[da.id] == nil then
                            da.parent[da.id] = console.returned_value
                            text = text .. '\n' .. console.header_bb .. "<added '" .. da.id .. "'>[-]"
                        else
                            text = text .. '\n' .. "<cannot add '" .. da.id .. "': it already exists>[-]"
                        end
                    end
                    console.deferred_assignment = nil
                end
            else
                text = console.error_bb .. '<not found>[-]'
            end
            return text, false
        end
    )

    console.add_admin_command('set', '['..console.option..'f] <variable> [<value>]',
        "Set variable to value.  If no value specified then the next value returned from 'call' is used.\n" ..
            console.option ..'f  force overwrite ignoring type',
        function (player, ...)
            local variable = nil
            local value = nil
            local force = false
            for _, arg in ipairs({...}) do
                if type(arg) == 'string' and arg:len() > 1 and arg:sub(1, 1) == console.option then
                    local c = 2
                    while c <= arg:len() do
                        local option = arg:sub(c, c)
                        if option == "f" then
                            force = not force
                        else
                            return console.error_bb .. "<option '" .. option .. "' not recognized>[-]"
                        end
                        c = c + 1
                    end
                elseif variable == nil then
                    variable = tostring(arg)
                else
                    value = arg
                end
            end
            if variable == nil then
                return console.error_bb .. '<you must supply a variable>[-]'
            end
            variable = console.fill_path(variable)
            local node, id, parent, found = console.node_from_path(variable)
            local text = ''
            if node ~= nil and found then
                if value == nil then
                    console.deferred_assignment = {command = 'set', parent = parent, id = id, force = force}
                    text = id .. ': ' .. console.header_bb .. "<awaiting 'call'>[-]"
                else
                    console.deferred_assignment = nil
                    if type(value) == 'string' and value:len() > 0  then
                        if value:sub(1, 1) == console.literal then
                            value = value:sub(2)
                        else
                            local value_node, value_id, value_parent, value_found = console.node_from_path(value)
                            if value_node ~= nil and value_found then
                                value = value_node
                            else
                                return console.error_bb .. '<not found>[-]'
                            end
                        end
                    end
                    if type(node) == 'boolean' then
                        if not value or tostring(value):lower() == 'false' then
                            value = false
                        else
                            value = true
                        end
                    end
                    if type(node) == type(value) or force then
                        parent[id] = value
                        text = id .. ': ' .. console.value_bb .. tostring(parent[id]) .. '[-]'
                    else
                        return console.error_bb .. "<cannot set '" .. id .. "': it is of type '" .. type(node) .. "'>[-]"
                    end
                end
            else
                text = console.error_bb .. '<not found>[-]'
            end
            return text
        end
    )

    console.add_admin_command('toggle', '<boolean>',
        'Toggle specified boolean variable',
        function (player, variable)
            if variable == nil then
                return console.error_bb .. '<you must supply variable>'
            else
                variable = tostring(variable)
            end
            local variable = console.fill_path(variable)
            local node, id, parent, found = console.node_from_path(variable)
            local text = ''
            if node ~= nil and found then
                if type(node) == 'boolean' then
                    if node then
                        parent[id] = false
                        text = id .. ': ' .. console.value_bb .. 'false[-]'
                    else
                        parent[id] = true
                        text = id .. ': ' .. console.value_bb .. 'true[-]'
                    end
                else
                    text = console.error_bb .. '<can only toggle a boolean>[-]'
                end
            else
                text = console.error_bb .. '<not found>[-]'
            end
            return text
        end
    )
    console.add_admin_command('tgl', nil, nil, 'toggle')

    console.add_admin_command('rm', '<variable>',
        'Remove specified variable',
        function (player, variable)
            if variable == nil then
                return console.error_bb .. '<you must supply variable>'
            else
                variable = tostring(variable)
            end
            local variable = console.fill_path(variable)
            local node, id, parent, found = console.node_from_path(variable)
            local text = ''
            if node ~= nil and found then
                parent[id] = nil
                text = id .. " removed!"
            else
                text = console.error_bb .. '<not found>[-]'
            end
            return text
        end
    )
    console.add_admin_command('del', nil, nil, 'rm')

    console.add_admin_command('add', '<variable> [<value>]',
        "Create a variable set to value.   If no value specified then the next value returned from 'call' is used.",
        function (player, variable, value)
            if variable == nil then
                return console.error_bb .. '<you must supply variable>[-]'
            else
                variable = tostring(variable)
            end
            local variable = console.fill_path(variable)
            local node, id, parent, found = console.node_from_path(variable)
            local text = ''
            if found then
                return console.error_bb .. '<already exists>[-]'
            elseif node == nil or id == '' then
                return console.error_bb .. '<not found>[-]'
            else
                if value == nil then
                    console.deferred_assignment = {command = 'add', parent = node, id = id}
                    text = id .. ': ' .. console.header_bb .. "<awaiting 'call'>[-]"
                else
                    console.deferred_assignment = nil
                    if type(value) == 'string' and value:len() > 0  then
                        if value:sub(1, 1) == console.literal then
                            value = value:sub(2)
                        else
                            local value_node, value_id, value_parent, value_found = console.node_from_path(value)
                            if value_node ~= nil and value_found then
                                value = value_node
                            else
                                return console.error_bb .. '<not found>[-]'
                            end
                        end
                    end
                    node[id] = value
                    text = id .. ': ' .. console.value_bb .. tostring(value) .. '[-]'
                end
            end
            return text
        end
    )

    console.add_admin_command('exec', '['..console.option..'?qsv] <commands>',
        'Execute a series of commands held in a string: commands are seperated by a new line or '..console.command_seperator,
        function (player, ...)
            local help_details = console.option..'q    quiet: will not output anything except final output\n' ..
                                 console.option..'s    silent: will not output anything at all\n'..
                                 console.option..'v    verbose: will output commands as they execute\n'
            local commands = nil
            local verbose = false
            local quiet = false
            local silent = false
            for _, arg in ipairs({...}) do
                if type(arg) == 'string' and arg:len() > 1 and arg:sub(1,1) == console.option then
                    local c = 2
                    while c <= arg:len() do
                        local option = arg:sub(c,c)
                        if option == '?' then
                            return help_details
                        elseif option == 'q' then
                            quiet = not quiet
                        elseif option == 's' then
                            silent = not silent
                        elseif option == 'v' then
                            verbose = not verbose
                        else
                            return console.error_bb .. "<option '" .. option .. "' not recognized>"
                        end
                        c = c + 1
                    end
                elseif commands == nil then
                    commands = tostring(arg)
                end
            end
            if silent then quiet = true end
            if commands:len() > 1 and commands:sub(1, 1) == console.literal then
                commands = commands:sub(2)
            else
                local variable = console.fill_path(commands)
                local node, id, parent, found = console.node_from_path(variable)
                if node ~= nil and found then
                    commands = node
                else
                    return console.error_bb .. '<not found>[-]'
                end
            end
            if commands:find('\n') then
                commands = console.split(commands, '\n')
            else
                commands = console.split(commands, console.command_seperator)
            end
            local end_result = nil
            for _, command_text in ipairs(commands) do
                local command = ''
                local command_function = nil
                local parameters = {player}
                local requires_admin = false
                command, command_function, parameters, requires_admin = console.get_command(command_text, player)
                if command ~= '' then
                    if command_function and (player.admin or not requires_admin) then
                        local response, mute = command_function(unpack(parameters))
                        if response ~= nil or mute ~= nil then
                            if not mute and verbose and not quiet then
                                printToColor('\n'..command_text, player.color, console.command_color)
                            end
                            if response then
                                end_result = response
                                if not quiet then
                                    printToColor(response, player.color, console.output_color)
                                end
                            end
                        end
                    elseif not quiet then
                        if verbose then printToColor('\n'..command_text, player.color, console.command_color) end
                        printToColor(console.error_bb .. "<command '" .. command .. "' not found>[-]", player.color, console.output_color)
                    end
                end
            end
            if end_result and not silent then
                printToColor(end_result, player.color, console.output_color)
            end
        end
    )

    console.add_admin_command('watch', '['..console.option..'?cgp] ['..console.option..'t#] ['..console.option..console.seperator..'<property>] [<variable>]',
        'Watch a variable or object and display it whenever it changes.\n' .. console.hidden_bb ..
        'Requires you to add a '..console.function_bb..'console.update()[-] call to an ' ..
        console.function_bb .. 'onUpdate[-] event in your code.[-]\n',
        function (player, ...)
            local help_details = 'Call without a parameter to display watched items, or with a variable to add it to watch list.\n' ..
                                console.option..'c will clear variable if specified, or all.\n' ..
                                console.option..'g will let you specify an object by its GUID.\n' ..
                                console.option..'t# will throttle output to # seconds.\n' ..
                                console.option..console.seperator..'<property> will watch the property of the variable.\n' ..
                                console.option..'p will pause or unpause watching.\n'
            local path = nil
            local clearing = false
            local throttle = nil
            local pause_changed = false
            local by_guid = false
            local parameters = {}
            local labels = {}
            local property = nil
            for _, arg in ipairs({...}) do
                if type(arg) == 'string' and arg:len() > 1 and arg:sub(1,1) == console.option then
                    local c = 2
                    while c <= arg:len() do
                        local option = arg:sub(c,c)
                        if option == '?' then
                            return help_details
                        elseif option == 'c' then
                            clearing = not clearing
                        elseif option == 'p' then
                            pause_changed = not pause_changed
                        elseif option == 'g' then
                            by_guid = not by_guid
                        elseif option == console.seperator then
                            if arg:len() > c then
                                property = arg:sub(c + 1)
                                c = arg:len() + 1
                            end
                        elseif option == 't' then
                            local n = ''
                            local j = c + 1
                            while j <= arg:len() do
                                local char = arg:sub(j, j)
                                if char:match('[0-9.]') then
                                    n = n .. char
                                else
                                    break
                                end
                                j = j + 1
                            end
                            c = j - 1
                            if n == '' then
                                return console.error_bb .. '<you must provide a throttle duration (in seconds)>[-]'
                            else
                                throttle = tonumber(n)
                            end
                        else
                            return console.error_bb .. "<option '" .. option .. "' not recognized>"
                        end
                        c = c + 1
                    end
                else
                    if path == nil then
                        path = tostring(arg)
                    else
                        local label = tostring(arg)
                        if type(arg) == 'string' then
                            if arg:len() > 2 and arg:sub(1,1) == console.literal then
                                arg = arg:sub(2)
                                label = arg
                            else
                                local node, id, parent, found = console.node_from_path(console.fill_path(arg))
                                if node ~= nil and found then
                                    arg = node
                                end
                            end
                        end
                        table.insert(labels, label)
                        table.insert(parameters, arg)
                    end
                end
            end
            local text = ''
            if pause_changed then
                if console.watch_list_paused then
                    console.watch_list_paused = nil
                    text = text .. console.header_bb .. '<unpaused>[-]'
                else
                    console.watch_list_paused = true
                    text = text .. console.header_bb .. '<paused>[-]'
                end
            end
            if path == nil then
                if throttle ~= nil then
                    text = text .. '\n' .. console.error_bb .. '<you must provide a variable or object>[-]'
                elseif by_guid then
                    text = text .. '\n' .. console.error_bb .. '<you must provide a GUID>[-]'
                elseif clearing then
                    console.watch_list = nil
                    console.watch_list_paused = nil
                    text = text .. '\nWatch list cleared!'
                elseif not pause_changed then
                    if console.watch_list then
                        local watched = {}
                        for label, watch in pairs(console.watch_list) do
                            if watch.player == player.color then
                                table.insert(watched, label)
                            end
                        end
                        table.sort(watched)
                        text = text .. '\n'..console.header_bb..'Watching:[-]'
                        for _, label in ipairs(watched) do
                            local watch = console.watch_list[label]
                            local is_guid = (label:len() == 6 and label:sub(1,1) ~= console.seperator)
                            local node, id, parent, found
                            local prefix
                            text = text .. '\n'
                            if is_guid then
                                prefix =  console.format_guid(label)
                                node = getObjectFromGUID(label)
                                found = tostring(node) ~= 'null'
                            else
                                prefix = label
                                node, id, parent, found = console.node_from_path(label)
                            end
                            if node ~= nil and found then
                                if type(node) == 'userdata' then
                                    prefix = console.object_bb .. prefix .. '[-]'
                                    local position = node.getPosition()
                                    local rotation = node.getRotation()
                                    local p = function (x) return math.floor(x * 100) * 0.01 end
                                    local r = function (x) return math.floor(x + 0.5) end
                                    text = text .. prefix .. console.value_bb .. ' ∡ '..r(rotation.x)..' '..r(rotation.y)..' '..r(rotation.z) .. '[-]'..
                                            console.boolean_bb..'   ⊞  '..p(position.x)..'   '..p(position.y)..'   '..p(position.z)
                                elseif type(node) == 'function' then
                                    local result = node(unpack(console.watch_list[label].parameters))
                                    if watch.property and (type(result) == 'table' or type(result) == 'userdata') then
                                        result = result[watch.property]
                                        if type(result) == 'function' then
                                            result = result()
                                        end
                                    end
                                    result = tostring(result)
                                    if watch.propery and watch.property:lower():find('guid') then
                                        result = console.format_guid(result)
                                    end
                                    if result:len() > console.crop_string_at then result = result:sub(1, console.crop_string_at) .. '...' end
                                    text = text .. watch.label .. console.value_bb .. result .. '[-]'
                                else
                                    if type(node) == 'boolean' then
                                        if node then
                                            node = 'true'
                                        else
                                            node = 'false'
                                        end
                                    elseif type(node) == 'string' then
                                        if node:len() > console.crop_string_at then node = node:sub(1, console.crop_string_at):gsub('\n', ' ') .. '...' end
                                    end
                                    text = text .. prefix .. ': ' .. console.value_bb .. node .. '[-]'
                                end
                            end
                        end
                    else
                        text = text .. "\nWatch list is empty."
                    end
                end
            else
                if not by_guid then
                    path = console.fill_path(path)
                end
                if clearing then
                    local node, id, parent, found
                    if not by_guid then
                        node, id, parent, found, path = console.node_from_path(path)
                    end
                    if console.watch_list[path] then
                        console.watch_list[path] = nil
                        if next(console.watch_list) == nil then
                            console.watch_list = nil
                        end
                        text = text .. '\n' .. console.header_bb.. 'No longer watching:[-] ' .. path
                    else
                        text = text .. '\n' .. console.error_bb .. '<not found>[-]'
                    end
                else
                    local node, id, parent, found
                    if by_guid then
                        node = getObjectFromGUID(path)
                        found = tostring(node) ~= 'null'
                    else
                        node, id, parent, found, path = console.node_from_path(path)
                    end
                    if node ~= nil and found then
                        if console.watch_list == nil then console.watch_list = {} end
                        if throttle == nil then throttle = 0 end
                        console.watch_list[path] = {player=player.color, throttle=throttle, last_check=0, property=property}
                        if type(node) == 'userdata' then
                            console.watch_list[path].position = node.getPosition()
                            console.watch_list[path].rotation = node.getRotation()
                            console.watch_list[path].is_guid  = by_guid
                        elseif type(node) == 'function' then
                            console.watch_list[path].parameters = parameters
                            console.watch_list[path].value = node
                            console.watch_list[path].label = console.function_bb .. path .. '[-]'
                            if property then
                                console.watch_list[path].label = console.watch_list[path].label .. console.seperator .. property
                            end
                            for _, label in ipairs(labels) do
                                console.watch_list[path].label = console.watch_list[path].label .. ' ' .. console.hidden_bb .. label .. '[-]'
                            end
                            console.watch_list[path].label = console.watch_list[path].label .. ': '
                        else
                            console.watch_list[path].value = node
                        end
                        if by_guid then
                            path = console.format_guid(path)
                        end
                        text = text .. '\n' .. console.header_bb .. 'Watching:[-] ' .. path
                    else
                        text = text .. '\n' .. console.error_bb .. '<not found>[-]'
                    end
                end
            end
            if text:len() > 1 and text:sub(1, 1) == '\n' then
                text = text:sub(2)
            end
            return text
        end
    )

    console.add_player_command('shout', '<text>',
        'Broadcast <text> to all players. Colour a section with {RRGGBB}section{-}.',
        function (player, ...)
            local text = player.steam_name .. ': '
            local space = ''
            for _, word in ipairs({...}) do
                text = text .. space .. tostring(word)
                space = ' '
            end
            text = text:gsub('{','[')
            text = text:gsub('}',']')
            broadcastToAll(text, stringColorToRGB(player.color))
            return nil, false
        end
    )

    -- change the command help color so client added commands appear different to console++
    console.set_command_listing_bb('[A0F0C0]')
end

end)
__bundle_register("Console/console", function(require, _LOADED, __bundle_register, __bundle_modules)
if not console then
    console = {}

    -- Change these values as you wish
    console.command_char = '>'
    console.option       = '-'
    console.prompt_color  = {r = 0.8,  g = 1.0,  b = 0.8 }
    console.command_color = {r = 0.8,  g = 0.6,  b = 0.8 }
    console.output_color  = {r = 0.88, g = 0.88, b = 0.88}
    console.invalid_color = {r = 1.0,  g = 0.2,  b = 0.2 }
    console.header_bb       = '[EECCAA]'
    console.error_bb        = '[FF9999]'
    console.inbuilt_help_bb = '[E0E0E0]'
    console.client_help_bb  = '[C0C0FF]'

    -- Exposed methods:

    function console.add_validation_function(validation_function)
        -- Adds a validation function all chat will be checked against:
        -- function(string message) which returns (boolean valid, string response)
        -- If all validation functions return <valid> as true the message will be displayed.
        -- If one returns <valid> as false then its <response> will be displayed to that player instead.
        table.insert(console.validation_functions, validation_function)
    end

    function console.add_player_command(command, parameter_text, help_text, command_function, default_parameters)
        -- Adds a command anyone can use, see below for details
        console.add_command(command, false, parameter_text, help_text, command_function, default_parameters)
    end

    function console.add_admin_command(command, parameter_text, help_text, command_function, default_parameters)
        -- Adds a command only admins can use, see below for details
        console.add_command(command, true, parameter_text, help_text, command_function, default_parameters)
    end

    function console.add_command(command, requires_admin, parameter_text, help_text, command_function, default_parameters)
        -- Adds a command to the console.
        -- command_function must take <player> as its first argument, and then any
        --   subsequent arguments you wish which will be provided by the player.
        -- You may alias an already-present command by calling this with command_function set to
        --   the command string instead of a function.  default_parameters can be set for the alias.
        -- See basic built-in commands at the bottom of this file for examples.
        local commands = console.commands
        local command_function = command_function
        local help_text = help_text
        local parameter_text = parameter_text
        if type(command_function) == 'string' then --alias
            if help_text == nil then
                help_text = commands[command_function].help_text
            end
            if parameter_text == nil then
                parameter_text = commands[command_function].parameter_text
            end
            command_function = commands[command_function].command_function
        end
        console.commands[command] = {
            command_function   = command_function,
            requires_admin     = requires_admin,
            parameter_text     = parameter_text,
            help_text          = help_text,
            help_bb            = console.command_help_bb,
            default_parameters = default_parameters,
        }
    end

    function console.set_command_listing_bb(bb)
        -- Tags commands added after with a bb color for when they are displayed (i.e. with 'help')
        console.command_help_bb = bb
    end

    function console.disable()
        -- Disables console for command purposes, but leaves validation functions running
        console.active = false
    end

    function console.enable()
        -- Enables console commands (console commands are on by default)
        console.active = true
    end

    -- End of exposed methods.  You shouldn't need to interact with anything below (under normal circumstances)


    console.active = true
    console.in_command_mode = {}
    console.commands = {}
    console.validation_functions = {}
    console.set_command_listing_bb(console.inbuilt_help_bb)

    function onChat(message, player)
        if message ~= '' then
            local command = ''
            local command_function = nil
            local parameters = {player}
            local requires_admin = false
            local command_mode = console.in_command_mode[player.steam_id]
            if command_mode and console.active then
                command, command_function, parameters, requires_admin = console.get_command(message, player)
            elseif message:sub(1, 1) == console.command_char and console.active then
                if message:len() > 1 then
                    command, command_function, parameters, requires_admin = console.get_command(message:sub(2), player)
                else
                    command, command_function, parameters, requires_admin = console.get_command(console.command_char, player)
                end
            else
                for i, f in ipairs(console.validation_functions) do
                    local valid, response = f(message)
                    if response == nil then response = '' end
                    if not valid then
                        printToColor(response, player.color, console.invalid_color)
                        return false
                    end
                end
                return true
            end
            if console.active then
                if command_function and (player.admin or not requires_admin) then
                    if command_mode then
                        message = console.command_char .. console.command_char .. message
                    end
                    local response, mute = command_function(unpack(parameters))
                    if response ~= nil or mute ~= nil then
                        if not mute then
                            printToColor('\n'..message, player.color, console.command_color)
                        end
                        if response then
                            printToColor(response, player.color, console.output_color)
                        end
                    end
                    if console.in_command_mode[player.steam_id] then console.display_prompt(player) end
                    return false
                else
                    printToColor('\n'..message, player.color, console.command_color)
                    printToColor(console.error_bb .. "<command '" .. command .. "' not found>[-]", player.color, console.output_color)
                    return false
                end
            end
        end
    end

    function console.get_command(message, player)
        local command_name = ''
        local command_function = nil
        local requires_admin = false
        local parameters = {player}
        for i, part in ipairs(console.split(message)) do
            if i == 1 then
                command_name = part
                local command = console.commands[command_name]
                if command then
                    command_function = command.command_function
                    requires_admin = command.requires_admin
                    if command.default_parameters then
                        for _, parameter in ipairs(command.default_parameters) do
                            table.insert(parameters, parameter)
                        end
                    end
                end
            else
                table.insert(parameters, part)
            end
        end
        return command_name, command_function, parameters, requires_admin
    end

    function console.display_prompt(player)
        printToColor(console.command_char..console.command_char, player.color, console.prompt_color)
    end

    function console.split(text, split_on)
        local split_on = split_on or ' '
        if type(split_on) == 'string' then
            local s = {}
            for c = 1, split_on:len() do
                s[split_on:sub(c,c)] = true
            end
            split_on = s
        end
        local parts = {}
        if text ~= '' then
            local make_table = function(s)
                local entries = console.split(s, ' ,')
                local t = {}
                for _, entry in ipairs(entries) do
                    if type(entry) == 'string' and entry:find('=') then
                        e = console.split(entry, '=')
                        t[e[1]] = e[2]
                    else
                        table.insert(t, entry)
                    end
                end
                return t
            end
            local current_split_on = split_on
            local adding = false
            local part = ""
            local totype = tonumber
            for c = 1, text:len() do
                local char = text:sub(c, c)
                if adding then
                    if current_split_on[char] then -- ended current part
                        if totype(part) ~= nil then
                            table.insert(parts, totype(part))
                        else
                            table.insert(parts, part)
                        end
                        adding = false
                        current_split_on = split_on
                        totype = tonumber
                    else
                        part = part .. char
                    end
                else
                    if not current_split_on[char] then -- found start of part
                        if char == "'" then
                            current_split_on = {["'"] = true}
                            totype = tostring
                            part = ''
                        elseif char == '"' then
                            current_split_on = {['"'] = true}
                            totype = tostring
                            part = ''
                        elseif char == '{' then
                            current_split_on = {['}'] = true}
                            totype = make_table
                            part = ''
                        else
                            part = char
                        end
                        adding = true
                    end
                end
            end
            if adding then
                if totype(part) ~= nil then
                    table.insert(parts, totype(part))
                else
                    table.insert(parts, part)
                end
            end
        end
        return parts
    end


    -- Add basic built-in console commands

    console.add_player_command('help', '[' .. console.option .. 'all|<command>]',
        'Display available commands or help on all commands or help on a specific command.',
        function (player, command)
            if command ~= nil then
                command = tostring(command)
            end
            local make_help = function (command)
                return console.header_bb .. command .. ' ' .. console.commands[command].parameter_text ..
                        '[-]\n' .. console.commands[command].help_text
            end
            local info_mode = false
            if command == console.option..'all' then
                info_mode = true
            end
            if command and console.commands[command] then
                return make_help(command)
            elseif command and not info_mode then
                return console.error_bb .. "<command '" .. command .. "' not found>[-]"
            else
                local msg = console.header_bb .. 'Available commands:[-]'
                local command_list = {}
                for c, _ in pairs(console.commands) do
                    if player.admin or not console.commands[c].requires_admin then
                        if info_mode then
                            table.insert(command_list, make_help(c))
                        else
                            table.insert(command_list, c)
                        end
                    end
                end
                table.sort(command_list)
                local sep
                if info_mode then
                    sep = '\n\n'
                else
                    sep = '\n'
                end
                for _, c in ipairs(command_list) do
                    local cmd = console.commands[c]
                    if cmd then
                        msg = msg .. sep .. cmd.help_bb .. c .. '[-]'
                    else
                        msg = msg .. sep .. c
                    end
                    if not info_mode then sep = ', ' end
                end
                return msg
            end
        end
    )
    console.add_player_command('?', nil, nil, 'help')
    console.add_player_command('info', '', 'Display help on all available commands.', 'help', {console.option..'all'})

    console.add_player_command('exit', '',
        "Leave <command mode> ('" .. console.command_char .. "' does the same).",
        function (player)
            console.in_command_mode[player.steam_id] = nil
            return console.header_bb .. '<command mode: off>[-]'
        end
    )

    console.add_player_command('cmd', '',
        "Enter <command mode> ('" .. console.command_char .. "' does the same).",
        function (player)
            console.in_command_mode[player.steam_id] = true
            return console.header_bb .. '<command mode: on>[-]'
        end
    )

    console.add_player_command(console.command_char, '',
        'Toggle <command mode>',
        function (player)
            console.in_command_mode[player.steam_id] = not console.in_command_mode[player.steam_id]
            if console.in_command_mode[player.steam_id] then
                return console.header_bb .. '<command mode: on>[-]', true
            else
                return console.header_bb .. '<command mode: off>[-]', true
            end
        end
    )

    console.add_player_command('=', '<expression>',
        'Evaluate an expression',
        function (player, ...)
            local expression = ''
            for _, arg in ipairs({...}) do
                expression = expression .. ' ' .. tostring(arg)
            end
            if not player.admin then
                expression = expression:gasub('[a-zA-Z~]', '')
            end
            console.returned_value = dynamic.eval(expression)
            return console.returned_value
        end
    )

    console.add_player_command('echo', '<text>',
        'Display text on screen',
        function (player, ...)
            local text = ''
            for _, arg in ipairs({...}) do
                text = text .. ' ' .. tostring(arg)
            end
            printToColor(text, player.color, console.output_color)
            return false
        end
    )

    console.add_player_command('cls', '',
        'Clear console text',
        function (player)
            return '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n' ..
                   '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'
        end
    )

    console.add_player_command('alias', '<alias> <command> [<parameter>...]',
        'Create a command alias.',
        function (player, ...)
            local alias
            local command
            local parameters = {}
            for i, arg in ipairs({...}) do
                if i == 1 then
                    alias = tostring(arg)
                elseif i == 2 then
                    command = tostring(arg)
                else
                    table.insert(parameters, arg)
                end
            end
            if not alias then
                return console.error_bb .. '<must provide an alias>[-]'
            --elseif console.commands[alias] ~= nil then
            --    return console.error_bb .. "<command '" .. alias .. "' already exists!>[-]"
            elseif command == nil then
                return console.error_bb .. "<must provide a command>[-]"
            elseif console.commands[command] == nil then
                return console.error_bb .. "<command '" .. command .. "' does not exist>[-]"
            else
                local text = console.header_bb .. alias .. '[-] = ' .. command
                local help_text = console.commands[command].help_text
                if not help_text:find('\nAliased to: ') then
                    help_text = help_text .. '\nAliased to: ' .. command
                end
                local combined_parameters = {}
                if console.commands[command].default_parameters then
                    for _, parameter in ipairs(console.commands[command].default_parameters) do
                        table.insert(combined_parameters, parameter)
                    end
                end
                for _, parameter in ipairs(parameters) do
                    table.insert(combined_parameters, parameter)
                    text = text .. ' ' .. parameter
                    help_text = help_text .. ' ' .. parameter
                end
                console.add_command(alias, console.commands[command].requires_admin, console.commands[command].parameter_text, help_text, command, combined_parameters)
                return text
            end
        end
    )

    -- change the command help color so client added commands appear different to in-built
    console.set_command_listing_bb(console.client_help_bb)
end

end)
return __bundle_require("Global.-1.lua")