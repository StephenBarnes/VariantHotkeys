-- This file creates the "Factoriopedia arrangement" of items. This is done in control stage, not data-final-fixes, so it runs after we're guaranteed all protos have been created.

-- These hold the item names we transition between when the hotkeys are pressed.
---@type { LOOPING: TransitionTable, NON_LOOPING: TransitionTable }
local TRANSITIONS = {
	LOOPING = {
		UP = {},
		DOWN = {},
		LEFT = {},
		RIGHT = {},
		TAB_LEFT = {},
		TAB_RIGHT = {},
	},
	NON_LOOPING = {
		UP = {},
		DOWN = {},
		LEFT = {},
		RIGHT = {},
		TAB_LEFT = {},
		TAB_RIGHT = {},
	},
}

------------------------------------------------------------------------
--- Build tables.
------------------------------------------------------------------------

---@alias NextItem { x: ItemEntry, wrap: boolean }
---@alias NextSubgroup { x: SubgroupEntry, wrap: boolean }
---@alias NextGroup { x: GroupEntry, wrap: boolean }
---@alias ItemEntry { name: string, order: string, left: NextItem, right: NextItem, up: NextItem, down: NextItem, tabLeft: NextItem, tabRight: NextItem }
---@alias SubgroupEntry { name: string, order: string, items: ItemEntry[], up: NextSubgroup, down: NextSubgroup, tabLeft: NextSubgroup, tabRight: NextSubgroup, wrap: boolean }
---@alias GroupEntry { name: string, order: string, subgroups: SubgroupEntry[], tabRight: NextGroup, tabLeft: NextGroup }
local groups = {} ---@type GroupEntry[]

-- Find an entry by .name in a table.
---@param table GroupEntry[] | SubgroupEntry[] | ItemEntry[]
---@param name string
---@return GroupEntry | SubgroupEntry | ItemEntry | nil
local function findByName(table, name)
	for _, entry in pairs(table) do
		if entry.name == name then return entry end
	end
	return nil
end

