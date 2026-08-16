# CachyOS dotfiles

This repository is the reproducible, reviewable part of this CachyOS setup. It
tracks four kinds of desired state:

1. selected home-directory configuration in `home/`;
2. installed-package manifests in `packages/`;
3. machine-specific configuration in `hosts/`; and
4. carefully reviewed system configuration in `system/`.

It is deliberately not a backup of the entire home directory. Credentials,
browser profiles, application databases, histories, caches, and other personal
data belong in a separate encrypted backup.

## Daily workflow

After installing or removing software, refresh the generated manifests:

```bash
bin/dots snapshot
git diff -- packages
```

To adopt a new, ordinary configuration file:

```bash
bin/dots add yazi ~/.config/yazi/yazi.toml
```

The `add` command intentionally accepts one regular file at a time. It refuses
known credential locations and secret-shaped assignments, keeps a recovery
copy under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/`, and then asks
GNU Stow to create the link.

Once a file is linked, edit it through its normal path under `~/.config`.
Changes immediately modify the corresponding repository file:

```bash
bin/dots status
git diff
git add home
git commit
```

Use `bin/dots scan` to report unmanaged files located below configuration
directories that are already tracked. The command only reports; it never
imports anything automatically.

## Commands

```text
bin/dots snapshot            regenerate package and service manifests
bin/dots add PACKAGE FILE     adopt one reviewed configuration file
bin/dots link [PACKAGE...]    link all or selected home packages
bin/dots unlink [PACKAGE...]  remove managed links
bin/dots dry-run [PACKAGE...] preview Stow operations
bin/dots scan                 report unmanaged neighbouring config files
bin/dots status               show repository status and a diff summary
bin/dots doctor               check dependencies, links, and secret risks
```

GNU Stow is the only dependency not present on a fresh version of this
repository. Install it with:

```bash
sudo pacman -S --needed stow
```

The repository uses file-level links via Stow's `--no-folding` option. This
keeps application-created files in the normal home directory until they are
explicitly reviewed and adopted.

The initial managed set is deliberately small: Fish, Alacritty, Starship,
btop, and Micro's settings file. Fish's generated `fish_variables` and Micro's
bundled syntax files are excluded.

## Fresh CachyOS installation

The intended restore order is:

1. install Git and GNU Stow;
2. clone this repository as `~/.dotfiles`;
3. install native packages from `packages/pacman.txt`;
4. install foreign/AUR packages from `packages/aur.txt`;
5. run `bin/dots link`; and
6. run `bin/dots doctor`.

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
