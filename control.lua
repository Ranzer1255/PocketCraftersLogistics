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


local function isHandCraftable(itemRecipeCategories)
    local handCraftCategories = prototypes.entity["character"].crafting_categories
    if handCraftCategories then 
        for _, itemRecipeCategory in pairs(itemRecipeCategories) do
            return handCraftCategories[itemRecipeCategory]
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
            not isHandCraftable(recipe.categories) or --we can't craft it
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

    --guard clause, player has no physical body. 
    if not player.character then
        player.print("no character")
        return
    end

    --get logistics network objects
    local point
    local opened = player.opened
    if player.opened and opened.get_requester_point() then
        point = opened.get_requester_point()
    else
        --Guard clause: check if recipe is handcraftable
        if not (isHandCraftable(prototypes.recipe[itemName].categories)) then
            player.print("item is not handcraftable")
            return
        end
        point = player.character.get_requester_point()
    end

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
        if ingredient.type == "item" then
            baseRequirements[ingredient.name] = ingredient.amount
        end
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
