#!/usr/bin/env bash
# setup/carbon.sh: Phases 1-3 of the carbon rebuild.
#
#   Phase 1  base system: pacman, mirrors, paru, clock
#   Phase 2  access: SSH keys only, linger, Tailscale, firewall
#   Phase 3  safety net: linux-lts, swap, resource limits, phone alerts
#
# Run from a tmux session on carbon:   sudo bash setup/carbon.sh
# What it sets up, and why, is written down in docs/carbon.md.
#
# Safe to re-run: every step checks or rewrites only its own files.
# It never touches the data on the 1 TB HDD (that is Phase 4); it only sets
# that disk's I/O scheduler and lets smartd read its health counters.
#
# The non-interactive steps run first. The three steps that need you
# (Tailscale login, firewall confirmation, phone test) come last.
set -Eeuo pipefail

U=${SUDO_USER:-}
[[ $EUID -eq 0 ]] || { echo "Run it with sudo: sudo bash $0"; exit 1; }
[[ $U == dev24k ]] || { echo "Run it from the dev24k account with sudo."; exit 1; }
[[ $(</etc/hostname) == carbon ]] || { echo "This machine is not carbon."; exit 1; }

LOG=/var/log/carbon-setup.log
touch "$LOG" && chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "!! failed at line $LINENO: $BASH_COMMAND"' ERR
echo "=== carbon-setup started $(date -Is)"

LIB=/usr/local/lib/carbon
LAN_IF=enp8s0
LAN_NET=192.168.31.0/24

