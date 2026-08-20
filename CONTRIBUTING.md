# Contributing

Thanks for helping validate or improve the project. Reports from different Bluetooth adapters, headsets, distributions, and kernels are especially valuable.

## Before opening an issue

1. Confirm the microphone works at least once after reconnecting Bluetooth.
2. Reproduce the failure with a direct PipeWire recording when possible.
3. Run `./scripts/diagnose.sh` immediately after a failed call.
4. Review the output and remove any remaining private information.
5. Search existing issues for the adapter, headset, and kernel version.

Do not attach raw `btmon` or USB captures until you have removed device addresses and names.

## Validation reports

Run at least five leave/rejoin cycles before and after the workaround. Report every attempt, not only successful ones. If available, include the negotiated codec, HCI synchronous connection result, active SCO count, and `btusb` alternate setting.

Call-audio degradation is outside the acceptance criteria. A proposal that fixes the microphone by forcing CVSD, disabling eSCO, or permanently selecting HFP should be clearly marked as an alternative and will not replace the default mSBC-preserving path.

## Code changes

- Keep scripts compatible with Bash and pass ShellCheck.
- Preserve safe rollback and exact kernel ABI checks.
- Never disable Secure Boot or weaken its policy automatically.
- Keep upstream authorship and commit references intact when backporting.
- Add an SPDX license identifier to new source and script files.
- Explain how the change was validated and on which hardware.

Kernel changes intended for upstream should follow the Linux kernel contribution process and Developer's Certificate of Origin. Repository pull requests alone do not submit a patch to the Linux Bluetooth maintainers.
