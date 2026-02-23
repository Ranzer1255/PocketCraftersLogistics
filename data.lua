data:extend({
  {
    type = "shortcut",
    name = "br-request-shortcut",
    action = "lua",
    -- The main icon
    icon = "__base__/graphics/icons/blueprint.png",
    icon_size = 64,
    -- The small icon (required for the selection menu)
    small_icon = "__base__/graphics/icons/blueprint.png",
    small_icon_size = 64,
    
    localised_name = "Request items from held blueprint",
    associated_control_input = "br-request-hotkey"
  },
  {
    type = "custom-input",
    name = "br-request-hotkey",
    key_sequence = "SHIFT + G"
  }
})