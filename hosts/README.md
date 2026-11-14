# Machines

Each folder here is named after a machine's `hostnamectl hostname`.

- `packages` lists the packages `./link` links on that machine, one per line.
  `#` starts a comment.
- `PACKAGE/` folders hold files only that machine gets. They mirror paths below
  the home directory, and are linked together with `home/PACKAGE` whenever
  `PACKAGE` is in the list. A folder here can also be a package of its own, with
  no `home/` counterpart.

Use this layer for logos, display layouts, hardware-specific KDE rules and
anything else that should not be the same on every machine.
