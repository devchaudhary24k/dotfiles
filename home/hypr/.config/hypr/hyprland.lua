-- Hyprland configuration.
--
-- Hyprland 0.55 reads Lua. The API reference is the stub file shipped with
-- Hyprland (share/hypr/stubs/hl.meta.lua) and https://wiki.hypr.land.
-- Config errors show up as a red banner at the top of the screen.
--
-- Reload after a change with: hyprctl reload

local terminal    = "uwsm app -- ghostty"
local fileManager = "uwsm app -- thunar"
local browser     = "uwsm app -- firefox"
local menu        = "fuzzel --launch-prefix='uwsm app -- '"
local mainMod     = "SUPER"

------------------------------------------------------------------------------
-- Monitors
--
-- Any monitor without its own rule gets its highest refresh rate and is
-- placed automatically. A machine's own layout is in monitors/<hostname>.lua;
-- carbon-nix links it to monitors.lua, which is loaded here when present.
------------------------------------------------------------------------------

hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1,
})

local ok, err = pcall(require, "monitors")
if not ok and not tostring(err):find("module 'monitors' not found", 1, true) then
    error(err)
end

------------------------------------------------------------------------------
-- Autostart
------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd("uwsm app -- swaync")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("uwsm app -- wl-paste --watch cliphist store")
end)

------------------------------------------------------------------------------
-- Look and feel
------------------------------------------------------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding = 8,
        shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
        blur   = { enabled = true, size = 3, passes = 1 },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    -- On a hybrid laptop, a monitor driven by the NVIDIA GPU flickers or
    -- loses the hardware cursor. The software cursor costs nothing noticeable.
    cursor = { no_hardware_cursors = true },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad     = { natural_scroll = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------------------------------------------------------
-- Keys
------------------------------------------------------------------------------

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))

-- Session
hl.bind(mainMod .. " + Escape",         hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("uwsm stop"))
hl.bind(mainMod .. " + N",              hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Clipboard history and screenshots
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind("Print",                   hl.dsp.exec_cmd("grimblast --notify copysave area"))
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("grimblast --notify copysave output"))

-- Focus with arrows or h/j/k/l
for key, direction in pairs({
    left = "left", right = "right", up = "up", down = "down",
    h = "left", l = "right", k = "up", j = "down",
}) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }))
end

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse: drag with SUPER + left button, resize with SUPER + right button
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"),                          { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),                          { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })

------------------------------------------------------------------------------
-- Window rules
------------------------------------------------------------------------------

-- Small utility windows float instead of tiling.
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$" },
    float = true,
})
