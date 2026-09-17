# KDE configuration inventory

KDE and Qt applications share several settings files. Portable preferences stay
in `home/kde/`. Files tied to nukebyte's hardware or desktop layout live in
`hosts/nukebyte/`.

## Shared KDE files

- `kdeglobals`: colors, icons, style, and file-dialog behavior.
- `dolphinrc`: Dolphin view and window preferences.
- `kglobalshortcutsrc`: Plasma and application global shortcuts.
- `mimeapps.list`: default browser and URL handlers.
- `plasma-localerc`: locale preferences.
- `spectaclerc`: Spectacle annotation and save-folder preferences.
- `plasma-systemmonitor/memory.page`: memory views.
- `plasma-systemmonitor/pressure.page`: CPU, memory, and I/O pressure views.
- `plasma-systemmonitor/processes-admin.page`: the administrator process view.

Recent paths, window geometry, generated desktop-file identifiers, and other
application state are not tracked.

## Nukebyte files

- `kwinoutputconfig.json`: display identities and layout.
- `plasma-org.kde.plasma.desktop-appletsrc`: panels, widgets, and desktop layout.
- `plasmashellrc`: Plasma shell state for that layout.
- `powermanagementprofilesrc`: laptop power settings.
- `kcminputrc`: settings for nukebyte's mouse.
- `kwinrc`: KWin tiling tied to nukebyte's displays.
- `systemmonitorrc` and the other `plasma-systemmonitor/*.page` files: navigation
  and views tied to nukebyte's CPU, GPUs, disks, sensors, and network interface.

These paths mirror their locations below `$HOME`. `dots link` includes them only
when the active hostname is `nukebyte`.
