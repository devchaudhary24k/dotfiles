# Sync collectors

Each executable file in this directory is an enabled collector. `dots sync`
discovers and runs them in filename order; no central application list needs to
be edited.

A collector must:

- accept no arguments to refresh `snapshots/COLLECTOR_NAME/`;
- accept `--check` for a read-only dependency and source check;
- copy only reproducible configuration, never caches, histories, or databases;
- sanitize credentials and fail if sensitive-looking content remains; and
- refuse to read an application while that application may be writing an
  inconsistent configuration.

Use direct Stow packages in `home/` for ordinary safe configuration files.
Create a collector only when an application's useful configuration is mixed
with generated state or secrets.
