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


local function isHandCraftable(itemRecipeCategory)
    local handCraftCategories = prototypes.entity["character"].crafting_categories
    if handCraftCategories then 
        return handCraftCategories[itemRecipeCategory] or false
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
            not isHandCraftable(recipe.category) or --we can't craft it
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


local function process_requests(player)

    --get Recipe for item in player's hand
    local itemName = getItemInHand(player)

    --guard clause: No item in player's hand or it isn't a craftable item
    if not itemName then
        player.print("no item selected or item has no recipe")
        return
    end

    --Guard clause: check if recipe is handcraftable
    if not (isHandCraftable(prototypes.recipe[itemName].category)) then
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
