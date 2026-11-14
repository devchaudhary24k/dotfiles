# Dotfiles

User configuration for two Arch Linux machines: nukebyte, a laptop running KDE
Plasma, and carbon, a headless development machine reached over SSH. It does
not track root-owned system files, application snapshots, credentials,
histories, caches, or backups.

`./link` links a machine's packages into its home directory with GNU Stow. The
links point back into this repository, so editing `~/.config/fish/...` or
`~/.gitconfig` edits the tracked file directly.

## Layout

```text
home/PACKAGE/            configuration shared by every machine
hosts/HOST/packages      the packages linked on HOST
hosts/HOST/PACKAGE/      files only HOST gets, added to that package
link                     the Stow script
setup/                   one-time system setup for a machine (run as root)
assets/                  sources and generators for files in the packages
docs/                    notes about selected configuration
```

A package mirrors its path below the home directory. For example:

```text
home/fish/.config/fish/config.fish -> ~/.config/fish/config.fish
```

Linking a package links `home/PACKAGE` and, when it exists,
`hosts/HOST/PACKAGE` on top. That is how each machine gets its own fastfetch
logo (`hosts/nukebyte/fastfetch`, `hosts/carbon/fastfetch`) while the
fastfetch config, the aliases and the animation stay shared.

## Commands

```text
./link          link (or relink) every package listed for this machine
./link -n       dry run: show what would change
./link -D       remove this machine's links
./link ... HOST act as HOST instead of this machine's hostname
```

Files are linked one by one (`stow --no-folding`), never whole folders, so a
program that adds files to its config folder never writes into the repository.
If a real file already sits where a link should go, Stow stops and changes
nothing; move the file away and run `./link` again.

## Setup

Install Git and Stow, clone the repository, preview, then link:

```bash
sudo pacman -S --needed git stow
git clone git@github.com:devchaudhary24k/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./link -n
./link
```

For a new machine, create `hosts/HOST/packages` first. Its name is the output
of `hostnamectl hostname`.

## The machines

| | nukebyte | carbon |
|---|---|---|
| Packages | see `hosts/nukebyte/packages` | fish, starship, git, btop, fastfetch |
| fastfetch logo | the company logo | a carbon atom |
| Prompt colours | reds | teals |

The prompt and logo differ so a terminal shows which machine it is on.
Starship has one config, `home/starship/.config/starship.toml`, with a
palette per machine; fish selects the one named after the hostname. Carbon's
system setup (`setup/carbon.sh`, `setup/carbon-dev.sh`) is described in
[`docs/carbon.md`](docs/carbon.md).

## Selected configuration

Fish defines the interactive shell, aliases, tool initialization, and a Trash
wrapper for `rm`. Git, Ghostty, Alacritty, Starship, fastfetch, btop, Micro,
the SSH agent (`ssh-agent`: session environment, KWallet unlock at login), SSH
forwarding, Hyprland, Waybar, UWSM and selected KDE settings have separate
packages. A package that is not in a machine's list is simply not linked there.

Ghostty, fastfetch and btop share the Catppuccin Mocha palette. fastfetch runs
when a terminal opens and when you type `fastfetch` (or `ff`); its logo then
animates until the screen could move. `ff-logo` plays the animation. The
logos come from generators in `assets/fastfetch/`: `logo-anim.py` draws
nukebyte's from the company logo SVG, and `atom-anim.py` draws carbon's.

Each machine's Hyprland monitor layout is
`home/hypr/.config/hypr/monitors/HOSTNAME.lua`; `hyprland.lua` loads the one
matching `/etc/hostname`.

KDE file ownership and the host split are documented in
[`docs/kde.md`](docs/kde.md). The SSH forwarding fragment is documented in
[`docs/ssh.md`](docs/ssh.md).