n=0
step() { n=$((n + 1)); printf '\n\033[1;34m==> %02d  %s\033[0m\n' "$n" "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
# put PATH MODE <<EOF ... EOF   writes stdin to PATH
put() { mkdir -p "$(dirname "$1")"; cat >"$1"; chmod "$2" "$1"; note "wrote $1"; }

###############################################################################
# Phase 1: base system
###############################################################################

step "pacman: 10 parallel downloads, colour, verbose package lists"
sed -i -E \
  -e 's/^#?ParallelDownloads.*/ParallelDownloads = 10/' \
  -e 's/^#Color$/Color/' \
  -e 's/^#VerbosePkgLists$/VerbosePkgLists/' \
  /etc/pacman.conf
grep -E '^(Color|ParallelDownloads|VerbosePkgLists)' /etc/pacman.conf | sed 's/^/    /'

step "Full system upgrade"
pacman -Syu --noconfirm
if [[ ! -d /usr/lib/modules/$(uname -r) ]]; then
  echo
  echo "The running kernel was replaced by the upgrade, so its modules are gone"
  echo "until a reboot (nftables and Tailscale need them). Reboot, then run this"
  echo "script again: it continues where it stopped."
  exit 0
fi

step "Base packages"
pacman -S --needed --noconfirm \
  base-devel git tmux pacman-contrib reflector \
  nftables tailscale smartmontools atop earlyoom

step "Mirrors: fastest HTTPS mirrors in India, refreshed weekly"
[[ -f /etc/pacman.d/mirrorlist.orig ]] || cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
put /etc/xdg/reflector/reflector.conf 644 <<'EOF'
# Read by reflector.service (weekly through reflector.timer).
--save /etc/pacman.d/mirrorlist
--country India
--protocol https
--age 12
--latest 15
--sort rate
EOF
if systemctl start reflector.service; then
  note "mirrorlist refreshed ($(grep -c '^Server' /etc/pacman.d/mirrorlist) servers)"
else
  warn "reflector failed; the previous mirrorlist is still in place"
  cp /etc/pacman.d/mirrorlist.orig /etc/pacman.d/mirrorlist
fi
systemctl enable reflector.timer

step "paru (AUR helper)"
if command -v paru >/dev/null; then
  note "already installed: $(paru --version | head -1)"
else
  build=$(sudo -u "$U" mktemp -d)
  sudo -u "$U" git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$build/paru-bin"
  (cd "$build/paru-bin" && sudo -u "$U" makepkg --noconfirm)
  pacman -U --noconfirm "$build"/paru-bin/paru-bin-[0-9]*.pkg.tar.zst
  rm -rf "$build"
  note "installed: $(paru --version | head -1)"
fi

step "Clock, hostname, locale"
timedatectl set-timezone Asia/Kolkata
timedatectl set-ntp true
hostnamectl hostname carbon
timedatectl | sed -n '1p;4,6p' | sed 's/^/    /'
localectl status | head -1 | sed 's/^/    /'

###############################################################################
# Phase 2: access
###############################################################################

step "SSH: key login only, dev24k only"
ak=/home/$U/.ssh/authorized_keys
if [[ ! -s $ak ]]; then
  echo "No $ak: turning passwords off now would lock you out. Stopping."
  exit 1
fi
note "authorized key: $(ssh-keygen -lf "$ak" | head -1)"
put /etc/ssh/sshd_config.d/10-carbon.conf 644 <<'EOF'
# carbon: key login only, for dev24k only. sshd uses the first value it reads,
# so this 10- file wins over the 20- and 99- drop-ins that follow it.
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
PermitRootLogin no
AllowUsers dev24k
EOF
sshd -t
systemctl reload sshd
# Display only: the settings are already live. A problem here is a warning.
if eff=$(sshd -T 2>&1); then
  # Case-insensitive: OpenSSH 10 prints these in CamelCase (PermitRootLogin).
  grep -iE '^(passwordauthentication|kbdinteractiveauthentication|authenticationmethods|permitrootlogin|allowusers) ' <<<"$eff" |
    sed 's/^/    /' || warn "sshd -T printed none of the expected settings"
else
  warn "sshd -T exited non-zero: $(head -3 <<<"$eff" | tr '\n' ' ')"
fi
note "open sessions stay connected; only new logins need the key"

step "Linger: dev24k's user services run from boot, logged in or not"
loginctl enable-linger "$U"
note "Linger=$(loginctl show-user "$U" -p Linger --value)"

step "Network: boot waits for the wired link only, not the unused Wi-Fi"
wait_online=/usr/lib/systemd/systemd-networkd-wait-online
if [[ -x $wait_online ]]; then
  put /etc/systemd/system/systemd-networkd-wait-online.service.d/50-carbon-any.conf 644 <<EOF
[Service]
ExecStart=
ExecStart=$wait_online --any
EOF
fi

step "Tailscale: IP forwarding for the exit node and subnet route"
put /etc/sysctl.d/60-carbon-forwarding.conf 644 <<'EOF'
# Tailscale exit node and subnet router (192.168.31.0/24).
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -q -p /etc/sysctl.d/60-carbon-forwarding.conf
systemctl enable --now tailscaled
note "login happens at the end of the script"

step "Firewall rules (written now, switched on at the end)"
put /etc/nftables.conf 644 <<EOF
#!/usr/bin/nft -f
# carbon firewall. It owns only the "inet carbon" table, so the tables Docker
# and Tailscale create for themselves survive a reload. (Arch's stock file
# starts with "flush ruleset", which would delete theirs.)
destroy table inet carbon

table inet carbon {
  chain input {
    type filter hook input priority filter; policy drop;

    ct state established,related accept
    ct state invalid drop
    iif lo accept
    meta l4proto { icmp, ipv6-icmp } accept

    iifname "$LAN_IF" udp dport { 68, 546 } accept comment "DHCP replies"
    iifname "$LAN_IF" ip saddr $LAN_NET tcp dport 22 accept comment "SSH from the LAN"
    iifname "tailscale0" tcp dport 22 accept comment "SSH over Tailscale"
    udp dport 41641 accept comment "Tailscale direct connections"
    iifname "docker0" accept comment "containers reaching services on carbon"
    iifname "br-*" accept comment "compose networks reaching services on carbon"

    # Everything else is dropped. Log a few per minute for: journalctl -k --grep nft-refused
    limit rate 6/minute burst 10 packets log prefix "nft-refused: " level info
  }

  chain forward {
    type filter hook forward priority filter; policy drop;

    ct state established,related accept
    iifname "tailscale0" accept comment "exit node and subnet route"
    iifname "docker0" accept comment "containers reaching out"
    iifname "br-*" accept comment "compose networks reaching out"
  }
}
EOF
# Arch's nftables.service loads the file and exits; it has no ExecStop, so it
# never flushes Docker's or Tailscale's tables. An ExecStop here would run the
# moment the oneshot exits and delete the table it just loaded.
rm -f /etc/systemd/system/nftables.service.d/50-carbon.conf
rmdir /etc/systemd/system/nftables.service.d 2>/dev/null || true
nft -c -f /etc/nftables.conf && note "rules parse cleanly"

###############################################################################
# Phase 3: safety net
###############################################################################

step "linux-lts as the fallback kernel"
if [[ ! -f /boot/EFI/Linux/arch-linux-lts.efi ]]; then
  mkinitcpio -p linux-lts
fi
bootctl set-default arch-linux.efi
ls -1 /boot/EFI/Linux/ | sed 's/^/    /'
note "normal boots use arch-linux.efi; a one-off LTS test boot comes after this script"

step "Swap: zram at half of RAM first, then a 16 GB swapfile"
put /etc/systemd/zram-generator.conf 644 <<'EOF'
# Compressed swap in RAM, used before the swapfile.
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
if [[ ! -f /swapfile ]]; then
  mkswap --file /swapfile --size 16G
fi
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap defaults,pri=10 0 0' >>/etc/fstab
swapon --show=NAME | grep -qx /swapfile || swapon -p 10 /swapfile
systemctl daemon-reload
systemctl restart systemd-zram-setup@zram0.service || warn "zram resize applies at next boot"
put /etc/sysctl.d/70-carbon-memory.conf 644 <<'EOF'
# Tuned for zram as the first swap (values from the Arch wiki zram page):
# swapping to compressed RAM is cheaper than dropping file cache.
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
sysctl -q -p /etc/sysctl.d/70-carbon-memory.conf
swapon --show | sed 's/^/    /'

step "fstrim weekly on the SSD"
systemctl enable --now fstrim.timer
note "$(systemctl list-timers fstrim.timer --no-legend | awk '{print "next run:", $1, $2, $3}')"

step "Resource limits: keep SSH alive, cap agents and containers"
# Everything you and the agents run lives in user.slice. Above 80% of RAM it
# is slowed down and pushed to swap; at 90% the kernel kills inside it only.
put /etc/systemd/system/user.slice.d/50-carbon-limits.conf 644 <<'EOF'
[Slice]
MemoryHigh=80%
MemoryMax=90%
CPUWeight=50
IOWeight=50
EOF
# Containers go here once Docker is set up (daemon.json cgroup-parent).
put /etc/systemd/system/docker.slice 644 <<'EOF'
[Unit]
Description=Docker containers (capped so they cannot starve the system)

[Slice]
MemoryHigh=60%
MemoryMax=75%
CPUWeight=50
IOWeight=50
EOF
# System services keep 1 GB that user work can never take.
put /etc/systemd/system/system.slice.d/50-carbon-reserve.conf 644 <<'EOF'
[Slice]
MemoryMin=1G
EOF
put /etc/systemd/system/sshd.service.d/50-carbon-lifeline.conf 644 <<'EOF'
# The daemon only: login sessions move to user.slice. No OOMScoreAdjust here,
# because sshd hands its own value down to every session it starts.
[Service]
MemoryMin=64M
CPUWeight=1000
EOF
put /etc/systemd/system/tailscaled.service.d/50-carbon-lifeline.conf 644 <<'EOF'
[Service]
MemoryMin=128M
CPUWeight=1000
OOMScoreAdjust=-900
EOF
systemctl daemon-reload
for cg in user.slice system.slice; do
  note "$cg: memory.high=$(cat /sys/fs/cgroup/$cg/memory.high) memory.max=$(cat /sys/fs/cgroup/$cg/memory.max) memory.min=$(cat /sys/fs/cgroup/$cg/memory.min) cpu.weight=$(cat /sys/fs/cgroup/$cg/cpu.weight)"
done

step "earlyoom: kill the biggest runaway before the machine freezes"
# SIGTERM when available RAM < 5% and free swap < 25%; SIGKILL at 2% / 10%.
# Never touches SSH, systemd, Tailscale, Docker or tmux. Prefers browsers and
# compilers. Your agents (node, claude, codex) are not preferred, only not
# protected: the biggest offender goes first.
put /etc/carbon/earlyoom.env 644 <<'EOF'
EARLYOOM_ARGS="-r 3600 -m 5,2 -s 25,10 --avoid ^(sshd|sshd-session|sshd-auth|systemd|systemd-.*|tailscaled|dockerd|containerd|containerd-shim.*|earlyoom|tmux.*)$ --prefer ^(chrome|chromium|headless_shell|cc1plus|rustc)$"
EOF
put /etc/systemd/system/earlyoom.service.d/50-carbon.conf 644 <<'EOF'
[Service]
EnvironmentFile=
EnvironmentFile=/etc/carbon/earlyoom.env
ExecStart=
ExecStart=/usr/bin/earlyoom $EARLYOOM_ARGS
EOF
systemctl daemon-reload
systemctl enable earlyoom
systemctl restart earlyoom
sleep 1
journalctl -u earlyoom -n 4 -o cat --no-pager | sed 's/^/    /'

step "Limits: open files, file watchers, /tmp size, journal size"
for scope in system user; do
  put /etc/systemd/$scope.conf.d/50-carbon-nofile.conf 644 <<'EOF'
[Manager]
DefaultLimitNOFILE=65536:524288
EOF
done
put /etc/sysctl.d/70-carbon-watchers.conf 644 <<'EOF'
# Vite, tsc --watch, editors and agents each hold many inotify watches.
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
EOF
sysctl -q -p /etc/sysctl.d/70-carbon-watchers.conf
put /etc/systemd/system/tmp.mount.d/50-carbon-size.conf 644 <<'EOF'
# /tmp lives in RAM; 25% (4 GB) instead of the default 50%.
[Mount]
Options=mode=1777,strictatime,nosuid,nodev,size=25%%,nr_inodes=1m
EOF
mount -o remount,size=25% /tmp || warn "/tmp resize applies at next boot"
put /etc/systemd/journald.conf.d/50-carbon.conf 644 <<'EOF'
# Three months of logs on disk, at most 2 GB, never filling the last 5 GB.
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemKeepFree=5G
RuntimeMaxUse=128M
MaxRetentionSec=3month
RateLimitIntervalSec=30s
RateLimitBurst=1000
EOF
systemctl daemon-reexec
systemctl restart systemd-journald
# Weekly: keep the last 3 versions of each package, enough to downgrade one.
systemctl enable --now paccache.timer
note "/tmp: $(findmnt -no SIZE /tmp); open-file limit applies to new logins after the reboot"

step "BFQ I/O scheduler on spinning disks (makes IOWeight count on the HDD)"
put /etc/udev/rules.d/60-carbon-ioscheduler.rules 644 <<'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
for d in /sys/block/sd?; do
  if [[ $(<"$d/queue/rotational") == 1 ]]; then
    echo bfq >"$d/queue/scheduler" || warn "could not set bfq on ${d##*/}"
    note "${d##*/}: $(<"$d/queue/scheduler")"
  fi
done

step "atop: a system snapshot every 5 minutes, kept 28 days"
if [[ -f /etc/default/atop ]]; then
  sed -i -E 's/^LOGINTERVAL=.*/LOGINTERVAL=300/; s/^LOGGENERATIONS=.*/LOGGENERATIONS=28/' /etc/default/atop
else
  put /etc/default/atop 644 <<'EOF'
LOGOPTS=""
LOGINTERVAL=300
LOGGENERATIONS=28
EOF
fi
for u in atop.service atopacct.service atop-rotate.timer; do
  systemctl enable --now "$u" || warn "$u not available"
done
note "read history later with: atop -r"

step "Phone alerts through ntfy"
if [[ ! -s /etc/carbon/ntfy-topic ]]; then
  echo "carbon-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')" >/etc/carbon/ntfy-topic
fi
chmod 600 /etc/carbon/ntfy-topic

put $LIB/notify 755 <<'EOF'
#!/bin/bash
# notify TITLE MESSAGE [PRIORITY] [TAGS]   sends one ntfy push to your phone.
# The topic name is the only secret; it lives in /etc/carbon/ntfy-topic.
set -u
topic=$(</etc/carbon/ntfy-topic) || exit 1
exec curl -fsS --max-time 15 --retry 2 -o /dev/null \
  -H "Title: $1" -H "Priority: ${3:-default}" -H "Tags: ${4:-computer}" \
  -d "$2" "https://ntfy.sh/$topic"
EOF

# Any system service that fails -> alert. Only the unit name and its result
# leave the machine, never log lines.
put $LIB/notify-failure 755 <<'EOF'
#!/bin/bash
unit="$1.service"
result=$(systemctl show -p Result --value "$unit" 2>/dev/null)
exec /usr/local/lib/carbon/notify "carbon: $unit failed" \
  "Result: ${result:-unknown}. Look with: journalctl -u $unit -b" high rotating_light
EOF
put /etc/systemd/system/carbon-notify-failure@.service 644 <<'EOF'
[Unit]
Description=Phone alert: %i failed

[Service]
Type=oneshot
ExecStart=/usr/local/lib/carbon/notify-failure %i
EOF
put /etc/systemd/system/service.d/90-carbon-onfailure.conf 644 <<'EOF'
# Top-level drop-in: applies to every system service.
[Unit]
OnFailure=carbon-notify-failure@%N.service
EOF
# Same file name, more specific directory: the alert unit itself has no
# OnFailure, so a failing alert cannot trigger another alert.
put /etc/systemd/system/carbon-notify-failure@.service.d/90-carbon-onfailure.conf 644 <<'EOF'
[Unit]
OnFailure=
EOF

# Disk filling up -> one alert at 85%, re-armed once it drops below 80%.
put $LIB/disk-check 755 <<'EOF'
#!/bin/bash
mkdir -p /run/carbon
for m in / /srv/bulk; do
  mountpoint -q "$m" || continue
  pct=$(df --output=pcent "$m" | tail -1 | tr -dc 0-9)
  flag=/run/carbon/disk-$(systemd-escape -p "$m")
  if (( pct >= 85 )) && [[ ! -e $flag ]]; then
    /usr/local/lib/carbon/notify "carbon: $m is ${pct}% full" \
      "Free space on $m is running out." high floppy_disk && touch "$flag"
  elif (( pct < 80 )); then
    rm -f "$flag"
  fi
done
EOF
put /etc/systemd/system/carbon-disk-check.service 644 <<'EOF'
[Unit]
Description=Phone alert when a disk passes 85%

[Service]
Type=oneshot
ExecStart=/usr/local/lib/carbon/disk-check
EOF
put /etc/systemd/system/carbon-disk-check.timer 644 <<'EOF'
[Unit]
Description=Check disk space every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

# earlyoom or the kernel killed something -> alert (at most once a minute).
put $LIB/oom-watch 755 <<'EOF'
#!/bin/bash
last=0
journalctl -f -n0 -o cat _SYSTEMD_UNIT=earlyoom.service + _TRANSPORT=kernel |
  while IFS= read -r line; do
    case $line in
      *"sending SIG"* | *"Out of memory"* | *"Killed process"*) ;;
      *) continue ;;
    esac
    now=$(date +%s)
    (( now - last < 60 )) && continue
    last=$now
    /usr/local/lib/carbon/notify "carbon: memory ran out" \
      "${line%%, cmdline*}" high warning
  done
