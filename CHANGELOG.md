# Changelog

All notable project changes are documented here.

## [0.1.0] - 2026-08-21

### Added

- Reproducible external `bluetooth.ko` build for Ubuntu generic 6.17 kernels.
- Backports of two upstream Linux Bluetooth SCO lifetime and connection-race fixes.
- Experimental two-second cleanup delay for pending outgoing SCO/eSCO connections.
- Safe install and rollback scripts that do not unload the live Bluetooth stack.
- Read-only diagnostic collection with Bluetooth MAC address redaction.
- English and Russian documentation of the symptoms, root cause, quality policy, and limitations.

[0.1.0]: https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/releases/tag/v0.1.0
