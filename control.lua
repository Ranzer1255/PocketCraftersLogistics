
-- Listen for the Shortcut Click
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "br-request-shortcut" then
        process_blueprint(game.get_player(event.player_index))
    end
end)

-- Listen for the Hotkey (Shift + G)
script.on_event("br-request-hotkey", function(event)
    process_blueprint(game.get_player(event.player_index))
end)