-- Get entry in a table by index, wrapping around if necessary.
---@generic T
---@param table T[]
---@param index number
---@return { x: T, wrap: boolean }
local function modIndex(table, index)
	return {
		x = table[(index - 1) % #table + 1],
		wrap = (index == 0 or index == #table + 1),
	}
end

-- Get the index of an entry in a table, but if index is above max, then return the last entry.
---@generic T
---@param table T[]
---@param index number
---@return T
local function ceilIndex(table, index)
	return table[math.min(index, #table)]
end

-- Get the order of an item, subgroup, or group.
---@param x LuaItemPrototype | LuaGroup
---@return string
local function getOrder(x)
	if x.order ~= nil then return x.order end
	for _, key in pairs{"place_result", "place_as_equipment_result", "place_as_tile_result"} do
		if x[key] ~= nil and x[key].order ~= nil then return x[key].order end
	end
	log("Error: item/group " .. x.name .. " has no order")
	return ""
end

-- Add an item to the arrangement, creating groups and subgroups as needed.
---@param item LuaItemPrototype
---@return nil
local function addItem(item)
	if item.hidden or item.hidden_in_factoriopedia then return end
	---@diagnostic disable-next-line: undefined-field
	if item.factoriopedia_alternative ~= nil then return end

	local order = getOrder(item)
	local itemEntry = { name = item.name, order = order }

	local subgroup = item.subgroup
	if subgroup == nil then
		log("Error: item " .. item.name .. " has no subgroup")
		return
	end
	local group = subgroup.group
	if group == nil then
		log("Error: item " .. item.name .. " in subgroup " .. subgroup.name .. " has no group")
		return
	end
	local groupEntry = findByName(groups, group.name) ---@as GroupEntry?
	if groupEntry == nil then
		groupEntry = { name = group.name, order = getOrder(group), subgroups = {} }
		table.insert(groups, groupEntry)
	end
	local subgroupEntry = findByName(groupEntry.subgroups, subgroup.name) ---@as SubgroupEntry?
	if subgroupEntry == nil then
		subgroupEntry = { name = subgroup.name, order = getOrder(subgroup), items = {} }
		table.insert(groupEntry.subgroups, subgroupEntry)
	end
	if findByName(subgroupEntry.items, item.name) ~= nil then
		log("Error: item " .. item.name .. " already exists in subgroup " .. subgroup.name)
		return
	end
	table.insert(subgroupEntry.items, itemEntry)
end

-- Add all items to the arrangement.
for _, item in pairs(prototypes.item) do
	addItem(item)
end
-- Could add virtual signals as well. But there's no way to get the signal in player's cursor, or change it. TODO change this if they add the API.
--[[
for _, signal in pairs(prototypes.virtual_signal) do
	addItem(signal)
end
]]

-- Order items the same way as the base game - first by .order, then by .name.
---@param a ItemEntry | SubgroupEntry | GroupEntry
---@param b ItemEntry | SubgroupEntry | GroupEntry
---@return boolean
local function orderThings(a, b)
	return a.order < b.order or (a.order == b.order and a.name < b.name)
end

-- Sort groups, subgroups, and items by order.
table.sort(groups, orderThings)
for _, groupEntry in pairs(groups) do
	table.sort(groupEntry.subgroups, orderThings)
	for _, subgroupEntry in pairs(groupEntry.subgroups) do
		table.sort(subgroupEntry.items, orderThings)
	end
end

-- Handle wrapping in Factoriopedia - split subgroups depending on layout constants.
-- local maxSubgroupLen = data.raw["utility-constants"].default.select_slot_row_count -- This works but it's data-stage, and it's not exposed to runtime Lua.
-- So instead I'll move it in via mod-data prototype. But that's in experimental, so for now I'll smuggle it in somewhere.
-- TODO update this to use mod-data prototype once it's out of experimental.
local maxSubgroupLen = prototypes.item["green-wire"].weight
for _, groupEntry in pairs(groups) do
	local newSubgroups = {}
	for _, subgroupEntry in pairs(groupEntry.subgroups) do
		if #subgroupEntry.items <= maxSubgroupLen then
			table.insert(newSubgroups, subgroupEntry)
		else
			local startNextGroupAt = 1
			local numItems = #subgroupEntry.items
			while numItems > 0 do
				local newSubgroup = { name = subgroupEntry.name, order = subgroupEntry.order, items = {} }
				table.insert(newSubgroups, newSubgroup)
				for i = startNextGroupAt, startNextGroupAt + maxSubgroupLen - 1 do
					table.insert(newSubgroup.items, subgroupEntry.items[i])
				end
				startNextGroupAt = startNextGroupAt + maxSubgroupLen
				numItems = numItems - maxSubgroupLen
			end
		end
	end
	groupEntry.subgroups = newSubgroups
end

-- Add tab left/right links between groups.
for i, groupEntry in pairs(groups) do
	groupEntry.tabLeft = modIndex(groups, i - 1) ---@as NextGroup
	groupEntry.tabRight = modIndex(groups, i + 1) ---@as NextGroup
end

-- Add tab links and up/down links between subgroups.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		-- Tabbing left from a subgroup basically tab-lefts the group, then takes corresponding subgroup from that group.
		subgroupEntry.tabLeft = { x = ceilIndex(groupEntry.tabLeft.x.subgroups, idxSubgroup), wrap = groupEntry.tabLeft.wrap } ---@as NextSubgroup
		subgroupEntry.tabRight = { x = ceilIndex(groupEntry.tabRight.x.subgroups, idxSubgroup), wrap = groupEntry.tabRight.wrap } ---@as NextSubgroup
		-- Going up/down from a subgroup gives the previous/next subgroup in the same group.
		subgroupEntry.up = modIndex(groupEntry.subgroups, idxSubgroup - 1) ---@as NextSubgroup
		subgroupEntry.down = modIndex(groupEntry.subgroups, idxSubgroup + 1) ---@as NextSubgroup
	end
end

-- Populate the links between items: up/down, left/right, tab left/right.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		for idxItem, itemEntry in pairs(subgroupEntry.items) do
			-- Going left/right from an item gives the previous/next item in the same subgroup, wrapping.
			itemEntry.left = modIndex(subgroupEntry.items, idxItem - 1) ---@as NextItem
			itemEntry.right = modIndex(subgroupEntry.items, idxItem + 1) ---@as NextItem
			-- Going up/down from an item gives the corresponding item in the subgroup above/below, with ceiling.
			itemEntry.up = { x = ceilIndex(subgroupEntry.up.x.items, idxItem), wrap = subgroupEntry.up.wrap } ---@as NextItem
			itemEntry.down = { x = ceilIndex(subgroupEntry.down.x.items, idxItem), wrap = subgroupEntry.down.wrap } ---@as NextItem
			-- Going tab-left/right from an item gives the corresponding item in the group's tabLeft/tabRight, with ceiling.
			itemEntry.tabLeft = { x = ceilIndex(ceilIndex(groupEntry.tabLeft.x.subgroups, idxSubgroup).items, idxItem), wrap = groupEntry.tabLeft.wrap } ---@as NextItem
			itemEntry.tabRight = { x = ceilIndex(ceilIndex(groupEntry.tabRight.x.subgroups, idxSubgroup).items, idxItem), wrap = groupEntry.tabRight.wrap } ---@as NextItem
		end
	end
end

---@param nextThing NextItem | NextSubgroup | NextGroup
---@return string | nil
local function transitionUnlessWrapping(nextThing)
	if nextThing.wrap then
		return nil
	else
		return nextThing.x.name
	end
end

-- Populate the transition tables.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		for idxItem, itemEntry in pairs(subgroupEntry.items) do
			TRANSITIONS.LOOPING.UP[itemEntry.name] = itemEntry.up.x.name
			TRANSITIONS.LOOPING.DOWN[itemEntry.name] = itemEntry.down.x.name
			TRANSITIONS.LOOPING.LEFT[itemEntry.name] = itemEntry.left.x.name
			TRANSITIONS.LOOPING.RIGHT[itemEntry.name] = itemEntry.right.x.name
			TRANSITIONS.LOOPING.TAB_LEFT[itemEntry.name] = itemEntry.tabLeft.x.name
			TRANSITIONS.LOOPING.TAB_RIGHT[itemEntry.name] = itemEntry.tabRight.x.name

			TRANSITIONS.NON_LOOPING.UP[itemEntry.name] = transitionUnlessWrapping(itemEntry.up)
			TRANSITIONS.NON_LOOPING.DOWN[itemEntry.name] = transitionUnlessWrapping(itemEntry.down)
			TRANSITIONS.NON_LOOPING.LEFT[itemEntry.name] = transitionUnlessWrapping(itemEntry.left)
			TRANSITIONS.NON_LOOPING.RIGHT[itemEntry.name] = transitionUnlessWrapping(itemEntry.right)
			TRANSITIONS.NON_LOOPING.TAB_LEFT[itemEntry.name] = itemEntry.tabLeft.x.name -- In non-looping mode, we still wrap tabs.
			TRANSITIONS.NON_LOOPING.TAB_RIGHT[itemEntry.name] = itemEntry.tabRight.x.name
		end
	end
end

------------------------------------------------------------------------
-- Return the transition tables.
return TRANSITIONS