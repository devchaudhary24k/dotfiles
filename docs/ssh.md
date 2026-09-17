# SSH forwarding inventory

`home/ssh/.ssh/config.d/carbon-forwards.conf` is loaded by the private
`~/.ssh/config`. It applies to the `carbon` host alias. The public fragment does
not contain Carbon's address, an identity path, or credentials.

Both ends of every forward bind to `127.0.0.1`. The fragment forwards these
ports:

- `3000` through `3005`
- `5000` through `5005`
- `4173`, `4321`, and `6006`

OpenSSH has no range syntax, so the file contains 15 `LocalForward` entries.
Each successfully bound port remains reserved on nukebyte for the life of the
SSH connection. `ExitOnForwardFailure no` lets a normal connection continue if
one is busy. A client that overrides this setting can still fail the whole
connection when any listed port is unavailable.

The private SSH config, Carbon's address, `known_hosts`, control sockets, and
keys stay outside this repository.
