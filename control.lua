------------------------------------------------------------------------
-- Tools to build a table of transitions between items.
------------------------------------------------------------------------

-- These hold the item names we transition between when the hotkeys are pressed.
local UP = {} ---@type { string: string }
local DOWN = {} ---@type { string: string }
local LEFT = {} ---@type { string: string }
local RIGHT = {} ---@type { string: string }

---@param entProt LuaEntityPrototype
---@return string|nil
local function entityProtToItemName(entProt)
	-- Returns name of item that places this entity.
	if entProt.items_to_place_this == nil or #entProt.items_to_place_this == 0 then return nil end
	return entProt.items_to_place_this[1].name
end

local function addUpperLower(a, b)
	if DOWN[a] ~= nil or UP[b] ~= nil then
		log("Error: tried to create upper-lower relation between " .. a .. " and " .. b .. " but already have: " .. (UP[b] or "nil") .. " and " .. (DOWN[a] or "nil"))
		return
	end
	DOWN[a] = b
	UP[b] = a
end
local function addLeftRight(a, b)
	if RIGHT[a] ~= nil or LEFT[b] ~= nil then
		log("Error: tried to create left/right relation between " .. a .. " and " .. b .. " but already have: " .. (LEFT[b] or "nil") .. " and " .. (RIGHT[a] or "nil"))
		return
	end
	RIGHT[a] = b
	LEFT[b] = a
end

local function addUpwardChain(l)
	if #l < 2 then
		log("Error: tried to create upward chain with only one item: " .. serpent.line(l))
		return
	end
	for i = 1, #l - 1 do
		addUpperLower(l[i], l[i + 1])
	end
end



------------------------------------------------------------------------
--- Build tables of belts, and then populate transition tables.
------------------------------------------------------------------------

-- TODO belts, splitters, undergrounds

local belts = {} ---@type { number: string }
local beltToNext = {} ---@type { string: string }
local beltToPrev = {}
local beltToUnderground = {} ---@type { string: string }

for _, belt in pairs(prototypes.get_entity_filtered{{filter="type", type="transport-belt"}}) do
	---@cast belt LuaEntityPrototype
	local beltItemName = entityProtToItemName(belt)
	table.insert(belts, beltItemName)
	if beltItemName ~= nil then
		local nextBelt = belt.next_upgrade
		if nextBelt ~= nil then
			local nextBeltItemName = entityProtToItemName(nextBelt)
			if nextBeltItemName ~= nil then
				beltToNext[beltItemName] = nextBeltItemName
				beltToPrev[nextBeltItemName] = beltItemName
			end
		end
		local underground = belt.related_underground_belt
		if underground ~= nil then
			local undergroundItemName = entityProtToItemName(underground)
			if undergroundItemName ~= nil then
				beltToUnderground[beltItemName] = undergroundItemName
			end
		end
	end
end

-- Add loop-around from top to bottom.
local bottomBelt = belts[1]
while beltToPrev[bottomBelt] ~= nil do bottomBelt = beltToPrev[bottomBelt] end
local topBelt = belts[1]
while beltToNext[topBelt] ~= nil do topBelt = beltToNext[topBelt] end
beltToNext[topBelt] = bottomBelt
beltToPrev[bottomBelt] = topBelt

for _, belt in pairs(belts) do
	local nextBelt = beltToNext[belt]
	if nextBelt ~= nil then
		addUpperLower(nextBelt, belt)
	end
	local underground = beltToUnderground[belt]
	if underground ~= nil then
		addLeftRight(underground, belt)
	end
	if underground ~= nil and nextBelt ~= nil then
		local nextUnderground = beltToUnderground[nextBelt]
		if nextUnderground ~= nil then
			addUpperLower(nextUnderground, underground)
		end
	end
end


------------------------------------------------------------------------
--- Populate transition tables for some ad-hoc stuff.
------------------------------------------------------------------------

-- TODO inserters
-- TODO rails, signals, train stations.
-- TODO rails, rail pillars, rail ramps
-- TODO iron copper steel plastic sulfur carbon
-- TODO gears, sticks, cables
-- TODO circuits
-- TODO rocket fuel, nuclear fuel, solid fuel, etc.
-- TODO power poles
-- TODO pipes, underground pipes, pumps, tanks
-- TODO tiles -- stone brick, concrete, refined
-- TODO boiler, steam engine
-- TODO heat exchanges, turbine, heat pipe
-- TODO furnace
-- TODO assembling machines
-- TODO chem plant, refinery
-- TODO modules! up/down and left/right
-- TODO lightning rod
-- TODO fusion generator and reactor
-- TODO lab and biolab
-- TODO chests, and logistic chests
-- TODO combinators
-- TODO gleba soils
-- TODO bot types

------------------------------------------------------------------------
-- Functions to change held item/ghost.
------------------------------------------------------------------------

---@param player LuaPlayer
---@param item ItemIDAndQualityIDPair
local function switchToItemOrGhost(player, item)
	-- Given player and item name, switch to item or ghost with that itemName, depending if player has that item.
	local inventory = player.get_main_inventory()
	if inventory == nil then return end
	local targetInInventory = inventory.find_item_stack(item)
	if targetInInventory ~= nil then
		player.cursor_stack.set_stack(targetInInventory)
	else
		player.clear_cursor()
		player.cursor_ghost = item
	end
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
	end
end

---@param player LuaPlayer
---@param transitionDict { string: string }
local function tryChangeItem(player, transitionDict)
	-- Given player and transition dict for currently-held item/ghost, try to change held item/ghost.
	local held = getPlayerHeldItem(player)
	if held ~= nil and held.name ~= nil then
		--game.print("held item: " .. serpent.line(held))
		local newItemName = transitionDict[held.name]
		if newItemName ~= nil then
			game.print("switching to " .. (newItemName or "nil"))
			local newItem  = {name = newItemName, quality = held.quality}
			switchToItemOrGhost(player, newItem)
			return
		end
	else
		-- TODO maybe do something with selected entity, eg pick it and then do the transition.
		game.print("nothing held")
	end
end


------------------------------------------------------------------------
-- Handlers for the custom input events.
------------------------------------------------------------------------

local function handleEvent(event, transitionDict)
	---@cast event EventData.CustomInputEvent
	if event.player_index == nil then return end
	local player = game.get_player(event.player_index)
	if player == nil or not player.valid then return end
	tryChangeItem(player, transitionDict)
end

script.on_event("VariantHotkeys-up", function(event) handleEvent(event, UP) end)
script.on_event("VariantHotkeys-down", function(event) handleEvent(event, DOWN) end)
script.on_event("VariantHotkeys-left", function(event) handleEvent(event, LEFT) end)
script.on_event("VariantHotkeys-right", function(event) handleEvent(event, RIGHT) end)

-- TODO draw a big map of items, with arrows, and post it with the mod.

-- TODO keep quality of selected item stack.

-- TODO check what happens if target item doesn't exist, eg Space Age isn't installed.

-- TODO implement API for other mods to add their own transitions to the dicts.