local HandmadeMode = require("control/handmade-arrangement") ---@as TransitionTable
local FactoriopediaModes = require("control/factoriopedia-arrangements")
local FactoriopediaLoopingMode = FactoriopediaModes.LOOPING ---@as TransitionTable
local FactoriopediaNonLoopingMode = FactoriopediaModes.NON_LOOPING ---@as TransitionTable

------------------------------------------------------------------------
-- Functions to change held item/ghost.
------------------------------------------------------------------------

---@param ent LuaEntity | nil
---@param entProt LuaEntityPrototype|LuaTilePrototype
---@return ItemIDAndQualityIDPair | nil
local function entityProtToItem(ent, entProt)
	-- Returns item associated with this entity.
	-- Entity could be something you placed (eg transport belt), a mineable (eg iron ore), or a ghost building/tile.
	if entProt.items_to_place_this ~= nil and #entProt.items_to_place_this ~= 0 then
		local itemToPlace = entProt.items_to_place_this[1]
		return {name = itemToPlace.name, quality = itemToPlace.quality}
	elseif entProt.mineable_properties ~= nil
		and entProt.mineable_properties.minable
		and entProt.mineable_properties.products ~= nil
		and #entProt.mineable_properties.products ~= 0
		and entProt.mineable_properties.products[1].type == "item" then
		return {name = entProt.mineable_properties.products[1].name, quality = nil}
	elseif (entProt.type == "entity-ghost" or entProt.type == "tile-ghost") and ent ~= nil then
		local ghostProt = ent.ghost_prototype
		return entityProtToItem(nil, ghostProt)
	end
end

---@param player LuaPlayer
---@param item ItemIDAndQualityIDPair
local function showSwitchMessage(player, item)
	if player.mod_settings["VariantHotkeys-switch-message"].value then
		local itemProt = prototypes.item[item.name]
		if itemProt ~= nil and itemProt.localised_name ~= nil then
			player.clear_local_flying_texts()
			player.create_local_flying_text{text = itemProt.localised_name, create_at_cursor = true} -- Can't specify speed or time to live if create_at_cursor is true.
		end
	end
end

---@param player LuaPlayer
---@param item ItemIDAndQualityIDPair
local function switchToItemOrGhost(player, item)
	player.clear_cursor() -- Do this before anything else, to put held items back into inventory.
	-- Given player and item name, switch to item or ghost with that itemName, depending if player has that item.
	local inventory = player.get_main_inventory()
	-- Note that this inventory will be nil if player is in remote view.
	if inventory ~= nil then
		local targetInInventory = inventory.find_item_stack(item)
		if targetInInventory ~= nil then
			player.cursor_stack.set_stack(targetInInventory)
			showSwitchMessage(player, item)
			targetInInventory.clear() -- Remove from inventory so we don't dupe items.
			return
		end
	end
	-- If we reach this point we couldn't put an item from inventory into player's cursor, so put a ghost instead.
	player.cursor_ghost = item
	showSwitchMessage(player, item)
end

---@param player LuaPlayer
---@return ItemIDAndQualityIDPair | nil
local function getPlayerHeldItem(player)
	-- Returns name and quality of item or ghost that player is holding, or nil if they are not holding anything.
	if player.cursor_stack ~= nil and player.cursor_stack.valid_for_read then
		return { name = player.cursor_stack.name, quality = player.cursor_stack.quality }
	elseif player.cursor_ghost ~= nil then
		local name = player.cursor_ghost.name
		if type(name) ~= "string" then name = name.name end -- Weird.
		return { name = player.cursor_ghost.name.name, quality = player.cursor_ghost.quality }
	else
		--No held item or ghost.
		-- Would be nice to be able to move between signals in the cursor, but I can't see any way to do that with the API.
	end
end

---@param player LuaPlayer
---@param transitionDict { string: string }
local function tryChangeFrom(player, transitionDict, startItem)
	local newItemName = transitionDict[startItem.name]
	if prototypes.item[newItemName] == nil then
		--player.print("tried to switch to non-existent item: " .. (newItemName or "nil"))
		return
	end
	if newItemName ~= nil then
		--player.print("switching to " .. (newItemName or "nil"))
		local newItem  = {name = newItemName, quality = startItem.quality}
		switchToItemOrGhost(player, newItem)
		return
	end
end

---@param player LuaPlayer
---@param transitionDict { string: string }
local function tryChangeItem(player, transitionDict)
	-- Given player and transition dict for currently-held item/ghost, try to change held item/ghost.
	local held = getPlayerHeldItem(player)
	if held ~= nil and held.name ~= nil then
		--game.print("held item: " .. serpent.line(held))
		tryChangeFrom(player, transitionDict, held)
	elseif player.selected ~= nil then
		-- If nothing held, look at selected entity, if any.
		--player.print("selected entity: " .. serpent.line(player.selected))
		local item = entityProtToItem(player.selected, player.selected.prototype)
		-- TODO maybe handle non-ghost tiles. Would need to check what's under cursor, not player.selected.
		if item ~= nil then
			tryChangeFrom(player, transitionDict, item)
		end
	else
		--player.print("nothing held")
	end
end


------------------------------------------------------------------------
-- Handlers for the custom input events.
------------------------------------------------------------------------

---@param event EventData.CustomInputEvent
---@param transitionKey Key
local function handleEvent(event, transitionKey)
	---@cast event EventData.CustomInputEvent
	if event.player_index == nil then return end
	local player = game.get_player(event.player_index)
	if player == nil or not player.valid then return end

	local playerMode = player.mod_settings["VariantHotkeys-mode"].value
	if playerMode == "factoriopedia-non-looping" then
		transitionDict = FactoriopediaNonLoopingMode
	elseif playerMode == "factoriopedia-looping" then
		transitionDict = FactoriopediaLoopingMode
	elseif playerMode == "handmade" then
		transitionDict = HandmadeMode
	else
		log("Error: unknown player mode: " .. playerMode)
		return
	end
	tryChangeItem(player, transitionDict[transitionKey])
end

---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-up", function(event) handleEvent(event, "UP") end)
---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-down", function(event) handleEvent(event, "DOWN") end)
---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-left", function(event) handleEvent(event, "LEFT") end)
---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-right", function(event) handleEvent(event, "RIGHT") end)
---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-tab-left", function(event) handleEvent(event, "TAB_LEFT") end)
---@diagnostic disable-next-line: param-type-mismatch
script.on_event("VariantHotkeys-tab-right", function(event) handleEvent(event, "TAB_RIGHT") end)

-- TODO maybe add API for other mods to add their own rules to the transition tables.