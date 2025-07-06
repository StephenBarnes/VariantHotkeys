data:extend{
    {
        order = "a",
        name = "VariantHotkeys-mode",
        type = "string-setting",
        setting_type = "runtime-per-user",
		allowed_values = {"factoriopedia-looping", "factoriopedia-non-looping", "handmade"},
        default_value = "factoriopedia-looping",
    },
    {
        order = "b",
        name = "VariantHotkeys-switch-message",
        type = "bool-setting",
        setting_type = "runtime-per-user",
        default_value = false,
    },
}