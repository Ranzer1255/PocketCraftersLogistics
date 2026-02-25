data:extend({
  {
    type = "shortcut",
    name = "pc-request-shortcut",
    action = "lua",
    -- The main icon
    icon = "__base__/graphics/icons/coin.png",
    icon_size = 64,
    -- The small icon (required for the selection menu)
    small_icon = "__base__/graphics/icons/coin.png",
    small_icon_size = 64,
    
    localised_name = "Request items to Craft Held item",
    associated_control_input = "pc-request-hotkey"
  }
})