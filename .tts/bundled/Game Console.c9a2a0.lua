-- Bundled by luabundle {"rootModuleName":"Game Console.c9a2a0.lua","version":"1.6.0"}
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
__bundle_register("Game Console.c9a2a0.lua", function(require, _LOADED, __bundle_register, __bundle_modules)
require("Game.GameConsole")

end)
__bundle_register("Game.GameConsole", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Scrip created by Eirik 'Flippster' Munthe for the Unified X-Wing 2.0 TTS Module
-- Standard libraries extensions
require("TTS_Lib.Util.Math")
require("TTS_Lib.Util.Table")
require("TTS_Lib.Util.String")

__XW_LayoutHandlers = { hide = 'deleteIndicators', show = 'show' }


max_rounds = 13
max_offset = 9
state = "init"
history = {}
players = {}
sided_players = {}
required_dice_roll_players = {}
default_color = color(0.8, 0.8, 0.8)
stones = {}
runningCounts = {}
indicators = {}
dice_roll_scores = {}
round = 0
even_distribution = false
after_dials_mode = true
dice_roll_mode = true
wait_timer = nil
dice_roll_timer = 0

function onLoad(save_state)
    math.randomseed(os.time())
    if save_state and save_state ~= nil then
        local loadState = JSON.decode(save_state)
        if loadState and loadState ~= {} then
            max_rounds = loadState.max_rounds
            state = loadState.state
            history = loadState.history
            players = loadState.players
            stones = loadState.stones
            round = loadState.round
            even_distribution = loadState.even_distribution
            after_dials_mode = loadState.after_dials_mode
            dice_roll_mode = loadState.dice_roll_mode
            for color, player in pairs(players) do
                required_dice_roll_players[color] = true
                if player.side then
                    sided_players[player.side] = player
                    self.UI.setAttribute("Register" .. player.side, "active", "false")
                    self.UI.setAttribute(player.side .. "PointPanel", "color", color)
                    self.UI.setAttribute(player.side .. "PointPanel", "active", "true")
                    self.UI.setAttribute(player.side .. "PointText", "text", tostring(player.points))
                end
            end


            if loadState.timer_state then
                timerStats = loadState.timer_state
                if timerStats.started then
                    self.UI.setAttribute("SetupPanel", "active", false)
                    self.UI.setAttribute("StartedClockPanel", "active", true)
                    timerStats.start_time = os.time()
                end
            end
        end
    end

    recreateIndicators()
    setContextMenu()
    self.tooltip = false
    Wait.time(updateTime, 0.2, -1)
end

function onSave()
    local sState = {}
    sState.max_rounds = max_rounds
    sState.state = state
    sState.history = history
    sState.players = players
    sState.stones = stones
    sState.round = round
    sState.even_distribution = even_distribution
    sState.after_dials_mode = after_dials_mode
    sState.dice_roll_mode = dice_roll_mode
    sState.timer_state = {
        length = timerStats.length,
        random = timerStats.random,
        hidden = timerStats.hidden,
        auto_start = timerStats.auto_start,
        start_time = nil,
        elapsed_time = 0,
        paused = timerStats.paused,
        started = timerStats.started,
        end_offset = timerStats.end_offset,
        total_elapsed_time = timerStats.total_elapsed_time + timerStats.elapsed_time,
        total_time = timerStats.total_time
    }
    return JSON.encode(sState)
end

timerStats = {
    length = 75,
    random = false,
    hidden = false,
    auto_start = true,
    start_time = nil,
    elapsed_time = 0,
    paused = false,
    started = false,
    end_offset = 0,
    total_elapsed_time = 0,
    total_time = 0
}

function lengthButton()
    self.AssetBundle.playTriggerEffect(0)
    if timerStats.length >= 120 then
        timerStats.length = 45
    else
        timerStats.length = timerStats.length + 15
    end
    self.UI.setAttribute("LengthButton", "text", tostring(timerStats.length) .. " Min")
end

function minusLengthButton()
    self.AssetBundle.playTriggerEffect(0)
    if timerStats.length > 1 then
        timerStats.length = timerStats.length - 1
    end
    self.UI.setAttribute("LengthButton", "text", tostring(timerStats.length) .. " Min")
end

function plusLengthButton()
    self.AssetBundle.playTriggerEffect(0)
    timerStats.length = timerStats.length + 1
    self.UI.setAttribute("LengthButton", "text", tostring(timerStats.length) .. " Min")
end

function hiddenButton()
    self.AssetBundle.playTriggerEffect(0)
    timerStats.hidden = not timerStats.hidden
    if timerStats.hidden then
        self.UI.setAttribute("HiddenButton", "text", "Hidden")
    else
        self.UI.setAttribute("HiddenButton", "text", "Visible")
    end
end

function randomButton()
    self.AssetBundle.playTriggerEffect(0)
    timerStats.random = not timerStats.random
    if timerStats.random then
        self.UI.setAttribute("RandomButton", "text", "Random")
    else
        self.UI.setAttribute("RandomButton", "text", "Fixed")
    end
end

function startButton()
    timerStats.start_time = os.time()
    timerStats.started = true
    self.AssetBundle.playTriggerEffect(0)
    self.UI.setAttribute("SetupPanel", "active", false)
    self.UI.setAttribute("StartedClockPanel", "active", true)
    if timerStats.random then
        local minutes = 0
        for _ = 1, 3, 1
        do
            if math.random(8) <= 5 then
                minutes = minutes + 1
            end
        end
        local attackDiceRandom = math.random(8)
        if (attackDiceRandom <= 4) then
            timerStats.end_offset = minutes
        elseif (attackDiceRandom <= 6) then
            timerStats.end_offset = -minutes
        else
            timerStats.end_offset = 0
        end
    else
        timerStats.end_offset = 0
    end
    timerStats.total_time = (timerStats.length + timerStats.end_offset) * 60
end

function autoStartButton()
    self.AssetBundle.playTriggerEffect(0)
    timerStats.auto_start = not timerStats.auto_start
    if timerStats.auto_start then
        self.UI.setAttribute("AutoStartButton", "text", "Auto")
    else
        self.UI.setAttribute("AutoStartButton", "text", "Manual")
    end
end

function pauseButton()
    if timerStats.started then
        self.AssetBundle.playTriggerEffect(0)
        timerStats.paused = not timerStats.paused
        if timerStats.paused then
            timerStats.total_elapsed_time = timerStats.total_elapsed_time + timerStats.elapsed_time
            timerStats.elapsed_time = 0
        else
            timerStats.start_time = os.time()
        end
    else
        self.AssetBundle.playLoopingEffect(0)
        self.AssetBundle.playTriggerEffect(0)
    end
end

hiddenTokens = { '*', ' ' }

function updateTime()
    if not timerStats.started then
        return
    end
    if not timerStats.paused then
        timerStats.elapsed_time = os.time() - timerStats.start_time
    end

    local elapsed_time = math.floor(timerStats.elapsed_time + timerStats.total_elapsed_time)
    if timerStats.started and (elapsed_time > timerStats.total_time) then
        timerStats.started = false
        self.AssetBundle.playLoopingEffect(1)
        self.UI.setAttribute("TimerText", "text", string.format("TIME IS UP"))
    elseif timerStats.started then
        if timerStats.hidden then
            if timerStats.paused then
                self.UI.setAttribute("TimerText", "text",
                    string.format("%s PAUSED %s", hiddenTokens[elapsed_time % 2 + 1], hiddenTokens[elapsed_time % 2 + 1]))
            else
                self.UI.setAttribute("TimerText", "text",
                    string.format("%s ACTIVE %s", hiddenTokens[elapsed_time % 2 + 1], hiddenTokens[elapsed_time % 2 + 1]))
            end
        elseif timerStats.random then
            local hours = math.floor(elapsed_time / 3600)
            local minutes = math.floor((elapsed_time - hours * 3600) / 60)
            local seconds = elapsed_time % 60
            self.UI.setAttribute("TimerText", "text", string.format("%d:%02d:%02d", hours, minutes, seconds))
        else
            local secondsTotal = timerStats.total_time - elapsed_time
            local hours = math.floor(secondsTotal / 3600)
            local minutes = math.floor((secondsTotal - hours * 3600) / 60)
            local seconds = secondsTotal % 60
            self.UI.setAttribute("TimerText", "text", string.format("%d:%02d:%02d", hours, minutes, seconds))
        end
    end
end

guiIdToSide = {
    RegisterLeft = "Left",
    RegisterRight = "Right",
    RightPointPlus = "Right",
    LeftPointPlus = "Left",
    RightPointMinus = "Right",
    LeftPointMinus = "Left"
}

function registerPlayerFromGui(player, option, id)
    local side = guiIdToSide[id]
    self.AssetBundle.playTriggerEffect(0)
    if table.find({ 'White', 'Gray', 'Black' }, player.color) then
        printToAll("Please select a player color before registering", { 1, 0.4, 0 })
    else
        if players[player.color] and players[player.color].side then
            printToAll(player.steam_name .. " already registered with the game console", { 1, 0.4, 0 })
            return
        end
        printToAll(player.steam_name .. " registered with the game console", { 1, 0.4, 0 })
        players[player.color] = { color = player.color, set = false, side = side, points = 0, round_points = {} }
        sided_players[side] = players[player.color]
        self.UI.setAttribute(id, "active", "false")
        self.UI.setAttribute(side .. "PointPanel", "color", player.color)
        self.UI.setAttribute(side .. "PointPanel", "active", "true")
        for _, player in pairs(players) do
            if player.side and player.side ~= side then
                start()
            end
        end
    end
end

function addPoint(player, option, id)
    self.AssetBundle.playTriggerEffect(0)
    if state == "active" and round > 0 then
        local side = guiIdToSide[id]
        if id:find('Plus') then
            sided_players[side].points = sided_players[side].points + 1
            sided_players[side].round_points[round] = (sided_players[side].round_points[round] or 0) + 1
        elseif sided_players[side].points > 0 then
            sided_players[side].points = sided_players[side].points - 1
            sided_players[side].round_points[round] = (sided_players[side].round_points[round] or 0) - 1
        end
        self.UI.setAttribute(side .. "PointText", "text", tostring(sided_players[side].points))
        updateRoundPoints(round, side)
    end
end

function updateRoundPoints(round, side)
    if sided_players[side].round_points == 0 then
        indicators[round].UI.setAttribute(side .. "PointsPanel", "active", "false")
    else
        indicators[round].UI.setAttribute(side .. "PointsPanel", "active", "true")
        indicators[round].UI.setAttribute(side .. "PointsPanel", "color", sided_players[side].color)
        indicators[round].UI.setAttribute(side .. "PointsText", "text", tostring(sided_players[side].round_points[round]))
    end
end

function setContextMenu()
    self.clearContextMenu()
    if state == "init" then
        self.addContextMenuItem("Register player", registerPlayer, false)
        self.addContextMenuItem("Start", start, false)
        if even_distribution then
            self.addContextMenuItem("Disable fairness", function() setFairness(false) end, false)
        else
            self.addContextMenuItem("Enable fairness", function() setFairness(true) end, false)
        end
        if dice_roll_mode then
            self.addContextMenuItem("Disable dice mode", function() setDiceMode(false) end, false)
        else
            self.addContextMenuItem("Enable dice mode", function() setDiceMode(true) end, false)
        end
    elseif state == "active" then
        if not dice_roll_mode then
            self.addContextMenuItem("Randomize", function() randomizeNext(true) end, false)
            --self.addContextMenuItem("Fill random",function() randomTest(true) end, false)
            --self.addContextMenuItem("Random run",startRandomRun, false)
            --self.addContextMenuItem("Set ready", function(player) setReady({set=true,player=player}) end, false)
        end
        self.addContextMenuItem("Undo previous", goBack, false)
        if not even_distribution then
            self.addContextMenuItem("Change previous", changePrevious, false)
        end
    end
    self.addContextMenuItem("Reset", reset, false)
end

function setFairness(enabled)
    even_distribution = enabled
    setContextMenu()
    if enabled then
        printToAll("Fair distribution enabled when randomizing first player", { 1, 0.4, 0 })
    else
        printToAll("Fair distribution disabled when randomizing first player", { 1, 0.4, 0 })
    end
end

function setDiceMode(enabled)
    dice_roll_mode = enabled
    setContextMenu()
    if enabled then
        printToAll("Dice roll mode enabled for the first player randomizer", { 1, 0.4, 0 })
    else
        printToAll("Dice roll mode disabled for the first player randomizer", { 1, 0.4, 0 })
    end
end

function reset()
    timerStats = {
        length = 75,
        random = false,
        hidden = false,
        auto_start = true,
        start_time = nil,
        elapsed_time = 0,
        paused = false,
        started = false,
        end_offset = 0,
        total_elapsed_time = 0,
        total_time = 0
    }
    self.UI.setAttribute("SetupPanel", "active", true)
    self.UI.setAttribute("StartedClockPanel", "active", false)
    self.UI.setAttribute("RegisterLeft", "active", true)
    self.UI.setAttribute("LeftPointPanel", "active", false)
    self.UI.setAttribute("RegisterRight", "active", true)
    self.UI.setAttribute("RightPointPanel", "active", false)
    self.UI.setAttribute("LengthButton", "text", tostring(timerStats.length) .. " Min")
    self.UI.setAttribute("HiddenButton", "text", "Visible")
    self.UI.setAttribute("RandomButton", "text", "Fixed")

    state = "init"
    round = 0
    history = {}
    players = {}
    sided_players = {}
    required_dice_roll_players = {}
    max_rounds = 13
    recreateIndicators()
    setContextMenu()
end

function start()
    if table.size(players) < 2 then
        printToAll("Unable to start the game, needs at least 2 registered players", { 1, 0.4, 0 })
        return
    end
    state = "active"
    setContextMenu()
    for color, _ in pairs(players) do
        table.insert(stones, color)
        table.insert(stones, color)
        table.insert(stones, color)
    end
    for color, player in pairs(players) do
        required_dice_roll_players[color] = true
    end
    printToAll("The game is started", { 1, 0.4, 0 })
end

function registerPlayer(new_player)
    if players[new_player] then
        printToAll(new_player .. " player already registered with the game console", { 1, 0.4, 0 })
        return
    end
    printToAll(new_player .. " player registered with the game console", { 1, 0.4, 0 })
    players[new_player] = { color = new_player, set = false, side = nil, points = 0, round_points = {} }
end

function deleteIndicators()
    for _, indicator in pairs(indicators) do
        destroyObject(indicator)
    end
    indicators = {}
end

function show()
    Wait.condition(recreateIndicators, function() return (not self.isSmoothMoving()) end)
end

function recreateIndicators()
    deleteIndicators()
    self.destroyAttachments()
    local adjusted_max_offset = max_offset
    local scaleFactor = 0
    if max_rounds > 12 then
        adjusted_max_offset = adjusted_max_offset + 0.02 * (max_rounds - 12)
        scaleFactor = 0.02
        for i = 1, max_rounds - 12, 1
        do
            scaleFactor = scaleFactor + 0.25 * (0.99 ^ i)
        end
    end
    local range = 2 * adjusted_max_offset

    for i = 1, max_rounds, 1
    do
        local fraction = (i - 1) / (max_rounds - 1)
        local offset = adjusted_max_offset - range * fraction
        local indicator = spawnObject({
            type         = "Custom_Model",
            position     = self.positionToWorld(vector(-0.1, 0.05, offset)),
            rotation     = self.getRotation() + vector(0, 0, 45),
            scale        = vector(0.65, 0.65, 0.65) - vector(0.05, 0, 0.1) * scaleFactor,
            sound        = false,
            snap_to_grid = false,
        })
        indicator.setCustomObject({
            mesh =
            '{verifycache}https://raw.githubusercontent.com/JohnnyCheese/TTS_X-Wing2.0/master/assets/models/randomtile.obj',
            convex = true,
            material = 1,
            type = 0
        })

        local leftActive = "false"
        local rightActive = "false"
        local leftPoints = 0
        local rightPoints = 0
        local leftColor = "White"
        local rightColor = "White"
        if table.size(sided_players) > 1 then
            leftColor = sided_players["Left"].color
            rightColor = sided_players["Right"].color
            if sided_players["Left"].round_points[i] and sided_players["Left"].round_points[i] ~= 0 then
                leftActive = "true"
                leftPoints = sided_players["Left"].round_points[i]
            end
            if sided_players["Right"].round_points[i] and sided_players["Right"].round_points[i] ~= 0 then
                rightActive = "true"
                rightPoints = sided_players["Right"].round_points[i]
            end
        end

        indicator.UI.setXml('<Panel id="LeftPointsPanel" color="' ..
            leftColor ..
            '" rotation="180 180 90" width="50" height="31" position="82 32 -5" active="' ..
            leftActive ..
            '"><Text id="LeftPointsText" color="#111111" fontSize="22" fontStyle="Bold">' ..
            tostring(leftPoints) ..
            '</Text></Panel><Panel id="RightPointsPanel" color="' ..
            rightColor ..
            '" rotation="180 180 90" width="50" height="31" position="-82 -32 -5" active="' ..
            rightActive ..
            '"><Text id="RightPointsText" color="#111111" fontSize="22" fontStyle="Bold">' ..
            tostring(rightPoints) ..
            '</Text></Panel><Text id="IdLabel" resizeTextForBestFit="true" resizeTextMinSize="30" resizeTextMaxSize="70" color="#111111" rotation="180 180 90" position="0 0 -5" height="100" fontSize="50" fontStyle="Bold">' ..
            tostring(i - 1) .. '</Text>')
        indicator.setName("indicator")
        indicator.setDescription(i - 1)
        indicator.setLock(true)
        indicator.interactable = false
        indicator.addTag("TempLayoutElement")
        if history[i] then
            indicator.setColorTint(history[i])
        else
            indicator.setColorTint(default_color)
        end
        table.insert(indicators, indicator)
    end
end

function setIndicator(index, color)
    indicators[index].setColorTint(color)
end

function randomizeColor()
    if even_distribution then
        local index = math.random(#stones)
        local pick = stones[index]
        table.remove(stones, index)
        if round % table.size(players) == 0 then
            for _, player in pairs(players) do
                table.insert(stones, player.color)
            end
        end
        return pick
    else
        local i = 1
        local pick = math.random(table.size(players))
        for color, player in pairs(players) do
            if i == pick then
                return color
            end
            i = i + 1
        end
        print("Error, picked a value not within player range")
        return Color.White
    end
end

function randomizeNext(verbose)
    round = round + 1
    local color = randomizeColor()
    table.insert(history, color)
    if round > max_rounds then
        max_rounds = round
        recreateIndicators()
    else
        setIndicator(round, color)
    end
    if verbose then
        printToAll( "[" .. Color.fromString(color):toHex() .. "]" .. color .. "[-] player is first in round " .. tostring(round - 1), { 1, 0.4, 0 })
    end
    return color
end

function randomTest(verbose)
    round = 0
    local counts = {}
    stones = {}
    for _, player in pairs(players) do
        counts[player.color] = 0
        table.insert(stones, player.color)
        table.insert(stones, player.color)
        table.insert(stones, player.color)
    end
    for _ = 1, max_rounds, 1
    do
        local color = randomizeNext()
        counts[color] = counts[color] + 1
    end
    if verbose then
        for color, count in pairs(counts) do
            print(tostring(color) .. " " .. tostring(count))
        end
    else
        runningCounts[counts[players[1].color]] = runningCounts[counts[players[1].color]] + 1
    end
end

function startRandomRun()
    runningCounts = {
        [0] = 0,
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0,
        [7] = 0,
        [8] = 0,
        [9] = 0,
        [10] = 0,
        [11] = 0,
        [12] = 0
    }
    Wait.time(randomTest, 0.1, 100)
    Wait.time(presentRandomResults, 20 / 2)
end

function presentRandomResults()
    for n, count in pairs(runningCounts) do
        print("c[ " .. tostring(n) .. " ] = " .. tostring(count))
    end
end

function setReady(argTable)
    if argTable.set == true and after_dials_mode then
        if not Global.call('API_IsAllDialsSet', { player = argTable.player }) then

        end
    end
    Wait.stop(wait_timer)
    players[argTable.player].set = argTable.set
    for color, player in pairs(players) do
        if not player.set then
            return
        end
    end
    wait_timer = Wait.time(function() randomizeNext(true) end, 3)
end

function goBack()
    if round > 0 then
        printToAll("The result for round " .. tostring(round - 1) .. " is canceled", { 1, 0.4, 0 })

        if table.size(sided_players) > 1 then
            sided_players["Left"].round_points[round - 1] = (sided_players["Left"].round_points[round - 1] or 0) +
                (sided_players["Left"].round_points[round] or 0)
            sided_players["Left"].round_points[round] = 0
            sided_players["Right"].round_points[round - 1] = (sided_players["Right"].round_points[round - 1] or 0) +
                (sided_players["Right"].round_points[round] or 0)
            sided_players["Right"].round_points[round] = 0
        end

        round = round - 1
        table.remove(history, #history)
        if even_distribution then
            recreateStoneBag()
        end
        recreateIndicators()
    end -- if round > 0
end

function changePrevious()
    if round > 0 then
        local first_color = nil
        local choose_next = false
        for color, _ in pairs(players) do
            if first_color == nil then
                first_color = color
            end
            if choose_next then
                history[round] = color
                recreateIndicators()
                return
            end
            if color == history[round] then
                choose_next = true
            end
        end -- for pair(players)
        history[round] = first_color
        recreateIndicators()
    end -- if round > 0
end

function recreateStoneBag()
    stones = {}
    -- Calculate number of total stones per player in play
    local total_stones = 3 + math.floor(round / table.size(players))
    for color, player in pairs(players) do
        local player_stones = total_stones
        -- Remove already drawn stones for a player
        for _, h in pairs(history) do
            if h == color then
                player_stones = player_stones - 1
            end
        end
        -- Add the remaining stones to the bag
        for _ = 1, player_stones, 1
        do
            table.insert(stones, color)
        end -- For player_stones
    end     -- for pairs(players)
end

function firstPlayerRoll(args)
    if dice_roll_mode and state == "active" and required_dice_roll_players[args.color] then
        printToAll("[" .. Color.fromString(args.color):toHex() .. "]" .. args.player .. "[-] rolled for first player", { 1, 0.4, 0 })
        --printToAll("Score:" .. tostring(args.score), {1, 0.4, 0})

        dice_roll_scores[args.color] = args.score
        if table.size(dice_roll_scores) == table.size(required_dice_roll_players) then
            Wait.stop(dice_roll_timer)
            local highest_score = 0
            local highest_players = {}
            for color, score in pairs(dice_roll_scores) do
                if score > highest_score then
                    highest_score = score
                    highest_players = { color }
                elseif score == highest_score then
                    table.insert(highest_players, color)
                end
            end

            printToAll("All players have rolled for first player.", { 1, 0.4, 0 })
            required_dice_roll_players = {}
            if #highest_players > 1 then
                local print_str = "Players;"
                for _, color in pairs(highest_players) do
                    required_dice_roll_players[color] = true
                    print_str = print_str .. " [" .. Color.fromString(color):toHex() .. "]" .. color .. "[-],"
                end
                printToAll(print_str .. " rolled the same result and must reroll their first player dice", { 1, 0.4, 0 })
                dice_roll_scores = {}
            else
                round = round + 1
                local color = highest_players[1]
                table.insert(history, color)
                for color, player in pairs(players) do
                    required_dice_roll_players[color] = true
                end
                if round > max_rounds then
                    max_rounds = round
                    recreateIndicators()
                else
                    setIndicator(round, color)
                end
                if round == 2 then
                    -- This is start of first round, we potentially start the clock automatically
                    if timerStats.auto_start then
                        startButton()
                    end
                end
                printToAll( "[" .. Color.fromString(color):toHex() .. "]" .. color .. "[-] player is first in round " .. tostring(round - 1), { 1, 0.4, 0 })
                Global.call("API_StreamAnnounce", { text = "First Player", player = color })
                dice_roll_scores = {}
            end
        else
            Wait.stop(dice_roll_timer)
            dice_roll_timer = Wait.time(firstPlayerRollTimeout, 30)
        end
    end
end

function firstPlayerRollTimeout()
    printToAll("Automatic detection of first player roll timed out, all players must roll at the same time.", { 1, 0.4, 0 })
    dice_roll_scores = {}
end

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
return __bundle_require("Game Console.c9a2a0.lua")