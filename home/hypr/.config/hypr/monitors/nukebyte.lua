-- Nukebyte's monitors. hyprland.lua loads this file on the machine whose
-- /etc/hostname is nukebyte.
--
-- Layout, left to right:
--
--   +--------+ +----------------------+ +-------------+
--   | Acer   | | MSI 1440p 180 Hz     | | laptop      |
--   | 1080p  | | main                 | | (lid open   |
--   | 75 Hz  | |                      | |  only)      |
--   | portr. | +----------------------+ +-------------+
--   +--------+
--
-- Run `hyprctl monitors all` to see each monitor's name and description.
-- Rules match by description, so they follow a monitor to whichever port it
-- is plugged into. After editing, apply with: hyprctl reload

-- 22" 1080p turned on its side, on HDMI (AMD iGPU), on the left. Rotated it
-- is 1080 wide and 1920 tall. transform 1 rotates 90 degrees; use 3 if the
-- picture comes out upside down.
hl.monitor({
    output    = "desc:Acer Technologies B227Q",
    mode      = "1920x1080@75",
    position  = "0x0",
    scale     = 1,
    transform = 1,
})

-- 27" 1440p, 180 Hz, on USB-C (NVIDIA GPU): the main monitor, right of the
-- portrait one and centred on it vertically ((1920 - 1440) / 2 = 240).
hl.monitor({
    output   = "desc:Microstep MSI G274QPF E2",
    mode     = "2560x1440@180",
    position = "1080x240",
    scale    = 1,
})

-- The laptop's own panel: right of the main monitor while the lid is open,
-- off while it is closed.
local function lidClosed()
    for _, path in ipairs({
        "/proc/acpi/button/lid/LID0/state",
        "/proc/acpi/button/lid/LID/state",
    }) do
        local f = io.open(path)
        if f then
            local state = f:read("a")
            f:close()
            return state:find("closed", 1, true) ~= nil
        end
    end
    return false
end

local function laptopPanel(enabled)
    if enabled then
        hl.monitor({
            output   = "eDP-1",
            mode     = "preferred",
            position = "3640x240",
            scale    = 1,
        })
    else
        hl.monitor({ output = "eDP-1", disabled = true })
    end
end

-- At login and on every reload, match the lid as it is now.
laptopPanel(not lidClosed())

-- Then follow it: closing the lid turns the panel off, opening turns it on.
-- `locked` keeps these working while the screen is locked.
hl.bind("switch:on:Lid Switch",  function() laptopPanel(false) end, { locked = true })
hl.bind("switch:off:Lid Switch", function() laptopPanel(true) end,  { locked = true })
