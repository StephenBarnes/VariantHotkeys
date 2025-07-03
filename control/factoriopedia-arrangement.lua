-- This file creates the "Factoriopedia arrangement" of items. This is done in control stage, not data-final-fixes, so it runs after we're guaranteed all protos have been created.

-- These hold the item names we transition between when the hotkeys are pressed.
local UP = {} ---@type { string: string }
local DOWN = {} ---@type { string: string }
local LEFT = {} ---@type { string: string }
local RIGHT = {} ---@type { string: string }
local TAB_LEFT = {} ---@type { string: string }
local TAB_RIGHT = {} ---@type { string: string }

------------------------------------------------------------------------
--- Build tables.
------------------------------------------------------------------------

local items = prototypes.item
---@alias ItemEntry { name: string, order: string, left: ItemEntry, right: ItemEntry, up: ItemEntry, down: ItemEntry, tabLeft: ItemEntry, tabRight: ItemEntry }
---@alias SubgroupEntry { name: string, order: string, items: ItemEntry[], up: SubgroupEntry, down: SubgroupEntry, tabLeft: SubgroupEntry, tabRight: SubgroupEntry }
---@alias GroupEntry { name: string, order: string, subgroups: SubgroupEntry[], tabRight: GroupEntry, tabLeft: GroupEntry }
local groups = {} ---@type GroupEntry[]

-- Function to find an entry by name in a table.
---@param table GroupEntry[] | SubgroupEntry[] | ItemEntry[]
---@param name string
---@return GroupEntry | SubgroupEntry | ItemEntry | nil
local function findByName(table, name)
	for _, entry in pairs(table) do
		if entry.name == name then return entry end
	end
	return nil
end

-- Function to get entry in a table by index, wrapping around if necessary.
---@generic T
---@param table T[]
---@param index number
---@return T
local function modIndex(table, index)
	return table[(index - 1) % #table + 1]
end

-- Function to get the index of an entry in a table, but if index is above max, then return the last entry.
---@generic T
---@param table T[]
---@param index number
---@return T
local function ceilIndex(table, index)
	return table[math.min(index, #table)]
end

-- Function to get the order of an item, subgroup, or group.
---@param x LuaItemPrototype | LuaGroup
---@return string
local function getOrder(x)
	if x.order ~= nil then return x.order end
	for _, key in pairs{"place_result", "place_as_equipment_result", "place_as_tile_result"} do
		if x[key] ~= nil and x[key].order ~= nil then return x[key].order end
	end
	log("Error: item/group " .. x.name .. " has no order") -- TODO check if this generates any errors with default Spage etc.
	return ""
end

-- TODO ignore hidden tabs and subgroups.

-- Function to add an item to the arrangement, creating groups and subgroups as needed.
---@param item LuaItemPrototype
---@return nil
local function addItem(item)
	if item.hidden or item.hidden_in_factoriopedia then return end

	local order = getOrder(item)
	local itemEntry = { name = item.name, order = order }

	local subgroup = item.subgroup
	if subgroup == nil then
		log("Error: item " .. item.name .. " has no subgroup") -- TODO check
		return
	end
	local group = subgroup.group
	if group == nil then
		log("Error: item " .. item.name .. " in subgroup " .. subgroup.name .. " has no group") -- TODO check
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
		log("Error: item " .. item.name .. " already exists in subgroup " .. subgroup.name) -- TODO check
		return
	end
	table.insert(subgroupEntry.items, itemEntry)
end

-- Add all items to the arrangement.
for _, item in pairs(items) do
	addItem(item)
end

-- Sort groups, subgroups, and items by order.
table.sort(groups, function(a, b) return a.order < b.order end)
for _, groupEntry in pairs(groups) do
	table.sort(groupEntry.subgroups, function(a, b) return a.order < b.order end)
	for _, subgroupEntry in pairs(groupEntry.subgroups) do
		table.sort(subgroupEntry.items, function(a, b) return a.order < b.order end)
	end
end

-- Add tab left/right links between groups.
for i, groupEntry in pairs(groups) do
	groupEntry.tabLeft = modIndex(groups, i - 1) ---@as GroupEntry
	groupEntry.tabRight = modIndex(groups, i + 1) ---@as GroupEntry
end

-- Add tab links and up/down links between subgroups.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		-- Tabbing left from a subgroup basically tab-lefts the group, then takes corresponding subgroup from that group.
		subgroupEntry.tabLeft = ceilIndex(groupEntry.tabLeft.subgroups, idxSubgroup) ---@as SubgroupEntry
		subgroupEntry.tabRight = ceilIndex(groupEntry.tabRight.subgroups, idxSubgroup) ---@as SubgroupEntry
		-- Going up/down from a subgroup gives the previous/next subgroup in the same group.
		subgroupEntry.up = modIndex(groupEntry.subgroups, idxSubgroup - 1) ---@as SubgroupEntry
		subgroupEntry.down = modIndex(groupEntry.subgroups, idxSubgroup + 1) ---@as SubgroupEntry
	end
end

-- Add all links between items: up/down, left/right, tab left/right.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		for idxItem, itemEntry in pairs(subgroupEntry.items) do
			-- Going left/right from an item gives the previous/next item in the same subgroup, wrapping.
			itemEntry.left = modIndex(subgroupEntry.items, idxItem - 1) ---@as ItemEntry
			itemEntry.right = modIndex(subgroupEntry.items, idxItem + 1) ---@as ItemEntry
			-- Going up/down from an item gives the corresponding item in the subgroup above/below, with ceiling.
			itemEntry.up = ceilIndex(subgroupEntry.up.items, idxItem) ---@as ItemEntry
			itemEntry.down = ceilIndex(subgroupEntry.down.items, idxItem) ---@as ItemEntry
			-- Going tab-left/right from an item gives the corresponding item in the group's tabLeft/tabRight, with ceiling.
			itemEntry.tabLeft = ceilIndex(ceilIndex(groupEntry.tabLeft.subgroups, idxSubgroup).items, idxItem) ---@as ItemEntry
			itemEntry.tabRight = ceilIndex(ceilIndex(groupEntry.tabRight.subgroups, idxSubgroup).items, idxItem) ---@as ItemEntry
		end
	end
end

-- Populate the transition tables.
for idxGroup, groupEntry in pairs(groups) do
	for idxSubgroup, subgroupEntry in pairs(groupEntry.subgroups) do
		for idxItem, itemEntry in pairs(subgroupEntry.items) do
			UP[itemEntry.name] = itemEntry.up.name
			DOWN[itemEntry.name] = itemEntry.down.name
			LEFT[itemEntry.name] = itemEntry.left.name
			RIGHT[itemEntry.name] = itemEntry.right.name
			TAB_LEFT[itemEntry.name] = itemEntry.tabLeft.name
			TAB_RIGHT[itemEntry.name] = itemEntry.tabRight.name
		end
	end
end

------------------------------------------------------------------------
-- Return the transition tables.
return {
	UP = UP,
	DOWN = DOWN,
	LEFT = LEFT,
	RIGHT = RIGHT,
	TAB_LEFT = TAB_LEFT,
	TAB_RIGHT = TAB_RIGHT,
}