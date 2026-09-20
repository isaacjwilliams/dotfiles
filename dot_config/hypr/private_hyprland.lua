-- Hyprland config.
--
-- Almost everything lives in hyprland-gui.lua, which HyprMod owns and
-- rewrites wholesale on every save. Only the handful of things HyprMod
-- cannot round-trip belong in this file:
--
--   * spring curves        -- HyprMod has no spring emitter
--   * binds calling Lua    -- it reads them as empty binds
--   * gestures             -- it has no gesture page
--
-- Keep require("hyprland-gui") last: later values win.


-- Animations --------------------------------------------------------------

hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("easy",  { type = "spring", mass = 1, stiffness = 500, dampening = 35 })

hl.animation({ leaf = "global",              enabled = true, speed = 3, bezier = "quick" })
hl.animation({ leaf = "windows",             enabled = true, speed = 3, spring = "easy",  style = "slide" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 5, bezier = "quick", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2, bezier = "quick", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "quick", style = "slide bottom" })


-- Touchpad gestures -------------------------------------------------------

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })


-- Binds HyprMod reads incorrectly -----------------------------------------

-- Maximize. HyprMod drops the mode and reads it as plain fullscreen.
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = 1 }))

-- Cursor zoom, clamped to 1.0x - 3.0x.
local function zoom(delta)
    local factor = hl.get_config("cursor:zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, factor)) } })
end

hl.bind("SUPER + Minus",       function() zoom(-0.3) end, { repeating = true })
hl.bind("SUPER + Plus",        function() zoom(0.3)  end, { repeating = true })
hl.bind("SUPER + KP_Subtract", function() zoom(-0.3) end, { repeating = true })
hl.bind("SUPER + KP_Add",      function() zoom(0.3)  end, { repeating = true })


-- Special workspaces ------------------------------------------------------

-- Drop the scratchpad (SUPER+S) when switching workspaces, instead of having
-- it ride along over whatever workspace comes next. HyprMod's Keybinds page
-- covers binds themselves, not the binds:* config section, so this has no
-- home over there.

hl.config({
    binds = {
        hide_special_on_workspace_change = true,
    },
})


-- Group bar ---------------------------------------------------------------

-- HyprMod has no groupbar page, so the tab strip would otherwise run on
-- Hyprland's defaults: 14px tall, 8pt text.
--
-- Colors are deliberately absent: Noctalia's built-in hyprland template
-- (enabled in its settings, rendered to noctalia.lua) owns every group and
-- groupbar color, plus general.col. Its require() runs last in this file, so
-- it wins over both HyprMod and anything set here. Geometry and weight are
-- left alone by that template, which is why they live here.

hl.config({
    group = {
        groupbar = {
            height = 24,
            font_size = 12,
            indicator_height = 4,
            text_offset = -1,
            font_weight_active = "bold",
            font_weight_inactive = "medium",
            gaps_in = 3,
            gaps_out = 3,
        },
    },
})


-- Group binds. SUPER+W (toggle group) lives in hyprland-gui.lua, as do the tab
-- cycling keys; these are the ops HyprMod's grouping page can express but I
-- have not bound there.
--
-- Note the table arguments: these dispatchers read their direction out of a
-- table field, and silently fall back to the default when handed a bare value.

hl.bind("SUPER + CTRL + W",  hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + ALT + W",   hl.dsp.group.lock_active({ action = "toggle" }))
hl.bind("SUPER + SHIFT + H", hl.dsp.group.move_window({ forward = false }))
hl.bind("SUPER + SHIFT + L", hl.dsp.group.move_window({ forward = true }))


-- HyprMod-managed settings ------------------------------------------------

require("hyprland-gui")


-- Machine-local monitor layout --------------------------------------------

-- HyprMod rewrites hyprland-gui.lua wholesale, monitor block included, so the
-- outputs of whichever machine last saved travel with the dotfiles. monitors.lua
-- is generated per machine by ~/.local/bin/hypr-monitors, is chezmoi-ignored,
-- and loads after HyprMod's block -- later values win, so it is the one that
-- decides. pcall so a missing file degrades to HyprMod's layout instead of
-- taking the whole config down.

pcall(require, "monitors")


-- Noctalia color templates ---------------------------------------------------
-- noctalia.lua is generated by Noctalia from ~/.config/noctalia/config.toml and
-- is chezmoi-ignored, so on a machine where Noctalia has not run yet the file
-- simply does not exist. An unguarded require() there fails the *whole* config
-- with "module 'noctalia' not found" and the session comes up with no config at
-- all. Guard it: unthemed-but-working beats broken, and the colors arrive on the
-- next reload once Noctalia has written the file.
--
-- The require below is wrapped in a function rather than passed to pcall as
-- `pcall(require, "noctalia")`, and that is load-bearing. Noctalia's own apply
-- hook greps this file for the literal string require("noctalia") and appends
-- an unguarded call of its own whenever it does not find one -- which it did,
-- on every palette render, undoing this guard. Wrapping keeps that exact string
-- present in real code while pcall still catches the missing module.
local ok, noctalia = pcall(function()
    return require("noctalia")
end)
if ok and type(noctalia) == "table" and type(noctalia.apply_theme) == "function" then
    noctalia.apply_theme()
end
