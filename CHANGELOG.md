# Changelog

All notable project changes are documented here.

## [0.1.1] - 2026-08-25

### Fixed

- Rebuild the matching Ubuntu initramfs after installation and rollback so the stock Bluetooth core cannot be loaded before the module override becomes visible.
- Report both the on-disk and currently running Bluetooth module `srcversion` values in diagnostics.
- Document how to detect and repair a stale-initramfs module mismatch after reboot.

## [0.1.0] - 2026-08-21

### Added

- Reproducible external `bluetooth.ko` build for Ubuntu generic 6.17 kernels.
- Backports of two upstream Linux Bluetooth SCO lifetime and connection-race fixes.
- Experimental two-second cleanup delay for pending outgoing SCO/eSCO connections.
- Safe install and rollback scripts that do not unload the live Bluetooth stack.
- Read-only diagnostic collection with Bluetooth MAC address redaction.
- English and Russian documentation of the symptoms, root cause, quality policy, and limitations.

[0.1.0]: https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/releases/tag/v0.1.0
[0.1.1]: https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/releases/tag/v0.1.1
