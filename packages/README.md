# Package manifests

`bin/dots snapshot` regenerates these plain, sorted name lists from the running
machine:

- `pacman.txt`: explicitly installed native repository packages;
- `aur.txt`: explicitly installed foreign packages, normally from the AUR;
- `flatpak.txt`: installed Flatpak application IDs; and
- `enabled-user-services.txt`: currently enabled systemd user units.

The first three describe how to reacquire applications; they do not archive
package binaries. `manual.md` records software installed outside those package
managers.

The service manifest is an audit aid, not an automatic restore instruction.
Package-provided defaults should not be re-enabled without review.

