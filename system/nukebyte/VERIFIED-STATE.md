# Verified boot-security state

Last recorded: 2026-08-18. Device: `nukebyte`, ASUS TUF Gaming A15
FA506IC_FA506IC.

## Storage and boot chain

- EFI system partition: `/dev/nvme0n1p1`, mounted at `/boot`.
- LUKS2 root container: `/dev/nvme0n1p2`.
- LUKS UUID: `96427823-4de4-4288-b6d1-42e995ed4d4c`.
- Decrypted root mapping: `luks-96427823-4de4-4288-b6d1-42e995ed4d4c`.
- Filesystem: Btrfs, normal root subvolume `@`, with Limine/Snapper entries.
- Bootloader: Limine 12.5.2; initramfs generator: mkinitcpio 41.1.
- Kernels at verification: `linux-cachyos` 7.1.8-1 and
  `linux-cachyos-lts` 6.18.42-1.

## Secure Boot and unlock model

- `sbctl` reports Setup Mode disabled, Secure Boot enabled, and Microsoft
  vendor trust retained.
- Limine EFI and kernels are signed by the locally managed `sbctl` key set.
- Limine BLAKE2B configuration enrollment is enabled, and the boot config
  includes verification hashes for the kernel, initramfs, and
  `limine-splash.png`.
- mkinitcpio uses `systemd` and `sd-encrypt`.
- A `systemd-tpm2` LUKS token is bound to PCR 7.
- TPM enrollment occupies keyslot 0; the independently tested recovery
  passphrase remains in keyslot 1.
- PCR 4 is deliberately not bound, to avoid routine Limine updates breaking
  automatic unlock. PCR 11 is not used because this is a non-UKI Limine boot.
- `tpm2-measure-pcr=yes` is deliberately absent.

## Final verification evidence

`limine-update` completed successfully, regenerated both CachyOS initramfs
images, enrolled the config checksum, and confirmed the Limine EFI signature.
Every normal and snapshot entry inspected in `/boot/limine.conf` contained:

```text
rd.luks.options=96427823-4de4-4288-b6d1-42e995ed4d4c=tpm2-device=auto
```

No `tpm2-measure-pcr` option was present. A real reboot produced no password
prompt and the early boot log reported automatic discovery of the TPM2 token.

The final known-good LUKS header backup was named
`cachyos-final-tpm-pcr7.img`; its SHA-256 is:

```text
65a1a9b1f7bc5349ff60462eb583a1d37d1f17f78bb443e48d903b6a6c0dc89c
```

The header itself is sensitive and is not stored here. Older header backups
are also sensitive because restoring one may restore historical keyslots.

## Useful read-only checks

```bash
dots machine status nukebyte
sudo dots machine doctor nukebyte
sudo rg -n 'tpm2-measure-pcr|rd\.luks\.options' /boot/limine.conf
sudo cryptsetup luksDump /dev/nvme0n1p2
journalctl -b | rg 'TPM2 token|Automatically discovered security TPM2'
```
