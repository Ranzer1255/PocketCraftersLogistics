data:extend({
  {
    type = "shortcut",
    name = "pc-request-shortcut",
    action = "lua",
    icon = "__core__/graphics/icons/technology/effect/effect-logistic-slots.png",
    icon_size = 64,
    small_icon = "__core__/graphics/icons/technology/effect/effect-logistic-slots.png",
    small_icon_size = 64,
    technology_to_unlock = "logistic-robotics",
    unavailable_until_unlocked = true,    
    localised_name = "Handcraft Request",
    localized_description = "Hold an item or ghost in your hand and click here to request the materials to craft it from the Logistics Network",
    associated_control_input = "pc-request-hotkey"
  }
})