EOF
put /etc/systemd/system/carbon-oom-watch.service 644 <<'EOF'
[Unit]
Description=Phone alert when a process is killed for memory
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/lib/carbon/oom-watch
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Carbon came back after a reboot or power cut -> alert.
put /etc/systemd/system/carbon-boot-notify.service 644 <<'EOF'
[Unit]
Description=Phone alert that carbon has booted
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/usr/local/lib/carbon/notify "carbon is up" "Booted $(uname -r)."'

[Install]
WantedBy=multi-user.target
EOF

# Disk health: short self-test daily at 02:00, long one on Sundays at 03:00.
# A failing attribute or a temperature of 60°C or more -> alert.
[[ -f /etc/smartd.conf.orig ]] || cp /etc/smartd.conf /etc/smartd.conf.orig 2>/dev/null || true
put /etc/smartd.conf 644 <<'EOF'
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../7/03) -W 0,50,60 -m <nomailer> -M exec /usr/local/lib/carbon/smartd-notify
EOF
put $LIB/smartd-notify 755 <<'EOF'
#!/bin/bash
exec /usr/local/lib/carbon/notify "carbon: disk warning ${SMARTD_DEVICE:-}" \
  "${SMARTD_MESSAGE:-smartd reported a problem}" urgent warning
EOF

