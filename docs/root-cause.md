# Root cause analysis

## User-visible failure

The microphone worked on the first call after connecting the headset. Leaving and immediately rejoining a call made it silent, often in an alternating working/broken pattern. Bluetooth reconnect reset the state and restored the next attempt.

Direct PipeWire recording reproduced the silence, so the browser and meeting application were not the source of the audio loss.

## Observed sequence

In a failing transition:

1. WirePlumber switched from A2DP to the HFP headset profile.
2. BlueZ negotiated wideband mSBC.
3. Linux sent `Setup Synchronous Connection`.
4. A rapid socket replacement dropped the final host reference while the eSCO connection was still `BT_CONNECT`.
5. `hci_conn_drop()` scheduled immediate cleanup.
6. The controller completed the original eSCO setup successfully with transparent air mode and 60-byte packets.
7. Linux no longer had the matching connection object and logged `SCO packet for unknown connection handle`.
8. A replacement setup attempt failed because the controller already had the orphaned synchronous link.
9. `btusb` never observed an active SCO count and therefore did not select the isochronous alternate setting used for microphone traffic.

The important distinction is that the HCI command set can cancel an outgoing ACL connection, but does not provide an equivalent cancellation command for an already-issued `Setup Synchronous Connection`. Immediate host-side deletion therefore races a completion that the controller may still legally report.

## Successful trace characteristics

- synchronous connection complete: success;
- link type: eSCO;
- air mode: transparent;
- RX/TX packet length: 60 bytes;
- active SCO count becomes 1;
- `btusb` selects isochronous alternate setting 6;
- direct PipeWire recording contains microphone samples.

## Failed trace characteristics

- initial synchronous setup is successful at the controller;
- the corresponding host object was already deleted;
- packets arrive for an unknown handle;
- a second setup may report `Unsupported LMP Parameter`;
- active SCO count stays 0 from `btusb`'s perspective;
- no isochronous USB alternate setting is selected;
- direct PipeWire recording contains silence.

## Workaround rationale

For SCO and eSCO objects only, when the last reference is dropped in `BT_CONNECT`, cleanup is delayed by `HCI_DISCONN_TIMEOUT` instead of being scheduled immediately. Two seconds is already an established Bluetooth core timeout and was sufficient for the controller completion or socket replacement in the reproduced race.

No codec parameters are changed. In particular, the workaround does not disable eSCO or force CVSD.

## Validation so far

The original environment repeatedly failed on the second join. With the delayed pending-eSCO cleanup and the two upstream SCO fixes applied, four consecutive leave/rejoin cycles succeeded while kernel instrumentation confirmed an active SCO count and USB alternate setting 6 on every call.

This is promising but not yet enough evidence for a universal fix. Reports from different adapters and headsets should include both successful and failing traces where possible.
