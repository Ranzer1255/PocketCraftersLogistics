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

-- TODO: We'll come back to this idea later
-- --recursively generates the list of items needed to craft the supplied recipe 
-- local function getReqirements(item,count,requirements,network)
--     recipe = prototypes.recipe[item]
    

--     inNetwork = network.get_item_count(item)
--     if (inNetwork>=count or not (recipe.category=="crafting")) then
--         requirements[item]=(requirements[item] or 0) + count
--     else
--         craftsNeeded = math.ceil(count / recipe.products[1].amount)
--         for _, ingredient in pairs(recipe.ingredients) do
--             getReqirements(ingredient.name,ingredient.amount*craftsNeeded,requirements,network)
--         end
--     end
-- end

local function process_requests(player)

    --get Recipe for item in player's hand
    local itemName = getItemInHand(player)

    --guard clause: No item in player's hand or it isn't a craftable item
    if not itemName then
        player.print("no item selected or item has no recipe")
        return;
    end
    
    --Guard clause: check if recipe is handcraftable
    if not (prototypes.recipe[itemName].category=="crafting") then
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

    --[[
    local network = player.force.find_logistic_network_by_position(player.position,player.surface)

    
    if not network then
        player.print("no network found in logistics range?") --todo fail to a default request of just the recipe
        return
    end
    ]]--

    --get list of required items to craft item
    local requirements = {}
    for _, ingredient in pairs(prototypes.recipe[itemName].ingredients) do
       requirements[ingredient.name] = ingredient.amount
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
    local multiplier = settings.get_player_settings(player)["pc-craft-order-multiple"].value

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
