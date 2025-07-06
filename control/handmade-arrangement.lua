-- This file creates the "handmade arrangement" of items.

------------------------------------------------------------------------
-- Tools to build a table of transitions between items.
------------------------------------------------------------------------

-- These hold the item names we transition between when the hotkeys are pressed.
local UP = {} ---@type KeyTransitionTable
local DOWN = {} ---@type KeyTransitionTable
local LEFT = {} ---@type KeyTransitionTable
local RIGHT = {} ---@type KeyTransitionTable

local function addUpperLower(a, b, override)
	if (not override) and (DOWN[a] ~= nil or UP[b] ~= nil) then
		log("Error: tried to create upper-lower relation between " .. a .. " and " .. b .. " but already have: " .. (UP[b] or "nil") .. " and " .. (DOWN[a] or "nil"))
		return
	end
	DOWN[a] = b
	UP[b] = a
end
local function addLeftRight(a, b, override)
	if (not override) and (RIGHT[a] ~= nil or LEFT[b] ~= nil) then
		log("Error: tried to create left/right relation between " .. a .. " and " .. b .. " but already have: " .. (LEFT[b] or "nil") .. " and " .. (RIGHT[a] or "nil"))
		return
	end
	RIGHT[a] = b
	LEFT[b] = a
end

local function addUpwardChain(l, override)
	if #l < 2 then
		log("Error: tried to create upward chain with only one item: " .. serpent.line(l))
		return
	end
	for i = 1, #l - 1 do
		addUpperLower(l[i+1], l[i], override)
	end
	addUpperLower(l[1], l[#l], override)
end

local function addRightwardChain(l, override)
	if #l < 2 then
		log("Error: tried to create rightward chain with only one item: " .. serpent.line(l))
		return
	end
	for i = 1, #l - 1 do
		addLeftRight(l[i], l[i + 1], override)
	end
	addLeftRight(l[#l], l[1], override)
end

local function addGrid(g)
	-- Adds a grid of items, assuming each row the same length.
	local len = #g[1]
	for i = 2, #g do
		if #g[i] ~= len then
			log("Error: tried to create grid with unequal rows: " .. serpent.line(g))
			return
		end
	end
	if len >= 2 then
		for i = 1, #g do
			addRightwardChain(g[i])
		end
	end
	-- Create columns
	if #g >= 2 then
		for i = 1, len do
			local col = {}
			for j = #g, 1, -1 do
				col[#col+1] = g[j][i]
			end
			addUpwardChain(col)
		end
	end
end

------------------------------------------------------------------------
--- Build transition tables, as grids and lines.
------------------------------------------------------------------------

-- Belts, splitters, undergrounds.
addGrid{
	{ "turbo-transport-belt", "turbo-underground-belt", "turbo-splitter" },
	{ "express-transport-belt", "express-underground-belt", "express-splitter" },
	{ "fast-transport-belt", "fast-underground-belt", "fast-splitter" },
	{ "transport-belt", "underground-belt", "splitter" },
}

-- Circuits
addUpwardChain{"electronic-circuit", "advanced-circuit", "processing-unit", "quantum-processor"}

-- Rocket parts
addRightwardChain{"low-density-structure", "rocket-fuel", "processing-unit"}
DOWN["low-density-structure"] = "steel-plate"

-- Power poles
addUpwardChain{"small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation"}
RIGHT["small-electric-pole"] = "substation"
LEFT["small-electric-pole"] = "substation"
RIGHT["medium-electric-pole"] = "substation"
LEFT["medium-electric-pole"] = "substation"
addRightwardChain{"substation", "big-electric-pole"}

-- Chests and logistic chests
local chests = {"wooden-chest", "iron-chest", "steel-chest"}
local logisticChests = {"active-provider-chest", "passive-provider-chest", "storage-chest", "buffer-chest", "requester-chest"}
addUpwardChain(chests)
addRightwardChain(logisticChests)
for _, chest in pairs(chests) do
	RIGHT[chest] = "passive-provider-chest"
end
for _, logChest in pairs(logisticChests) do
	DOWN[logChest] = "steel-chest"
end
UP["steel-chest"] = "passive-provider-chest"
UP["passive-provider-chest"] = "active-provider-chest"
UP["active-provider-chest"] = "steel-chest"

addRightwardChain{"storage-tank", "pump", "offshore-pump"}
addRightwardChain{"pipe", "pipe-to-ground"}
addUpwardChain{"pipe", "storage-tank"}
addUpwardChain{"pipe-to-ground", "pump"}

addRightwardChain {"locomotive", "cargo-wagon", "fluid-wagon"}

addRightwardChain{"rail-signal", "rail-chain-signal"}
UP["rail-signal"] = "train-stop"
UP["rail-chain-signal"] = "train-stop"
DOWN["train-stop"] = "rail-signal"

addRightwardChain{"rail", "rail-ramp", "rail-support"}
addUpwardChain{"rail", "rail-support", "locomotive"}
DOWN["cargo-wagon"] = "rail-support"
DOWN["fluid-wagon"] = "rail-support"

-- Inserters
local inserterUpwardChain = {"burner-inserter", "inserter", "fast-inserter", "bulk-inserter", "stack-inserter"}
addUpwardChain(inserterUpwardChain)
for _, inserter in pairs(inserterUpwardChain) do
	RIGHT[inserter] = "long-handed-inserter"
	LEFT[inserter] = "long-handed-inserter"
end
RIGHT["long-handed-inserter"] = "fast-inserter"
LEFT["long-handed-inserter"] = "fast-inserter"

addRightwardChain{"boiler", "steam-engine"}
addRightwardChain{"heat-pipe", "heat-exchanger", "steam-turbine"}

addUpwardChain{"lab", "biolab"}
addRightwardChain{"lab", "biolab"}

addGrid{
	{"big-mining-drill", "electric-furnace", "assembling-machine-3"},
	{"electric-mining-drill", "steel-furnace", "assembling-machine-2"},
	{"burner-mining-drill", "stone-furnace", "assembling-machine-1"},
}

addRightwardChain({"assembling-machine-3", "foundry", "biochamber", "electromagnetic-plant", "cryogenic-plant"}, true)
DOWN["foundry"] = "electric-furnace"
LEFT["assembling-machine-3"] = "electric-furnace"

addRightwardChain{"chemical-plant", "oil-refinery"}
addUpwardChain{"chemical-plant", "biochamber", "cryogenic-plant"}

addUpwardChain{"stone", "stone-brick", "concrete", "refined-concrete"}
addRightwardChain{"concrete", "hazard-concrete"}
addRightwardChain{"refined-concrete", "refined-hazard-concrete"}
addUpwardChain{"hazard-concrete", "refined-hazard-concrete"}

addRightwardChain{"explosives", "cliff-explosives"}

addGrid{
	{"overgrowth-yumako-soil", "overgrowth-jellynut-soil"},
	{"artificial-yumako-soil", "artificial-jellynut-soil"},
}
addGrid{
	{"yumako-mash", "jelly", "nutrients"},
	{"yumako", "jellynut", "bioflux"},
	{"yumako-seed", "jellynut-seed", "spoilage"},
}

addUpwardChain{"car", "tank", "spidertron"}

addUpwardChain{"copper-ore", "copper-plate", "copper-cable"}
addUpwardChain{"iron-ore", "iron-plate", "steel-plate"}
addRightwardChain{"steel-plate", "tungsten-plate"}
addUpwardChain{"tungsten-ore", "tungsten-carbide", "tungsten-plate"}
addRightwardChain{"tungsten-ore", "calcite"}
addUpwardChain{"coal", "carbon", "carbon-fiber"}
addRightwardChain{"wood", "coal", "solid-fuel"}
addRightwardChain{"iron-ore", "copper-ore"}
addRightwardChain{"iron-bacteria", "copper-bacteria"}
UP["iron-bacteria"] = "iron-ore"
UP["copper-bacteria"] = "copper-ore"
addRightwardChain{"iron-plate", "copper-plate"}
addRightwardChain{"iron-gear-wheel", "iron-stick", "copper-cable"}
DOWN["iron-stick"] = "iron-plate"
addUpwardChain{"holmium-ore", "holmium-plate"}
addRightwardChain{"scrap", "holmium-ore"}
addUpwardChain{"scrap", "recycler"}
addUpwardChain{"lithium", "lithium-plate"}

addUpwardChain{"automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack", "space-science-pack", "metallurgic-science-pack", "agricultural-science-pack", "electromagnetic-science-pack", "cryogenic-science-pack", "promethium-science-pack"}
addRightwardChain{"metallurgic-science-pack", "agricultural-science-pack", "electromagnetic-science-pack"}

addUpwardChain{"solid-fuel", "rocket-fuel", "nuclear-fuel"}
LEFT["nuclear-fuel"] = "uranium-fuel-cell"
RIGHT["nuclear-fuel"] = "uranium-fuel-cell"

addRightwardChain{"solar-panel", "accumulator"}

addUpwardChain{"uranium-ore", "uranium-235", "uranium-fuel-cell", "fusion-power-cell"}
addUpperLower("depleted-uranium-fuel-cell", "uranium-238")
DOWN["uranium-238"] = "uranium-ore"
UP["depleted-uranium-fuel-cell"] = "fusion-power-cell"
addRightwardChain{"uranium-fuel-cell", "depleted-uranium-fuel-cell"}
addRightwardChain{"uranium-235", "uranium-238"}

addRightwardChain{"metallic-asteroid-chunk", "carbonic-asteroid-chunk", "oxide-asteroid-chunk", "promethium-asteroid-chunk"}
UP["metallic-asteroid-chunk"] = "iron-ore"
DOWN["metallic-asteroid-chunk"] = "iron-ore"
UP["carbonic-asteroid-chunk"] = "carbon"
DOWN["carbonic-asteroid-chunk"] = "carbon"
UP["oxide-asteroid-chunk"] = "ice"
DOWN["oxide-asteroid-chunk"] = "ice"

addRightwardChain{"asteroid-collector", "crusher"}

addUpwardChain{"iron-gear-wheel", "engine-unit", "electric-engine-unit"}
DOWN["iron-gear-wheel"] = "iron-plate"
addRightwardChain{"engine-unit", "electric-engine-unit", "flying-robot-frame"}
addUpwardChain{"flying-robot-frame", "logistic-robot", "roboport"}
addRightwardChain{"roboport", "radar"}
UP["construction-robot"] = "roboport"
DOWN["construction-robot"] = "flying-robot-frame"
addRightwardChain{"logistic-robot", "construction-robot"}

addRightwardChain{"plastic-bar", "sulfur", "battery"}
DOWN["plastic-bar"] = "coal"
UP["plastic-bar"] = "advanced-circuit"
addUpwardChain{"sulfur", "explosives"}

addRightwardChain{"superconductor", "supercapacitor"}
addUpwardChain{"superconductor", "supercapacitor"}

addRightwardChain{"pentapod-egg", "biter-egg"}

addRightwardChain{"red-wire", "green-wire", "copper-wire"}
local combinators = {"arithmetic-combinator", "decider-combinator", "selector-combinator", "constant-combinator", "power-switch", "programmable-speaker", "display-panel", "small-lamp"}
addRightwardChain(combinators) -- in order that they're in in the crafting menu.
for _, c in pairs(combinators) do
	DOWN[c] = "red-wire"
end
UP["red-wire"] = "constant-combinator"
UP["green-wire"] = "constant-combinator"
UP["small-lamp"] = "constant-combinator"
UP["constant-combinator"] = "arithmetic-combinator"
UP["arithmetic-combinator"] = "decider-combinator"
UP["decider-combinator"] = "selector-combinator"
UP["selector-combinator"] = "display-panel"
UP["display-panel"] = "small-lamp"
DOWN["power-switch"] = "copper-wire"
UP["copper-wire"] = "power-switch"

addUpwardChain{"lightning-rod", "lightning-collector"}

addGrid{
	{"speed-module-3", "efficiency-module-3", "productivity-module-3", "quality-module-3"},
	{"speed-module-2", "efficiency-module-2", "productivity-module-2", "quality-module-2"},
	{"speed-module", "efficiency-module", "productivity-module", "quality-module"},
}

addGrid{
	{"submachine-gun", "combat-shotgun"},
	{"pistol", "shotgun"},
}

addUpwardChain{"shotgun-shell", "piercing-shotgun-shell"}
addGrid{
	{"uranium-cannon-shell", "explosive-uranium-cannon-shell"},
	{"cannon-shell", "explosive-cannon-shell"},
}
addUpwardChain{"grenade", "cluster-grenade"}
addRightwardChain{"slowdown-capsule", "poison-capsule"}
addUpwardChain{"defender-capsule", "distractor-capsule", "destroyer-capsule"}
addUpwardChain{"light-armor", "heavy-armor", "modular-armor", "power-armor", "power-armor-mk2", "mech-armor"}
addUpwardChain{"fission-reactor-equipment", "fusion-reactor-equipment"}
addUpwardChain{"battery-equipment", "battery-mk2-equipment", "battery-mk3-equipment"}
addUpwardChain{"personal-roboport-equipment", "personal-roboport-mk2-equipment"}
addUpwardChain{"energy-shield-equipment", "energy-shield-mk2-equipment"}

addRightwardChain{"stone-wall", "gate"}

addUpwardChain{"landfill", "foundation"}
addRightwardChain{"landfill", "foundation"}

addRightwardChain{"fusion-reactor", "fusion-generator", "fusion-power-cell"}

addRightwardChain{"spidertron", "spidertron-remote"}
UP["raw-fish"] = "spidertron"

addUpwardChain{"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"}
addUpwardChain{"rocket", "explosive-rocket", "atomic-bomb"}

addUpwardChain{"gun-turret", "laser-turret", "flamethrower-turret", "artillery-turret", "rocket-turret", "tesla-turret", "railgun-turret"}
addRightwardChain{"firearm-magazine", "gun-turret"}
RIGHT["piercing-rounds-magazine"] = "gun-turret"
LEFT["piercing-rounds-magazine"] = "gun-turret"
RIGHT["uranium-rounds-magazine"] = "gun-turret"
LEFT["uranium-rounds-magazine"] = "gun-turret"
addRightwardChain{"artillery-shell", "artillery-turret"}
addRightwardChain{"rocket", "rocket-turret", "rocket-launcher"}
RIGHT["explosive-rocket"] = "rocket-turret"
LEFT["explosive-rocket"] = "rocket-turret"
RIGHT["atomic-bomb"] = "rocket-turret"
LEFT["atomic-bomb"] = "rocket-turret"
addRightwardChain{"railgun-ammo", "railgun-turret", "railgun"}
addRightwardChain{"flamethrower-ammo", "flamethrower-turret", "flamethrower"}
addRightwardChain{"tesla-ammo", "teslagun"}

------------------------------------------------------------------------

--[[ For debugging - checks whether items exist. Disabling to not spam logfile when playing without Space Age.
for _, transitionDict in pairs{UP, DOWN, LEFT, RIGHT} do
	for first, second in pairs(transitionDict) do
		if prototypes.item[first] == nil then
			log("Error: tried to create transition between non-existent item: " .. first .. " (to " .. second .. ")")
		end
		if prototypes.item[second] == nil then
			log("Error: tried to create transition between non-existent item: " .. second .. " (from " .. first .. ")")
		end
	end
end
]]

-- Return the transition table.
---@type TransitionTable
return {
	UP = UP,
	DOWN = DOWN,
	LEFT = LEFT,
	RIGHT = RIGHT,
	TAB_LEFT = {},
	TAB_RIGHT = {},
}