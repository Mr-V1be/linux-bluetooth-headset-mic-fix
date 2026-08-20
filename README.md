# Linux Bluetooth Headset Microphone Fix

[![CI](https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/actions/workflows/ci.yml)
[![License: GPL v2](https://img.shields.io/badge/license-GPL--2.0--only-blue.svg)](LICENSE)
[![Status: experimental](https://img.shields.io/badge/status-experimental-orange.svg)](#project-status)

Experimental Linux kernel workaround for Bluetooth headset microphones that work on the first call, then go silent after leaving and rejoining Google Meet, Discord, Zoom, or another voice application.

The confirmed failure is a race in the Linux Bluetooth SCO/eSCO connection lifetime. The controller completes an mSBC eSCO connection after the kernel has already scheduled the pending connection object for immediate deletion. Linux then receives audio for an unknown handle, `btusb` never enables its isochronous USB endpoint, and applications see a microphone that is present but silent.

This project preserves wideband **mSBC** call audio. It does not force CVSD, disable eSCO, pin the headset in call mode, or sacrifice A2DP playback quality.

> [!WARNING]
> This is an experimental kernel-level workaround, currently validated only on the hardware and software listed below. Read the limitations and keep a bootable stock kernel available.

## Symptoms

This project may match your problem when:

- a Bluetooth headset microphone works immediately after pairing or reconnecting;
- the first call works, but the second call is silent;
- reconnecting Bluetooth temporarily restores the microphone;
- PipeWire or the browser still lists the microphone;
- switching between A2DP and HFP/HSP triggers the failure;
- the kernel log contains `SCO packet for unknown connection handle`;
- HCI traces show a successful synchronous connection followed by an orphaned eSCO handle.

It is not intended for missing browser permission, a muted microphone, a broken headset, or systems without Bluetooth SCO/eSCO support.

## Confirmed environment

- Ubuntu 25.10
- Linux `6.17.0-41-generic`
- MediaTek MT7925 Bluetooth (`0489:e111`)
- HUAWEI FreeBuds Pro 4
- PipeWire 1.4.7
- WirePlumber 0.5.15
- BlueZ 5.83
- mSBC / transparent-air-mode eSCO

Reports from other headsets, adapters, distributions, and kernel versions are welcome.

## What the workaround changes

During a rapid HFP socket replacement, Linux can drop the last reference to an outgoing SCO/eSCO connection while HCI setup is still pending. HCI has no command that cancels `Setup Synchronous Connection`, so the controller may still complete it after host-side deletion.

The local workaround delays cleanup of a pending `BT_CONNECT` SCO/eSCO object by the existing `HCI_DISCONN_TIMEOUT` interval (2 seconds). This gives the completion event time to arrive or a replacement socket time to attach. ACL, LE, connected SCO/eSCO, codec selection, and A2DP behavior are unchanged.

The Ubuntu 6.17 backport also includes two upstream SCO lifetime/race fixes:

- [`abd93c85c866`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=abd93c85c8667add738ee82aeab95dd9fc8265a2) — give the socket its own `sco_conn` reference, by Aldo Ariel Panzardo.
- [`8a5b0135d4a5`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?id=8a5b0135d4a5d9683203a3d9a12a711ccec5936b) — fix races in `sco_sock_connect()`, by Cen Zhang.

See [docs/root-cause.md](docs/root-cause.md) for the observed event sequence and evidence.

## Quick diagnosis

The diagnostic script is read-only and redacts Bluetooth MAC addresses by default:

```bash
./scripts/diagnose.sh
```

Attach the generated text file to a bug report. Review it before publishing because hardware names and system versions remain visible.

## Build on Ubuntu 25.10

Install the build dependencies and matching kernel headers:

```bash
sudo apt update
sudo apt install build-essential bzip2 dpkg-dev patch \
  "linux-headers-$(uname -r)"
```

Build against the matching Ubuntu source package:

```bash
./scripts/build-ubuntu.sh
```

The resulting module is written to `dist/<kernel-release>/bluetooth.ko`. The build script verifies the module name and vermagic before accepting it.

### Prebuilt module for the confirmed kernel

Release `v0.1.0` includes an unsigned module for exactly `6.17.0-41-generic`. Do not use it on any other ABI. Building locally is preferred; the prebuilt asset is provided for users on the confirmed Ubuntu kernel.

```bash
git clone --branch v0.1.0 \
  https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix.git
cd linux-bluetooth-headset-mic-fix

curl -LO https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/releases/download/v0.1.0/bluetooth-6.17.0-41-generic.ko
curl -LO https://github.com/Mr-V1be/linux-bluetooth-headset-mic-fix/releases/download/v0.1.0/SHA256SUMS-v0.1.0
sha256sum --check --ignore-missing SHA256SUMS-v0.1.0

sudo env SOURCE_MODULE="$PWD/bluetooth-6.17.0-41-generic.ko" \
  ./scripts/install.sh
sudo reboot
```

The release also contains the patched Bluetooth source bundle corresponding to the binary module.

### Install

```bash
sudo ./scripts/install.sh
sudo reboot
```

The installer backs up any existing override, installs only for the current kernel, runs `depmod`, and never unloads the live Bluetooth stack. After reboot:

```bash
modinfo -n bluetooth
modinfo -F vermagic bluetooth
```

### Uninstall

```bash
sudo ./scripts/uninstall.sh
sudo reboot
```

Uninstall restores a previous override when one existed; otherwise it removes this project's module so the stock Ubuntu module becomes active again.

## Limitations

- Automated building currently supports Ubuntu generic 6.17 kernels only.
- Kernel modules are ABI-specific. Rebuild after every kernel ABI update.
- Unsigned modules do not load with Secure Boot enforcement. The installer refuses that configuration instead of weakening Secure Boot.
- A kernel crash is possible when testing kernel code. Keep another installed kernel in the boot menu.
- The workaround has a narrow real-world validation set and needs broader testing before upstream submission.
- This repository does not install the diagnostic `btusb` module used during the original investigation.

## Quality policy

The project does not use degraded call audio as a workaround:

- `disable_esco=Y`: not used;
- forced CVSD: not used;
- permanent HFP/HSP profile: not used;
- A2DP disabled outside calls: not used.

The expected behavior is high-quality A2DP outside calls and automatic wideband mSBC HFP during calls.

## Help the project

If your microphone has the same first-call/second-call pattern, open a [bug report](../../issues/new?template=bug-report.yml) with:

1. the output from `scripts/diagnose.sh`;
2. headset and Bluetooth adapter models;
3. whether Bluetooth reconnect temporarily fixes it;
4. at least five leave/rejoin results before and after the workaround;
5. confirmation of the active call codec when known.

Please do not post raw `btmon` captures without reviewing them: they can contain device addresses and names.

## Project status

`v0.1.x` is an experimental, Ubuntu-specific proof of the fix. Planned work includes broader kernel compatibility, automated package builds, Secure Boot signing documentation, longer soak tests, and an upstream RFC.

## License and attribution

Kernel-derived patches and module changes are distributed under `GPL-2.0-only`, matching the Linux kernel files they modify. Original upstream authorship and signed-off-by chains are preserved in the referenced patches. Project scripts and documentation are also licensed under `GPL-2.0-only` unless a file says otherwise.

Russian documentation: [README.ru.md](README.ru.md).
