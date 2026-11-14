#!/usr/bin/env bash
# setup/carbon-dev.sh: carbon's development services. Run after setup/carbon.sh.
#
#   - packages for TypeScript, JavaScript and Node development, plus common
#     build tools
#   - Docker, capped by docker.slice, with small logs and a weekly image prune
#   - long-term logs: sysstat, vnstat, core dumps, hardware errors, a hardware
#     inventory at every boot, and the `sysreport` command
#   - the Minecraft Console Client bots and the `mcc` command
#
# Run from a tmux session on carbon:   sudo bash setup/carbon-dev.sh
# What it sets up, and why, is written down in docs/carbon.md.
#
# Safe to re-run. User-level tools (Claude Code, Codex, T3 Code, Node versions
# through fnm) are installed as dev24k, not here; docs/carbon.md lists them.
set -Eeuo pipefail

U=${SUDO_USER:-}
[[ $EUID -eq 0 ]] || { echo "Run it with sudo: sudo bash $0"; exit 1; }
[[ $U == dev24k ]] || { echo "Run it from the dev24k account with sudo."; exit 1; }
[[ $(</etc/hostname) == carbon ]] || { echo "This machine is not carbon."; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)

LOG=/var/log/carbon-setup.log
touch "$LOG" && chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "!! failed at line $LINENO: $BASH_COMMAND"' ERR
echo "=== carbon-dev started $(date -Is)"

