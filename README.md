# Dotfiles

User configuration for nukebyte, an Arch Linux laptop running KDE Plasma. It
does not track package lists, root-owned system files, application snapshots,
credentials, histories, caches, or backups.

Every package is linked into the home directory with GNU Stow by `bin/dots`.
The links point back into this repository, so editing `~/.config/fish/...` or
`~/.gitconfig` edits the tracked file directly.

## Layout

```text
home/                 shared user configuration
hosts/HOSTNAME/       configuration for one machine
bin/dots              Stow helper
docs/                 notes about selected configuration
```

A package mirrors its path below the home directory. For example:

```text
home/alacritty/.config/alacritty/alacritty.toml
                                 -> ~/.config/alacritty/alacritty.toml
```

Nukebyte's monitor layout, Plasma panel, power settings, input-device settings,
KWin layout, and hardware-specific System Monitor pages live under
`hosts/nukebyte/`. They are linked only when the active hostname is `nukebyte`.

The Hyprland, Waybar and UWSM packages are linked the same way, so an edit
under `~/.config/hypr` lands in this repository and `hyprctl reload` picks it
up. Each machine's monitor layout is
`home/hypr/.config/hypr/monitors/HOSTNAME.lua`; `hyprland.lua` loads the one
matching `/etc/hostname`.

## Commands

```text
dots link [PACKAGE...]    link all packages or selected shared packages
dots unlink [PACKAGE...]  remove all links or selected shared-package links
dots dry-run [PACKAGE...] preview the corresponding link operation
dots add PACKAGE FILE     adopt one reviewed regular file
dots scan                 report nearby unmanaged configuration files
dots status               show the active host and Git status
dots doctor               check dependencies, links, and sensitive filenames
```

With no package arguments, `link`, `unlink`, and `dry-run` operate on every
shared package plus the current host package. With package arguments, they
operate only on the named package below `home/`.

The `add` command refuses known credential locations and files containing
secret-shaped assignments. Before it replaces the source with a Stow link, it
stores a recovery copy under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/`.

`scan` reports unmanaged files beside tracked configuration. It does not import
or delete anything. Patterns in `.dots-ignore` keep known generated files out of
its output.

## Setup

Install Git and Stow, clone the repository to `~/code/dotfiles`, and link the
packages you want, previewing first:

```bash
sudo pacman -S --needed git stow
bin/dots dry-run fish git starship alacritty
bin/dots link fish git starship alacritty
bin/dots doctor
```

The `dots` command is itself the `dotfiles-cli` package
(`bin/dots link dotfiles-cli`), which also installs its Fish completions. It
finds the repository by following its own link, so the clone can live anywhere.

## Selected configuration

Fish defines the interactive shell, aliases, tool initialization, and a Trash
wrapper for `rm`. Git, Ghostty, Alacritty, Starship, fastfetch, btop, Micro,
the SSH agent (`ssh-agent`: session environment, KWallet unlock at login), SSH
forwarding, and selected KDE settings have separate packages.

Ghostty, fastfetch and btop share the Catppuccin Mocha palette. The fastfetch
logo is generated from the company logo SVG by `assets/fastfetch/logo-anim.py`,
which writes the still logo and the idle animation that `ff-logo` plays.

KDE file ownership and the host split are documented in
[`docs/kde.md`](docs/kde.md). The SSH forwarding fragment is documented in
[`docs/ssh.md`](docs/ssh.md).
