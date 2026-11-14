# Carbon

Carbon is the headless development machine: an AMD Ryzen 5 3500 (6 cores),
16 GB of RAM, a 240 GB SATA SSD for the system and a 1 TB HDD for bulk
storage. It runs Arch Linux and is reached over SSH, on the home LAN or over
Tailscale. It was rebuilt on 2026-11-14; before that it ran NixOS from the
`carbon-nix` repository.

Two scripts set it up. Run them on carbon, as root, from inside tmux, in this
order:

```bash
sudo bash setup/carbon.sh       # base system, remote access, safety net
sudo bash setup/carbon-dev.sh   # dev packages, Docker, long-term logs, MCC bots
```

Either can be run again at any time. Each step checks its own state or
rewrites its own files, so a second run changes nothing that is already
right. Every run appends to `/var/log/carbon-setup.log`. The last three steps
of `carbon.sh` wait for input: the Tailscale login, the firewall confirmation
and the phone test.

Neither script touches the data on the HDD. The tools installed as `dev24k`
(Claude Code, T3 Code, Node versions) are described under
[Development](#development).

## Base system

`/etc/pacman.conf` has `ParallelDownloads = 10`, `Color` and
`VerbosePkgLists` turned on.

The script installs `base-devel`, `git`, `tmux`, `pacman-contrib`,
`reflector`, `nftables`, `tailscale`, `smartmontools`, `atop` and `earlyoom`.

Reflector picks the fastest HTTPS mirrors in India and rewrites
`/etc/pacman.d/mirrorlist` once a week (`reflector.timer`). Its settings are
in `/etc/xdg/reflector/reflector.conf`. The mirror list from the installer is
kept as `/etc/pacman.d/mirrorlist.orig`.

The AUR helper is `paru-bin`, a prebuilt paru. If a pacman update ever breaks
it with a `libalpm` error, rebuild it from the AUR.

The timezone is `Asia/Kolkata`. `systemd-timesyncd` keeps the clock in sync.

## Access

### SSH

`/etc/ssh/sshd_config.d/10-carbon.conf` allows key login only, and only for
`dev24k`. Root cannot log in. sshd uses the first value it reads for each
setting, so this `10-` file wins over the `20-` and `99-` files that Arch
ships.

The key is `~/.ssh/carbon/carbon` on nukebyte, and nukebyte's `~/.ssh/config`
has a `carbon` host entry that uses it. Password login over the network is
off. Without the key, the only way in is a keyboard and screen on carbon
itself.

To check from nukebyte that password login is refused:

```bash
ssh -o PubkeyAuthentication=no carbon    # expect: Permission denied (publickey)
```

nukebyte's SSH config uses `ControlMaster auto` with `ControlPersist 600`.
After one login, other SSH commands to carbon reuse that connection without
logging in again. This applies to any program running as you, and lasts until
10 minutes after the last session closes. `ssh -O exit carbon` closes it.

### Tailscale

Carbon is an exit node and routes the home LAN (`192.168.31.0/24`) to the
tailnet. IP forwarding for both is turned on in
`/etc/sysctl.d/60-carbon-forwarding.conf`.

Three settings live in the Tailscale admin console. On the carbon machine,
"Edit route settings" approves the subnet route and the exit node. The `…`
menu in the Machines list disables key expiry. Without that, carbon drops off
the tailnet when its key expires.

The subnet route lets tailnet devices reach the home LAN through carbon when
they are away. Phones, macOS and Windows use it automatically. Linux only uses
it after `tailscale set --accept-routes`, which nukebyte doesn't need: at home
it is already on that LAN. The exit node sends all of a device's internet
traffic out through carbon, and only when that device picks carbon as its
exit node.

`tailscale up` prints a warning about UDP GRO forwarding on `enp8s0`. It only
affects exit-node throughput and can be left alone.

### Firewall

`/etc/nftables.conf` defines a single table, `inet carbon`. It accepts SSH
from the LAN on `enp8s0` and over `tailscale0`, Tailscale's own UDP port
41641, and anything from Docker networks to carbon itself. Everything else
coming in is dropped, and a few dropped packets per minute are logged:
`journalctl -k --grep nft-refused`. Forwarded traffic is allowed from the
tailnet (for the exit node and subnet route) and from Docker networks going
out.

The file deletes and redefines only its own table. Arch's stock file begins
with `flush ruleset`, which would also delete the tables that Docker and
Tailscale create for themselves.

`nftables.service` loads the file and exits, so `systemctl status nftables`
showing `inactive` is normal. To see the rules that are loaded:

```bash
sudo nft list table inet carbon
```

To open a port, add a rule to the `input` chain and run
`sudo systemctl restart nftables`. Don't give `nftables.service` an
`ExecStop`: it runs as soon as the service exits and deletes the table that
was just loaded.

Development servers don't need open ports. nukebyte reaches them through the
SSH port forwards described in [`ssh.md`](ssh.md).

### Services without a login

Linger is on for `dev24k` (`loginctl enable-linger`). User services
(`systemctl --user`) start at boot and keep running when no one is logged in.
Docker and the other long-running services are system services, which never
depend on a login.

`systemd-networkd-wait-online` waits for any one link instead of all of them
(`--any`). The Wi-Fi card is unused and never connects, and without this the
boot would wait two minutes for it.

## Safety net

### Fallback kernel

Both `linux` and `linux-lts` are installed. Each has its own single-file
kernel image (UKI) in `/boot/EFI/Linux/`. Normal boots use `arch-linux.efi`.
To boot the LTS kernel once, with the next boot going back to normal:

```bash
sudo systemctl reboot --boot-loader-entry=arch-linux-lts.efi
```

If the normal kernel stops booting, pick the LTS entry in the boot menu. That
needs a screen.

### Swap

| Swap | Size | Priority |
|---|---|---|
| zram (compressed RAM) | half of RAM, 7.8 GB | 100, used first |
| `/swapfile` on the SSD | 16 GB | 10, used once zram is full |

zram is configured in `/etc/systemd/zram-generator.conf` and the swapfile in
`/etc/fstab`. `/etc/sysctl.d/70-carbon-memory.conf` tunes memory reclaim for
zram (`vm.swappiness = 180` and three related values, from the Arch wiki's
zram page).

### SSD trim

When a file is deleted, the filesystem marks its blocks as free, but the SSD
doesn't know until it is told. TRIM tells it, which keeps writes fast and
reduces wear. `fstrim.timer` trims the SSD once a week. The `discard` mount
option would trim on every delete instead, which stalls this DRAM-less SSD.

### Memory, CPU and disk limits

Agents and builds can use a lot of memory and CPU very quickly. These limits
keep SSH and the system responsive while that happens.

| Unit | Setting | File |
|---|---|---|
| `user.slice`: everything you and the agents run | `MemoryHigh=80%`, `MemoryMax=90%`, `CPUWeight=50`, `IOWeight=50` | `/etc/systemd/system/user.slice.d/50-carbon-limits.conf` |
| `docker.slice`: containers, once Docker uses it | `MemoryHigh=60%`, `MemoryMax=75%`, `CPUWeight=50`, `IOWeight=50` | `/etc/systemd/system/docker.slice` |
| `system.slice` | `MemoryMin=1G`, memory user work can't take | `/etc/systemd/system/system.slice.d/50-carbon-reserve.conf` |
| `sshd.service` | `MemoryMin=64M`, `CPUWeight=1000` | `/etc/systemd/system/sshd.service.d/50-carbon-lifeline.conf` |
| `tailscaled.service` | `MemoryMin=128M`, `CPUWeight=1000`, `OOMScoreAdjust=-900` | `/etc/systemd/system/tailscaled.service.d/50-carbon-lifeline.conf` |

`sshd` gets no `OOMScoreAdjust`, because sshd passes its own value on to
every login session it starts. That would make the agents hard to kill too.

As memory runs out, these happen in order:

1. Above 80% of RAM, user work is slowed down and pushed into swap. The system
   keeps its reserved memory.
2. When available RAM is below 5% and free swap below 25%, earlyoom sends
   SIGTERM to the process using the most memory. At 2% and 10% it sends
   SIGKILL.
3. If user work reaches 90% of RAM, the kernel kills a process inside
   `user.slice` only.

earlyoom never kills `sshd`, systemd, `tailscaled`, Docker, containerd or
tmux. It picks browsers and compilers first (`chrome`, `chromium`,
`headless_shell`, `cc1plus`, `rustc`). Its arguments are in
`/etc/carbon/earlyoom.env`.

earlyoom kills single processes. `systemd-oomd`, which kills whole cgroups, is
not used: agents started from one SSH session share a cgroup, so it would end
the whole tmux session.

Other limits:

- **Open files:** 65536, with a hard limit of 524288, for every service and
  login (`/etc/systemd/{system,user}.conf.d/50-carbon-nofile.conf`).
- **File watchers:** 1,048,576 inotify watches and 1024 instances, for Vite,
  `tsc --watch` and editors (`/etc/sysctl.d/70-carbon-watchers.conf`).
- **`/tmp`:** in RAM, capped at 25% of RAM (about 4 GB) instead of 50%.
- **The system journal:** kept 3 months, capped at 2 GB, and never allowed to
  fill the last 5 GB of the disk.
- **The package cache:** `paccache.timer` keeps the last 3 versions of each
  package, every week. That is enough to downgrade one with
  `pacman -U /var/cache/pacman/pkg/...`.
- **The HDD's I/O scheduler:** BFQ, which makes `IOWeight` count on that disk
  (`/etc/udev/rules.d/60-carbon-ioscheduler.rules`).

### atop

atop records a full system snapshot every 5 minutes and keeps 28 days. After
a slowdown, replay that day's file and step through it with `t` and `T`:

```bash
atop -r /var/log/atop/atop_$(date +%Y%m%d)
```

### Long-term logs

`setup/carbon-dev.sh` adds the rest of what the old NixOS setup kept, so a
problem can be looked up weeks later. Nothing is sent anywhere.

| Record | Kept by | Read with |
|---|---|---|
| CPU, memory, disk and per-interface network, every 5 minutes, 90 days | `sysstat` | `sar -u`, `sar -r`, `sar -n DEV` |
| Data used per interface, per hour, day and month | `vnstat` | `vnstat -d`, `vnstat -m` |
| Programs that crashed, with compressed core dumps (at most 1 GB) | `systemd-coredump` | `coredumpctl list` |
| Memory and CPU hardware errors | `rasdaemon` (AUR) | `ras-mc-ctl --summary` |
| CPU, memory, disks, PCI, USB and network at every boot | `hardware-inventory.service` | `journalctl -u hardware-inventory` |
| Connections the firewall dropped | the `nft-refused` log rule | `journalctl -k --grep nft-refused` |

`sysreport` prints a one-page summary of the machine right now: failed
services, recent errors, processes killed for memory, crashes, disk space,
memory, temperatures and network use. Run it with `sudo` to add disk health.

## Bulk drive

The 1 TB HDD is a single ext4 partition labelled `carbon-bulk`, mounted at
`/srv/bulk` by UUID with `noatime,nofail,x-systemd.device-timeout=30s`.
`nofail` matters on a headless machine: if the HDD dies, carbon still boots
and stays reachable instead of stopping at an emergency prompt. 1% of the disk
is reserved for root instead of the usual 5%.

`/srv/bulk/datasets` and `/srv/bulk/downloads` belong to `dev24k`, and new
files in them get the `users` group.

## Development

### Packages

`setup/carbon-dev.sh` installs only what TypeScript, JavaScript and Node work
needs, plus common build tools:

- **Node:** `nodejs-lts-krypton` (Node 24) is the system Node, which services
  and agents find without any shell setup. `fnm` switches versions per project
  from `.node-version` or `.nvmrc` in interactive shells. Also `npm`, `pnpm`,
  `yarn` and `bun`.
- **Build tools:** `base-devel` (gcc, make), `cmake`, `ninja` and `clang`, for
  native npm modules and AUR packages.
- **Everyday tools:** `github-cli`, `jq`, `ripgrep`, `fd`, `fzf`, `btop`,
  `ncdu`, `lsof`, `strace`, `tree`, `micro`, `neovim`, `watchexec`, `just`,
  `shellcheck` and `rsync`.
- **Docker:** `docker`, `docker-compose`, `docker-buildx` and `lazydocker`.

Databases are not installed. Projects run their own in Docker Compose.

### Docker

`/etc/docker/daemon.json` puts every container in `docker.slice`, so
containers together are capped at 75% of RAM. Container logs use the `local`
driver, at most 3 files of 20 MB each. `docker-prune.timer` removes images and
build cache unused for a week, every week. It never touches volumes.

`dev24k` is in the `docker` group, which is equivalent to root access.

### Coding agents

- **Claude Code** is installed with its own installer as `~/.local/bin/claude`
  and updates itself.
- **Codex** is the `openai-codex` package and updates with `pacman -Syu`.

The restore brought back both tools' settings, logins and history.

### Shell

The login shell is fish, configured by this repository like nukebyte's:
`hosts/carbon/packages` links fish, starship, git, btop and fastfetch. The
prompt is teal instead of red, and fastfetch shows a benzene ring instead of
the company logo, so a terminal shows which machine it is on. The tools the
fish config expects (`eza`, `bat`, `zoxide`, `trash-cli`) are installed.

Bash is still installed, and scripts that start with `#!/usr/bin/env bash` use
it. `~/.bashrc` is Arch's default.

`~/.config/environment.d/10-carbon-path.conf` puts `~/.local/bin` on PATH for
user services, so T3 Code and the agents it starts find `claude`. It is not
part of the dotfiles.

## GitHub

Carbon has its own GitHub key, separate from nukebyte's: `~/.ssh/github/github`
(ed25519, `dev24k@carbon`), the same path as on nukebyte. It has no passphrase,
because nobody is at carbon to type one and T3 Code and the agents push on
their own. If the key is ever in doubt, delete it on GitHub and carbon is cut
off at once.

- `~/.ssh/config` uses the key for `github.com` only. Carbon's `known_hosts`
  entry for github.com was checked against the fingerprint GitHub publishes.
- The key is on the GitHub account twice, both titled "carbon (Arch) 2026-11":
  once as an authentication key and once as a signing key.
- `gh` is signed in (`gh auth login`, SSH protocol), with the scopes needed to
  add keys. T3 Code uses this login for pull requests and automatic pulls.
- Commits are signed with the same key. `~/.config/git/local.gitconfig` holds
  carbon's signing settings and is not in the dotfiles. Carbon's public key is
  in `home/git/.config/git/allowed_signers`, next to nukebyte's.
- The name and email come from the dotfiles' `.gitconfig`, which includes
  `local.gitconfig`.

## T3 Code

T3 Code was installed with `curl -fsSL https://t3.codes/install.sh | sh`,
which put the `t3` command in `~/.local/bin`. `t3 service install` created the
user service `t3code.service`. It listens on `127.0.0.1:3773` only, and runs
from boot without a login because linger is on. Its state is in `~/.t3`.

`t3 service protect` reserves memory for the server and makes the
out-of-memory killer pick agents before it. It offered to protect `sshd` and
`tailscaled` too; that was declined because `setup/carbon.sh` already does.
Undo it with `t3 service protect --undo`.

To pair a device: `t3 pair --tailscale`. It serves T3 over Tailscale HTTPS,
which reaches the local port, so the firewall needs no change. `dev24k` is the
Tailscale operator (`tailscale set --operator=dev24k`), which lets it set that
up without sudo.

To update: `t3 update`. `t3 doctor` offers to delete the database from before
0.1.0 (1.33 GB). Keep it: the backup notes say some tool-activity history
exists only there. The service log from the old machine was restored too, so
its errors from before 2026-11-14 are history, not current problems.

## MCC bots

Four Minecraft Console Client bots run as system services, one per account:
`mcc-dev24k`, `mcc-devchaudhary24k`, `mcc-hammersamster` and `mcc-kartik`.
`mcc.target` groups them and starts them at boot. `setup/carbon-dev.sh` sets
all of this up. It is a port of `modules/services/mcc.nix` from carbon-nix.

- **Binary:** MCC `20260906-516`, downloaded from the MCC GitHub release and
  checked against its SHA-256. It is at
  `/usr/local/lib/mcc/MinecraftClient-20260906-516`, with
  `/usr/local/lib/mcc/MinecraftClient` linking to it.
- **Accounts:** `/opt/mcc/accounts/<name>/` holds each account's
  `MinecraftClient.ini` and its login and session tokens. The folder is
  readable only by `dev24k` (mode 700) and is not in this repository.
- **Console:** each bot runs inside GNU `screen` (sockets in `/run/mcc`).
  screen answers MCC's terminal queries even when nobody is attached; without
  that, the backlog corrupted a bot's input on the old machine.
- **Start order:** the bots start 20 seconds apart, because four logins at
  once made the server reject some. Boot therefore reaches `multi-user.target`
  about a minute after SSH is already up. That is the stagger, not a problem.
- **MCP:** each bot runs MCC's MCP server on `127.0.0.1`, on ports 33331 to
  33334 in account-name order. It only answers while the bot is in the game.
- **Restarts:** a bot that exits restarts after 15 seconds. Five failures in
  five minutes stop it, and the phone alert reports it.
- **Without sudo:** `/etc/polkit-1/rules.d/50-mcc.rules` lets `dev24k` start,
  stop and restart the bots, and nothing else.

`mcc` controls the bots. `mcc status` shows each bot's state, uptime and MCP
port. `mcc attach <account>` opens one bot's console; detach with Ctrl-A then
D. `mcc dash` shows all four consoles side by side. `mcc help` lists the rest.

Every `MinecraftClient.ini` has `MinecraftVersion = "26.2"` instead of
`"auto"`. On 2026-11-14 the server (play.romanmc.net) began reporting protocol
777, Minecraft 26.3, which no MCC release supports yet. With `auto` the bots
were refused with "This version is not supported". With 26.2 the server
accepts them. The configs from before this change are kept as
`MinecraftClient.ini.before-26.2-pin`. Once an MCC release supports 26.3,
change the version or set it back to `auto`.

## Restoring the backup (2026-11-14)

Before the reinstall, the old system was backed up to the HDD as
`backups/pc-reset-2026-11-14/`. The backup had its own README and
`restore.sh`. A dry run came first, then `./restore.sh --apply`, which
compared every restored file byte for byte with the backup:

- 463,542 files (23.2 GB) in `/home/dev24k`. Nothing was overwritten.
- All 522 `.env` files, and all 87 worktree links.
- The T3 Code database, with 215 threads.
- `/opt/mcc`, all 37 files, with the accounts folder still mode 700.

`node_modules` and build output were left out of the backup on purpose. Run
`pnpm install` in each repository or worktree before working in it. Also
removed after the restore, as the backup's README says: a stale
`~/code/commitscape/.git/refs/remotes/origin/HEAD.lock`.

Nothing else on the HDD was kept. That includes the old `datasets`, the old
system and home snapshots, the old database dumps, and the backup itself. The
HDD was then reformatted as ext4.

## Phone alerts

Alerts are sent as push notifications through ntfy.sh, a free service. The
phone subscribes to a topic in the ntfy app. The topic name is stored on
carbon in `/etc/carbon/ntfy-topic`, readable only by root, and is not in this
repository. Anyone who knows the name can read and send alerts, so treat it as
a password.

| Alert | Sent by |
|---|---|
| A system service failed | `carbon-notify-failure@.service`, through a drop-in that applies to every service |
| `/` or `/srv/bulk` is 85% full | `carbon-disk-check.timer`, every 15 minutes; sent once, then again after the disk drops below 80% |
| A process was killed for memory | `carbon-oom-watch.service`, at most once a minute |
| Carbon has booted | `carbon-boot-notify.service` |
| A disk is failing or reaches 60 °C | `smartd`, which also runs a short self-test daily at 02:00 and a long one on Sundays at 03:00 |

Alerts contain unit names, statuses and process names, never log lines. The
scripts are in `/usr/local/lib/carbon/`. To send one by hand:

```bash
sudo /usr/local/lib/carbon/notify "Title" "Message"
```

To change the topic, write the new name to `/etc/carbon/ntfy-topic` and
subscribe to it in the app.

## Problems on the first run

- The step that printed the effective SSH settings with `sshd -T` stopped the
  script, even though the settings were already applied. OpenSSH 10 prints
  setting names in CamelCase (`PermitRootLogin no`) and the search was
  case-sensitive. The search now ignores case, and a mismatch is only a
  warning. Checked as root afterwards: all five settings are as intended.
- The firewall's first version gave `nftables.service` an `ExecStop`, which
  deleted the rules right after loading them. That override has been removed.
- The first version didn't enable `paccache.timer`. It does now.
- `systemd-networkd-wait-online` failed once, during the second run. Something
  started it before the `--any` override was loaded, so it waited for the
  Wi-Fi. It works now, and the failed state clears on reboot.

- Unmounting the old HDD failed with "target is busy". A `du` started during
  the inventory was still reading it, and about ten services started while
  the HDD was mounted held their own copy of the mount. Both were cleared
  before the wipe.

## How the rebuild was done

On 2026-11-14 Claude Code did the setup from nukebyte, over SSH with the
carbon key. It ran `setup/carbon.sh` with you at the keyboard for the sudo
password. For the rest, it used temporary passwordless sudo:
`/etc/sudoers.d/90-claude-temp`, which would have deleted itself after 6 hours
(`claude-sudo-expire.timer`). The same rule went onto nukebyte by mistake and
was deleted there straight away. Both rules and both timers were removed at
the end, and `sudo` asks for a password on both machines again.

Files left on carbon from the rebuild:

- `/var/log/carbon-setup.log`: the output of every setup run.
- `~/restore-apply.log`: the output of the backup restore.
- `MinecraftClient.ini.before-26.2-pin` in each MCC account folder.

## Still to do


- **Pair T3 Code** with `t3 pair --tailscale`.
