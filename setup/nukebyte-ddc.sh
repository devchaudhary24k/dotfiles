#!/usr/bin/env bash
# setup/nukebyte-ddc.sh: make monitor brightness control (DDC/CI) reliable on
# the monitor plugged into nukebyte's NVIDIA GPU.
#
# Run once as root, then reboot:   sudo bash setup/nukebyte-ddc.sh
#
# Plasma's brightness sliders for external monitors go through ddcutil, which
# talks to each monitor over the cable's I2C wires. On the NVIDIA GPU (the MSI
# on DisplayPort) those replies were slow or missing, so PowerDevil sometimes
# dropped the MSI's slider at login. ddcutil's documentation recommends making
# the NVIDIA driver use software I2C at the standard 100 kHz for this.
#
# The driver reads the option when it loads, and the initramfs carries its own
# copy of /etc/modprobe.d (the modconf hook), so the boot images are rebuilt.
# Check after the reboot:   grep RegistryDwords /proc/driver/nvidia/params
# Undo:   sudo rm /etc/modprobe.d/nvidia-ddc.conf && sudo mkinitcpio -P
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run it with sudo: sudo bash $0"; exit 1; }

conf=/etc/modprobe.d/nvidia-ddc.conf
cat >"$conf" <<'EOF'
# Reliable DDC/CI (monitor brightness) on the NVIDIA GPU: software I2C at
# 100 kHz. Installed by setup/nukebyte-ddc.sh in the dotfiles.
options nvidia NVreg_RegistryDwords="RMUseSwI2c=0x01;RMI2cSpeed=100"
EOF
echo "wrote $conf"

mkinitcpio -P
echo
echo "Done. Reboot, then check: grep RegistryDwords /proc/driver/nvidia/params"
