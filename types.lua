-- This file contains types for FMTK / Lua LSP.

---@alias KeyTransitionTable { [string]: string }
---@alias Key "UP" | "DOWN" | "LEFT" | "RIGHT" | "TAB_LEFT" | "TAB_RIGHT"
---@alias TransitionTable { [Key]: KeyTransitionTable }