-- returns String itemName for item in Player's Hand or nil if hand has an incompatible item or is empty
local function getItemInHand(player)

    local itemName
    --player's hand has a stack in it
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        itemName = player.cursor_stack.name --LuaItemStack
    end

    --player's hand has a ghost
    if player.cursor_ghost then
        itemName = player.cursor_ghost.name.name
    end

    return itemName
end


-- returns true if any of the recipe's categories can be crafted by the character
-- (2.1 replaced LuaRecipePrototype.category with the categories array)
local function isHandCraftable(recipe)
    if not recipe then return false end
    local handCraftCategories = prototypes.entity["character"].crafting_categories
    if not handCraftCategories then return false end
    for _, category in pairs(recipe.categories) do
        if handCraftCategories[category] then
            return true
        end
    end
    return false
end


--generates the list of items needed to craft the supplied recipe 
local function getNetworkReqirements(baseRequirements,network)
    local finalRequirements = {}
    while next(baseRequirements) ~= nil do
        
        local itemName, ammount = next(baseRequirements)
        if not itemName then break end
        baseRequirements[itemName]=nil

        local recipe = prototypes.recipe[itemName]

        if 
            not recipe or --there's no recipe
            not isHandCraftable(recipe) or --we can't craft it
            ((network.get_item_count(itemName) - (finalRequirements[itemName] or 0))  >= ammount) --we have enough if it on hand
        then
            finalRequirements[itemName] = (finalRequirements[itemName] or 0) + ammount
        else
            local recipe = prototypes.recipe[itemName]
            local yeld = recipe.products[1].amount
            local craftsNeeded = math.ceil(ammount/yeld)

            --add the ingredients to the queue 
            for _, ingredient in pairs(prototypes.recipe[itemName].ingredients) do
                baseRequirements[ingredient.name] = (baseRequirements[ingredient.name] or 0) + (ingredient.amount * craftsNeeded)
            end
        end
    end
    return finalRequirements
end


-- craftCount: how many crafts to request for (1, 5, 10...). Multiplied with the player's Order Multiplier setting.
local function process_requests(player, craftCount)
    craftCount = craftCount or 1

    --get Recipe for item in player's hand
    local itemName = getItemInHand(player)

    --guard clause: No item in player's hand or it isn't a craftable item
    if not itemName then
        player.print("no item selected or item has no recipe")
        return
    end

    --Guard clause: check if recipe is handcraftable
    if not (isHandCraftable(prototypes.recipe[itemName])) then
        player.print("item is not handcraftable")
        return
    end

    --guard clause, player has no physical body. 
    if not player.character then
        player.print("no character")
        return
    end

    --get logistics network objects
    local point = player.character.get_requester_point()

    --Guard clause: Player has not unlocked logistics yet
    if not point then
        player.print("no logistics")
        return
    end

    local network
    if settings.get_player_settings(player)["pc-recuseive-ordering"].value then
        network = player.force.find_logistic_network_by_position(player.position,player.surface)
    end

    --get list of required items to craft item
    local baseRequirements = {}
    local requirements = {}

    for _, ingredient in pairs(prototypes.recipe[itemName].ingredients) do
        baseRequirements[ingredient.name] = ingredient.amount
    end

    if not network then --either the player has disabled recursive ordering or they are not in logistics range
        requirements = baseRequirements
    else
        requirements = getNetworkReqirements(baseRequirements,network)
    end

    --requirements will be useful when i start recursively generating additional items based on what's availble in the Logistics network

    local filters = {}
    for ingredientName, ammount in pairs(requirements) do
        table.insert(filters,{
            value = {
                type = "item",
                name = ingredientName,
                quality = "normal"
            },
            min = ammount
        })
    end



    --add list to requester group
    local multiplier = settings.get_player_settings(player)["pc-craft-order-multiple"].value * craftCount

    section = point.add_section()
    section.filters = filters
    section.active = true
    section.multiplier=multiplier
end


-- Listen for the Shortcut Click
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "pc-request-shortcut" then
        process_requests(game.get_player(event.player_index))
    end
end)


--------------------------------------------------------------------------------
-- Top-left mod GUI button: left-click = 1x, right-click = 5x, shift+click = 10x, ctrl+shift+click = 100x
-- (the shortcut bar can't tell which mouse button / modifier was used)
--------------------------------------------------------------------------------
local mod_gui = require("mod-gui")

local BUTTON_NAME = "pc-request-button"
local UNLOCK_TECH = "logistic-robotics" -- same tech that unlocks the shortcut

local function isUnlocked(force)
    local tech = force.technologies[UNLOCK_TECH]
    return (not tech) or tech.researched -- if a mod removed the tech, don't hide the button forever
end

-- add the button once research is done, remove it if research is reversed.
-- Only touches mod_gui.get_button_flow when unlocked, because that call creates
-- the shared top-left frame and would leave an empty box on screen otherwise.
local function updateButton(player)
    if isUnlocked(player.force) then
        local flow = mod_gui.get_button_flow(player)
        if not flow[BUTTON_NAME] then
            flow.add{
                type = "sprite-button",
                name = BUTTON_NAME,
                sprite = "pc-request-button-sprite",
                style = mod_gui.button_style,
                tooltip = {"pc-gui.request-button-tooltip"}
            }
        end
    else
        local frame = player.gui.top.mod_gui_top_frame
        local flow = (frame and frame.mod_gui_inner_frame) or player.gui.top.mod_gui_button_flow
        if flow and flow[BUTTON_NAME] then
            flow[BUTTON_NAME].destroy()
        end
    end
end

local function updateAllButtons()
    for _, player in pairs(game.players) do
        updateButton(player)
    end
end

local function updateForceButtons(force)
    for _, player in pairs(force.players) do
        updateButton(player)
    end
end

script.on_init(updateAllButtons)
script.on_configuration_changed(updateAllButtons)

script.on_event(defines.events.on_player_created, function(event)
    updateButton(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_changed_force, function(event)
    updateButton(game.get_player(event.player_index))
end)

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
    if event.research.name == UNLOCK_TECH then
        updateForceButtons(event.research.force)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    if not (event.element and event.element.valid and event.element.name == BUTTON_NAME) then return end

    local craftCount = 1
    if event.shift and event.control then
        craftCount = 100
    elseif event.shift then
        craftCount = 10
    elseif event.button == defines.mouse_button_type.right then
        craftCount = 5
    end

    process_requests(game.get_player(event.player_index), craftCount)
end)
