data:extend({
	{
		type = "custom-input",
		name = "VariantHotkeys-up",
		key_sequence = "SHIFT + mouse-wheel-up",
		alternative_key_sequence = "SHIFT + W",
		order = "a",
	},
	{
		type = "custom-input",
		name = "VariantHotkeys-down",
		key_sequence = "SHIFT + mouse-wheel-down",
		alternative_key_sequence = "SHIFT + S",
		order = "b",
	},
	{
		type = "custom-input",
		name = "VariantHotkeys-left",
		key_sequence = "CONTROL + mouse-wheel-down",
		alternative_key_sequence = "SHIFT + A",
		order = "c",
	},
	{
		type = "custom-input",
		name = "VariantHotkeys-right",
		key_sequence = "CONTROL + mouse-wheel-up",
		alternative_key_sequence = "SHIFT + D",
		order = "d",
	},
	{
		type = "custom-input",
		name = "VariantHotkeys-tab-left",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-down",
		alternative_key_sequence = "CONTROL + SHIFT + A",
		order = "e",
	},
	{
		type = "custom-input",
		name = "VariantHotkeys-tab-right",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-up",
		alternative_key_sequence = "CONTROL + SHIFT + D",
		order = "f",
	},
})

-- I want to move in max subgroup length as a mod-data prototype, but mod-data is in experimental. So instead for now I'm smuggling it in here.
-- TODO change once mod-data is out of experimental.
data.raw.item["green-wire"].weight = data.raw["utility-constants"].default.select_slot_row_count