systemctl daemon-reload
systemctl enable --now smartd carbon-disk-check.timer carbon-oom-watch.service
systemctl enable carbon-boot-notify.service
note "smartd watching: $(journalctl -u smartd -b -o cat --no-pager | grep -oE '^Device: /dev/sd[a-z]' | sort -u | tr '\n' ' ' || true)"

###############################################################################
# Interactive steps
###############################################################################

step "Tailscale login"
if tailscale status >/dev/null 2>&1; then
  note "already logged in"
else
  note "First, in https://login.tailscale.com/admin/machines remove the old"
  note "offline 'carbon' machine, so this one gets the name carbon, not carbon-1."
  read -rp "    Press Enter once that is done: " _
fi
note "If a login URL appears, open it on nukebyte."
tailscale up --hostname=carbon --advertise-exit-node --advertise-routes="$LAN_NET"
note "Tailscale IP: $(tailscale ip -4)"
note "Still to do in the admin console, on the carbon machine:"
note "  - Edit route settings: approve the subnet route and the exit node"
note "  - Disable key expiry (otherwise carbon drops off the tailnet in 180 days)"

step "Firewall on"
systemctl enable nftables
systemctl restart nftables
if nft list table inet carbon >/dev/null 2>&1; then
  note "firewall active"
else
  echo "The carbon table did not load; see: journalctl -u nftables -b. Stopping."
  exit 1