n=0
step() { n=$((n + 1)); printf '\n\033[1;34m==> %02d  %s\033[0m\n' "$n" "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
put() { mkdir -p "$(dirname "$1")"; cat >"$1"; chmod "$2" "$1"; note "wrote $1"; }

###############################################################################
step "Packages"
###############################################################################
packages=(
  # Node and JavaScript. nodejs-lts-krypton (Node 24) is the system Node that
  # services and agents find on PATH; fnm switches versions per project.
  nodejs-lts-krypton npm pnpm yarn bun fnm
  # Build tools that native npm modules and other packages expect
  cmake ninja clang
  # Everyday command-line tools
  github-cli jq ripgrep fd fzf btop ncdu lsof strace tree less unzip zip wget
  bind man-db man-pages micro neovim watchexec just shellcheck rsync sqlite
  # Containers
  docker docker-compose docker-buildx lazydocker
  # Long-term logs
  sysstat vnstat lm_sensors dmidecode pciutils usbutils
  # MCC bots: the console, .NET runtime libraries, and polkit for the rule
  # that lets dev24k start and stop the bots
  screen icu krb5 libunwind polkit
)
pacman -S --needed --noconfirm "${packages[@]}"

###############################################################################
step "Docker: containers in docker.slice, small logs, weekly image prune"
###############################################################################
# docker.slice (memory and CPU caps) is created by setup/carbon.sh.
put /etc/docker/daemon.json 644 <<'EOF'
{
  "cgroup-parent": "docker.slice",
  "log-driver": "local",
  "log-opts": { "max-size": "20m", "max-file": "3" }
}
EOF
put /etc/systemd/system/docker-prune.service 644 <<'EOF'
[Unit]
Description=Remove Docker images and build cache unused for a week (never volumes)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker image prune --all --force --filter until=168h
ExecStart=/usr/bin/docker builder prune --all --force --filter until=168h
EOF
put /etc/systemd/system/docker-prune.timer 644 <<'EOF'
[Unit]
Description=Weekly Docker image and build-cache prune

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
usermod -aG docker "$U"
systemctl daemon-reload
systemctl enable docker.service docker-prune.timer
systemctl restart docker.service
systemctl start docker-prune.timer
note "$(docker info --format 'cgroup driver: {{.CgroupDriver}}, log driver: {{.LoggingDriver}}')"
note "$U is in the docker group from the next login"

###############################################################################
step "Long-term logs"
###############################################################################
# CPU, memory, disk and per-interface network every 5 minutes, kept 90 days.
put /etc/systemd/system/sysstat-collect.timer.d/50-carbon.conf 644 <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*:00/5
EOF
if [[ -f /etc/conf.d/sysstat ]]; then
  sed -i -E 's/^HISTORY=.*/HISTORY=90/' /etc/conf.d/sysstat
fi
systemctl daemon-reload
for u in sysstat.service sysstat-collect.timer sysstat-summary.timer; do
  systemctl enable --now "$u" || warn "$u not available"
done

# Data used per interface per hour, day and month.
systemctl enable --now vnstat.service

# Crashed programs keep a compressed core dump (coredumpctl list).
put /etc/systemd/coredump.conf.d/50-carbon.conf 644 <<'EOF'
[Coredump]
Storage=external
Compress=yes
MaxUse=1G
KeepFree=5G
EOF

# Memory and CPU hardware errors (rasdaemon is in the AUR).
if ! pacman -Q rasdaemon >/dev/null 2>&1; then
  sudo -u "$U" paru -S --needed --noconfirm --skipreview rasdaemon || warn "rasdaemon not installed"
fi
if pacman -Q rasdaemon >/dev/null 2>&1; then
  systemctl enable --now rasdaemon.service || warn "rasdaemon did not start"
fi

# A snapshot of the hardware at every boot, so "what changed" after a part or
# firmware swap can be answered from the journal.
put /usr/local/lib/carbon/hardware-inventory 755 <<'EOF'
#!/bin/bash
echo "=== hardware inventory: $(date --iso-8601=seconds) ==="
uname -a
lscpu
free -h
lsblk -e7 -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS
lspci -nnk
lsusb
ip -brief address
dmidecode --type system --type baseboard --type bios
EOF
put /etc/systemd/system/hardware-inventory.service 644 <<'EOF'
[Unit]
Description=Record hardware and network inventory in the journal
After=local-fs.target network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/lib/carbon/hardware-inventory

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable hardware-inventory.service

# One-page summary of the machine right now.
put /usr/local/bin/sysreport 755 <<'EOF'
#!/bin/bash
# sysreport: one-page summary of carbon right now. With sudo it adds disk health.
#
# Where to look when something went wrong:
#   journalctl -b -p warning         warnings and errors since this boot
#   journalctl -b -1 -p err          errors from the previous boot (crashes)
#   journalctl -u <service>          one service's log
#   journalctl -k --grep nft-refused connections the firewall dropped
#   sar -n DEV                       network traffic per interface, every 5 min
#   sar -u / sar -r                  CPU / memory over the day
#   atop -r                          replay per-process usage (t and T to step)
#   vnstat -d / vnstat -m            data used per day / month
#   coredumpctl list                 programs that crashed
#   smartctl -a /dev/<disk>          disk health
section() { printf '\n== %s\n' "$1"; }

echo "$(hostname): $(date --iso-8601=seconds)"
uptime

section "Failed services"
systemctl --failed --no-legend --plain || true

section "Errors since boot (newest 15)"
journalctl -b -p err --no-pager -n 15 -o short-iso || true

section "Processes killed for memory since boot"
journalctl -b --no-pager -o short-iso --grep 'Out of memory|oom-kill|sending SIG' \
  _TRANSPORT=kernel + _SYSTEMD_UNIT=earlyoom.service 2>/dev/null || echo "none"

section "Crashes in the last week"
coredumpctl list --no-pager --since '-7d' 2>/dev/null || echo "none"

section "Disks"
df -h -x tmpfs -x devtmpfs -x efivarfs -x overlay

section "Memory and swap"
free -h
swapon --show

section "Temperatures"
sensors 2>/dev/null | grep -E '^(Tctl|Tccd|edge|Composite|temp1)' || echo "no sensors"

section "Network, last two days"
vnstat -d 2 2>/dev/null || echo "vnstat has no data yet"

if (( EUID == 0 )); then
  section "Disk health"
  for disk in /dev/sd? /dev/nvme?n1; do
    [[ -e "$disk" ]] || continue
    printf '%s: ' "$disk"
    smartctl -H "$disk" | grep -E 'result|Status' || echo "unknown"
  done
else
  printf '\n(run with sudo to include disk health)\n'
fi
EOF

###############################################################################
step "MCC bots"
###############################################################################
MCC_VERSION=20260906-516
MCC_SHA256=d35dbab50db7a48616b9125a23cf8a26addece75e2283c304499ee673da6eda6
MCC_LIB=/usr/local/lib/mcc
MCC_BIN=$MCC_LIB/MinecraftClient-$MCC_VERSION
# Account, MCP port (from 33331 in name order), and start delay. Logging in
# all four at once made the server reject some of them, so they start 20 s
# apart.
mcc_accounts=(
  "dev24k 33331 0"
  "devchaudhary24k 33332 20"
  "hammersamster 33333 40"
  "kartik 33334 60"
)

if [[ ! -x $MCC_BIN ]]; then
  mkdir -p "$MCC_LIB"
  curl -fL --retry 3 -o "$MCC_BIN.part" \
    "https://github.com/MCCTeam/Minecraft-Console-Client/releases/download/$MCC_VERSION/MinecraftClient-$MCC_VERSION-linux-x64"
  echo "$MCC_SHA256  $MCC_BIN.part" | sha256sum -c --quiet
  chmod 755 "$MCC_BIN.part"
  mv "$MCC_BIN.part" "$MCC_BIN"
fi
ln -sfn "$MCC_BIN" "$MCC_LIB/MinecraftClient"
note "MCC $MCC_VERSION (checksum verified)"

# The console runs in GNU screen. screen answers MCC's terminal queries even
# when nobody is attached; dtach doesn't, and the backlog corrupted a bot's
# input. truecolor keeps MCC's colours. (Measured on NixOS; see carbon-nix.)
put "$MCC_LIB/screenrc" 644 <<'EOF'
startup_message off
defscrollback 10000
term screen-256color
truecolor on
EOF
# screen needs its socket directory private to the bots' user.
put /etc/tmpfiles.d/mcc.conf 644 <<EOF
d /run/mcc 0700 $U users -
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/mcc.conf

put /etc/systemd/system/mcc.target 644 <<'EOF'
[Unit]
Description=Minecraft Console Client bots

[Install]
WantedBy=multi-user.target
EOF
for entry in "${mcc_accounts[@]}"; do
  read -r name port delay <<<"$entry"
  dir=/opt/mcc/accounts/$name
  pre_delay=""
  ((delay > 0)) && pre_delay="ExecStartPre=/usr/bin/sleep $delay"
  put /etc/systemd/system/mcc-$name.service 644 <<EOF
[Unit]
Description=Minecraft Console Client ($name)
PartOf=mcc.target
Wants=network-online.target
After=network-online.target tailscaled.service
# Five failures in five minutes means the account or server is broken: stop.
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=$U
Group=users
WorkingDirectory=$dir
# A clear failure instead of MCC writing a default config and logging in as nobody.
ExecStartPre=/usr/bin/test -f $dir/MinecraftClient.ini
$pre_delay
TimeoutStartSec=$((delay + 120))
# -D -m keeps screen in the foreground, so systemd supervises MCC itself.
ExecStart=/usr/bin/screen -c $MCC_LIB/screenrc -D -m -S mcc-$name $MCC_LIB/MinecraftClient $dir/MinecraftClient.ini --Logging.LogToFile=true --Logging.LogFile=console-log.txt --ChatBot.McpServer.Enabled=true --ChatBot.McpServer.Transport.BindHost=127.0.0.1 --ChatBot.McpServer.Transport.Port=$port
# MCC exits cleanly on SIGTERM and flushes SessionCache.db. screen returns 1
# when its child is stopped, which is a normal stop, not a failure.
KillSignal=SIGTERM
SuccessExitStatus=1
TimeoutStopSec=30
Restart=always
RestartSec=15
CacheDirectory=mcc
Environment=DOTNET_BUNDLE_EXTRACT_BASE_DIR=/var/cache/mcc SCREENDIR=/run/mcc TERM=xterm-256color
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/opt/mcc /run/mcc

[Install]
WantedBy=mcc.target
EOF
done

# dev24k may start, stop and restart the bots (and only the bots) without sudo.
put /etc/polkit-1/rules.d/50-mcc.rules 644 <<EOF
polkit.addRule(function (action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "$U") {
    var unit = action.lookup("unit");
    if (unit && (unit.indexOf("mcc-") == 0 || unit == "mcc.target")) {
      return polkit.Result.YES;
    }
  }
});
EOF
install -m 755 "$HERE/mcc" /usr/local/bin/mcc
note "installed /usr/local/bin/mcc"

systemctl daemon-reload
systemctl enable mcc.target
for entry in "${mcc_accounts[@]}"; do
  read -r name _ <<<"$entry"
  systemctl enable "mcc-$name.service"
done
if [[ -d /opt/mcc/accounts ]]; then
  note "accounts dir: $(stat -c '%A %U' /opt/mcc/accounts)"
  systemctl start mcc.target
  note "bots starting, 20 s apart; check with: mcc status"
else
  warn "/opt/mcc is not restored yet; the bots start at the next boot or with: systemctl start mcc.target"
fi

echo
echo "=== carbon-dev finished $(date -Is)"
