-- Nukebyte's monitors. carbon-nix links this file to ~/.config/hypr/monitors.lua
-- on nukebyte, and hyprland.lua loads it from there.
--
-- Run `hyprctl monitors` to see each monitor's description. Rules match by
-- description, so they follow a monitor to whichever port it is plugged into.

-- 27" 1440p, 180 Hz, on USB-C (driven by the NVIDIA GPU).
hl.monitor({
    output   = "desc:Microstep MSI G274QPF E2",
    mode     = "2560x1440@180",
    position = "0x0",
    scale    = 1,
})

-- 22" 1080p turned on its side, on HDMI (driven by the AMD iGPU), to the
-- right of the main monitor. transform 1 rotates 90 degrees; use 3 if it
-- comes out upside down.
hl.monitor({
    output    = "desc:Acer Technologies B227Q",
    mode      = "1920x1080@75",
    position  = "2560x0",
    scale     = 1,
    transform = 1,
})

-- The laptop's own panel, left of the main monitor when the lid is open.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto-left",
    scale    = 1,
})