fi
systemctl stop carbon-fw-revert.timer 2>/dev/null || true
systemd-run --quiet --unit=carbon-fw-revert --on-active=10min \
  /usr/bin/nft destroy table inet carbon
note "Safety switch: the firewall turns itself off in 10 minutes unless you keep it."
note "Ask Claude to check SSH over the LAN and over Tailscale now."
read -rp "    Type keep once both work (anything else lets it switch off): " ans
if [[ $ans == keep ]]; then
  systemctl stop carbon-fw-revert.timer
  note "kept. It loads at every boot."
else
  warn "the firewall switches off in under 10 minutes; re-run the script to try again"
fi

step "Phone test"
note "In the ntfy app (Android or iOS): + > server ntfy.sh > topic:"
echo
echo "        $(</etc/carbon/ntfy-topic)"
echo
note "Treat that name like a password: anyone who knows it can read and send alerts."
read -rp "    Press Enter once you are subscribed: " _
$LIB/notify "carbon: alerts work" "This is the setup test." default white_check_mark &&
  note "test sent"

###############################################################################
step "Summary"
note "kernel:   $(uname -r)   default boot entry: $(bootctl status 2>/dev/null | awk -F': ' '/Default Entry/ {print $2}')"
note "time:     $(date)"
note "memory:"; free -h | sed 's/^/      /'
note "swap:";   swapon --show | sed 's/^/      /'
note "tailscale: $(tailscale ip -4 2>/dev/null)"
note "failed units: $(systemctl --failed --no-legend | wc -l)"
echo
echo "Next: reboot once so every limit takes effect (sudo reboot)."
echo "After that, test the LTS kernel once:"
echo "    sudo systemctl reboot --boot-loader-entry=arch-linux-lts.efi"
echo "It boots LTS that one time; the boot after goes back to the normal kernel."
echo "=== carbon-setup finished $(date -Is)"
