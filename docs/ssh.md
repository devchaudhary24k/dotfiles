# SSH forwarding inventory

`home/ssh/.ssh/config.d/carbon-forwards.conf` is a generated, public fragment
loaded by the private `~/.ssh/config`. It applies only to `Host carbon` and
binds listeners to `127.0.0.1` so they are not exposed to the local network.

Forwarded ports:

- `3000` through `3005`;
- `5000` through `5005`;
- `4173`, `4321`, and `6006`.

OpenSSH has no port-range syntax, so the fragment contains one `LocalForward`
per port: 15 forwards in total. They activate automatically when T3 Code,
Codex, or a terminal opens a new `carbon` SSH connection. Existing connections
do not reload config changes.

Every successfully bound port is reserved locally for the lifetime of that SSH
connection. `ExitOnForwardFailure no` protects ordinary `ssh carbon` sessions
when a selected port is busy. T3 Code currently supplies
`ExitOnForwardFailure=yes` on its command line, which overrides the config, so
these 15 local ports must be free when T3 establishes its connection.

The main SSH config, host IPs, `known_hosts`, control sockets, and all private
keys remain outside this public repository.
