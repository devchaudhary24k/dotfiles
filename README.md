# Dotfiles

This repository contains reviewed user configuration. It does not track package
lists, root-owned system files, application snapshots, credentials, histories,
caches, or backups.

## Consumers

Both machines run NixOS from
[`carbon-nix`](https://github.com/devchaudhary24k/carbon-nix), which takes this
repository as a flake input and links these paths with Home Manager:

```text
home/git/.gitconfig
home/git/.config/git/ignore
home/fish/.config/fish
home/starship/.config/starship.toml
home/hypr/.config/hypr                desktop machines
home/waybar/.config/waybar            desktop machines
home/uwsm/.config/uwsm                desktop machines
```

`home/hypr/.config/hypr/monitors/HOSTNAME.lua` is linked to
`~/.config/hypr/monitors.lua` on the matching machine.

These paths are part of the interface to `carbon-nix`. If one moves, update
`home/dev24k/` in `carbon-nix` to match. A change here reaches a machine after
`nix flake update dotfiles` in `carbon-nix` and a rebuild.

The packages Nix links are listed in `.nix-managed`, and `dots` leaves them
alone. Everything else, including KDE settings that Plasma rewrites and the
host package, is still linked with Stow by `bin/dots link`, because
Nix-managed links are read-only.

## Layout

```text
home/                 shared user configuration
hosts/HOSTNAME/       configuration for one machine
bin/dots              Stow helper
docs/                  notes about selected configuration
```

A package mirrors its path below the home directory. For example:

```text
home/alacritty/.config/alacritty/alacritty.toml
                                 -> ~/.config/alacritty/alacritty.toml
```

Nukebyte's monitor layout, Plasma panel, power settings, input-device settings,
KWin layout, and hardware-specific System Monitor pages live under
`hosts/nukebyte/`. They are linked only when the active hostname is `nukebyte`.
There is no `hosts/carbon/` package because Carbon's machine configuration lives
in `carbon-nix`.

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

## Setup on nukebyte

Clone the repository to `~/code/dotfiles` (Git and GNU Stow come with
carbon-nix), then run:

```bash
bin/dots dry-run
bin/dots link
bin/dots doctor
```

The `dots` command is itself managed by the `dotfiles-cli` Stow package. Fish
completions for it are in the same package.

## Selected configuration

Fish defines the interactive shell, aliases, tool initialization, and a Trash
wrapper for `rm`. Git, Alacritty, Starship, btop, Micro, SSH forwarding, and
selected KDE settings have separate packages.

KDE file ownership and the host split are documented in
[`docs/kde.md`](docs/kde.md). Carbon's SSH forwarding fragment is documented in
[`docs/ssh.md`](docs/ssh.md).
