# KDE configuration inventory

These files are retained intentionally. KDE and Qt applications share several
of them, so a file that looks unimportant may still affect the entire desktop.

## Portable KDE package

- `kdeglobals`: shared colors, icon/style choices, fonts, and file-dialog
  behavior. Removing it can produce a dark shell with light application views.
- `dolphinrc`: Dolphin behavior and view preferences.
- `kglobalshortcutsrc`: Plasma and application global shortcuts.
- `kwinrc`: KWin behavior and tiling state.
- `kcminputrc`: cursor and pointer settings currently used by this laptop.
- `mimeapps.list`: default browser and URL-handler associations.
- `plasma-localerc`: locale preferences.
- `plasmanotifyrc`: Plasma notification preferences.
- `spectaclerc`: Spectacle capture preferences and application state.
- `konsolerc`: Konsole integration preferences.
- `systemmonitorrc` plus `plasma-systemmonitor/*.page`: the customized System
  Monitor sidebar, overview, CPU, memory, GPU, thermal, storage, network,
  pressure, process, and system pages.

## `nukebyte` host package

- `kwinoutputconfig.json`: physical display identities, positions, rotation,
  resolution, and refresh rates.
- `plasma-org.kde.plasma.desktop-appletsrc`: panels, launchers, widgets, and
  desktop containment layout.
- `plasmashellrc`: Plasma shell state associated with that layout.
- `powermanagementprofilesrc`: laptop power-profile choices.

## Safe cleanup rule

Do not unlink or delete one of these from the running desktop as a cleanup
experiment. Copy the full KDE package into a disposable user account, remove
one candidate there, log out and back in, and test Plasma plus KDE apps. Only a
verified removal should be made in this repository. Caches, logs, histories,
crash reports, and window-session data outside this explicit inventory remain
untracked.
