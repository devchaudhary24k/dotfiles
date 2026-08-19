# CachyOS dotfiles

This repository is the reproducible, reviewable part of this CachyOS setup. It
tracks five kinds of desired state:

1. selected home-directory configuration in `home/`;
2. installed-package manifests in `packages/`;
3. machine-specific configuration in `hosts/`;
4. sanitized stateful-application snapshots in `snapshots/`; and
5. carefully reviewed system configuration in `system/`.

It is deliberately not a backup of the entire home directory. Credentials,
browser profiles, application databases, histories, caches, and other personal
data belong in a separate encrypted backup.

## Daily workflow

One command refreshes package manifests and every enabled app collector:

```bash
dots sync
git diff
```

The repository's pre-commit hook runs the same sync automatically and stages
generated changes below `packages/` and `snapshots/`. If OBS is open, the hook
stops the commit so OBS can be closed before retrying; this prevents a partial
snapshot.

To adopt a new, ordinary configuration file:

```bash
dots add yazi ~/.config/yazi/yazi.toml
```

The `add` command intentionally accepts one regular file at a time. It refuses
known credential locations and secret-shaped assignments, keeps a recovery
copy under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/`, and then asks
GNU Stow to create the link.

Once a file is linked, edit it through its normal path under `~/.config`.
Changes immediately modify the corresponding repository file:

```bash
dots status
git diff
git add home
git commit
```

Use `dots scan` to report unmanaged files located below configuration
directories that are already tracked. The command only reports; it never
imports anything automatically.

`dots` is a Stow-managed executable at `~/.local/bin/dots`, which is already on
the Fish `PATH`. It delegates to this repository's `bin/dots` implementation,
so the command also works from other shells. Fish completions describe the
subcommands and complete Stow package names.

## Commands

```text
dots sync                 refresh packages and all enabled collectors
dots sync --list          list enabled collectors
dots sync --only NAME     run one collector without refreshing packages
dots snapshot             refresh package and service manifests only
dots add PACKAGE FILE     adopt one reviewed configuration file
dots link [PACKAGE...]    link all or selected home packages
dots unlink [PACKAGE...]  remove managed links
dots dry-run [PACKAGE...] preview Stow operations
dots scan                 report unmanaged neighbouring config files
dots tui                  open the interactive terminal interface
dots machine list         list host-labelled recovery profiles
dots machine status HOST  show public boot-security state
dots machine plan HOST    preview the guarded recovery procedure
dots status               show repository status and a diff summary
dots doctor               check dependencies, links, and secret risks
```

Run `dots tui` when you do not remember a command. It exposes package
snapshots, collectors, config adoption, link/unlink previews, diagnostics, and
the guarded machine-security workflow from one menu. The TUI uses `whiptail`
from the `libnewt` package. Destructive or root-owned actions still require a
second confirmation and show the command output.

GNU Stow manages the home-directory links, and `jq` performs the OBS JSON
sanitization. Install both with:

```bash
sudo pacman -S --needed stow jq
```

The repository uses file-level links via Stow's `--no-folding` option. This
keeps application-created files in the normal home directory until they are
explicitly reviewed and adopted.

The initial managed set is deliberately small: Fish, Git, Alacritty, Starship,
btop, Micro's settings file, and selected KDE settings. Fish's generated
`fish_variables` and Micro's bundled syntax files are excluded.

## Adding new applications

Use `dots add APP FILE` for an ordinary safe configuration file. For an app
whose useful configuration is mixed with secrets or generated state, add one
executable named `collectors/APP`. `dots sync` discovers it automatically, so
the main command and hook never need an application list.

Collectors export only reviewed data into `snapshots/APP/`, support a read-only
`--check`, and perform app-specific sanitization. The complete collector
contract is in `collectors/README.md`.

## KDE layout

Portable preferences live in `home/kde/`: appearance, shortcuts, input
behavior, default applications, locale, notifications, and selected KDE app
settings. They are normal Stow links, so changes made through System Settings
or the applications immediately appear in `git diff`.

Monitor layout, panels and widgets, Plasma shell state, and power settings live
in `hosts/nukebyte/`. `dots link` applies that package only when the current
static hostname is `nukebyte`; it will not impose this machine's desktop layout
on another computer.

KDE configuration files are coupled: for example, `kdeglobals` supplies the
palette used by Dolphin and many other applications. Do not delete a tracked
KDE file from the live Stow package merely because it looks generated. First
unstow only in a test account, restart the affected applications, and verify
the complete desktop. The current file inventory is explained in
[`docs/kde.md`](docs/kde.md).

The customized Plasma System Monitor navigation and pages are stored in
`home/kde/.config/systemmonitorrc` and
`home/kde/.local/share/plasma-systemmonitor/`. Several sensors are specific to
`nukebyte`'s Ryzen/NVIDIA/Radeon/NVMe hardware.

## SSH forwarding

The public `home/ssh` package contains only Carbon's loopback port forwards.
Private host addresses and identity configuration remain in the untracked
`~/.ssh/config`, which loads the managed fragment through:

```sshconfig
Include ~/.ssh/config.d/*.conf
```

The forwarded ranges and their operational trade-offs are documented in
[`docs/ssh.md`](docs/ssh.md). SSH keys are never tracked.

## Machine security profile

`system/nukebyte/` records the public, device-labelled part of this laptop's
LUKS2, TPM2 PCR 7, Secure Boot, Limine, mkinitcpio, NVIDIA, and Btrfs snapshot
configuration. Start with read-only commands:

```bash
dots machine status nukebyte
dots machine plan nukebyte
sudo dots machine doctor nukebyte
```

The apply workflow is deliberately guarded and is not run by `dots link` or
`dots sync`. It checks the exact DMI model, makes `/etc` backups, and asks for
typed confirmation. TPM enrollment is a separate option that requires a fresh
LUKS header backup on protected external storage. Secure Boot private keys,
LUKS headers, and the recovery passphrase never belong in this public repo.

## OBS snapshot

OBS configuration is stateful and can contain credentials, so it is not linked
live with Stow. Close OBS and refresh a curated public snapshot instead:

```bash
dots sync --only obs
```

Normally no OBS-specific command is needed: `dots sync` and the pre-commit hook
both discover the OBS collector automatically.

The export includes ordinary preferences, profiles, encoder settings, and
sanitized scene collections. It excludes logs, profiler data, databases,
backups, generated service definitions, plugin-manager state, the OBS WebSocket
configuration, stream credentials, and PipeWire restore tokens.

On a new machine, copy `snapshots/obs/basic/`, `global.ini`, and `user.ini` into
`~/.config/obs-studio/` while OBS is closed. Screen-capture sources must then be
authorized again; `snapshots/obs/README.md` is documentation, not OBS input.

## Fresh CachyOS installation

The intended restore order is:

1. install Git and GNU Stow;
2. clone this repository as `~/.dotfiles`;
3. install native packages from `packages/pacman.txt`;
4. install foreign/AUR packages from `packages/aur.txt`;
5. run `bin/dots link` once to install the links and `dots` command; and
6. run `dots doctor`.

On CachyOS, package restoration can be performed with:

```bash
sudo pacman -S --needed - < packages/pacman.txt
yay -S --needed - < packages/aur.txt
```

Review `packages/enabled-user-services.txt` rather than enabling every entry
blindly; some services are defaults supplied by installed packages.

Package manifests contain names rather than pinned versions. CachyOS is a
rolling-release distribution, so packages should be restored from a mutually
consistent current repository snapshot.

## Layout rules

Each directory immediately below `home/` is one Stow package and mirrors the
path below the home directory. For example:

```text
home/alacritty/.config/alacritty/alacritty.toml
                                 -> ~/.config/alacritty/alacritty.toml
```

Use one package per application where practical. Cross-application desktop
settings may be grouped under a descriptive package such as `kde` or
`desktop`.

Host-specific files use the same mirrored layout below `hosts/HOSTNAME/`.
Display layouts and hardware-specific KDE rules belong there rather than in a
portable home package.

Files below `system/` are documentation/source copies only. They are never
automatically linked into `/etc`; applying root-owned configuration must remain
an explicit, separately reviewed action.
