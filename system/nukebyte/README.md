# nukebyte security and recovery profile

Machine: **ASUS TUF Gaming A15 FA506IC**, hostname `nukebyte`.

This public profile records the reproducible part of the machine's boot chain:

- LUKS2 root on the current `/dev/nvme0n1p2`;
- Btrfs root subvolume `@`;
- mkinitcpio with `systemd`, `sd-encrypt`, Plymouth, and the CachyOS Limine
  snapshot overlay drop-in;
- Limine with an enrolled BLAKE2B configuration checksum;
- Secure Boot managed by `sbctl`, retaining Microsoft trust; and
- automatic TPM2 unlock bound to PCR 7, with password recovery retained.

The current LUKS UUID and hardware identity are documented in
`security-profile.conf`. The apply command discovers the live root LUKS device
and UUID instead of blindly reusing those values after a reinstall.

## Commands

```bash
dots machine status nukebyte
dots machine plan nukebyte
sudo ~/.dotfiles/bin/dots machine doctor nukebyte
sudo ~/.dotfiles/bin/dots machine apply nukebyte
```

The ordinary apply operation installs only public configuration and regenerates
Limine/initramfs. It requires the existing `sbctl` keys to have already been
restored securely and refuses Secure Boot Setup Mode.

It also restores the two machine-specific mkinitcpio drop-ins (NVIDIA modules
and the Btrfs snapshot overlay hook) and the Limine reset/enroll hook symlinks.
Existing versions of every changed `/etc` file are copied to timestamped
root-owned backups first.

TPM enrollment is deliberately separate because it mutates the LUKS header:

```bash
sudo ~/.dotfiles/bin/dots machine apply nukebyte \
  --enroll-tpm \
  --header-backup /path/on/encrypted-external-disk/nukebyte-luks-header.img
```

That mode creates a fresh header backup before enrollment, requires Secure Boot
to be enabled, and never removes any LUKS keyslot.

## Never commit these

- `/var/lib/sbctl/keys/` or any Secure Boot private key;
- a LUKS header backup, including historical backups;
- the recovery passphrase or a 1Password export;
- TPM secrets or raw credential material; or
- an unencrypted archive containing any of the above.

Keep the `sbctl` key hierarchy in a separate encrypted backup. Keep LUKS header
backups on protected external storage. Historical headers remain sensitive
because restoring one can restore historical keyslot state.

`VERIFIED-STATE.md` is a sanitized audit record of the working setup. It stores
identifiers, package/config facts, and verification commands—not private keys,
passphrases, token secrets, `/etc/crypttab`, or any LUKS header bytes.

## Recovery order

1. Confirm the recovery passphrase works before modifying keyslots.
2. Restore the encrypted `sbctl` key backup with root-only permissions.
3. Confirm firmware is not in Setup Mode; on this ASUS model retain Microsoft
   trust and do not use `--firmware-builtin`.
4. Run `dots machine plan`, then the public apply operation.
5. Enable Secure Boot in firmware if necessary and verify `sbctl status`.
6. Only then enroll TPM PCR 7 with a fresh external header backup.
7. Reboot once and confirm TPM unlock; also test recovery-password fallback.

This profile can reduce the repeatable Linux-side work to a guarded command,
but it cannot safely automate firmware Setup Mode, recovery-passphrase tests,
restoring private `sbctl` keys, or validating the first reboot. Those remain
intentional recovery gates.
