function onLoad(save_state)
    -- X-Wing United : les locks sont toujours bleus (jumeau blanc), les
    -- options de couleur ont été retirées.
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
