# Mobile Host Replay

This consumer fixture exposes one staged Android input-tree receipt through
CangHui kMode without opening a window or generating an APK.

```bash
cuic kmode list mobile-host-replay
cuic kmode call mobile-host-replay mobile.demo.host.replay
cuic kmode call mobile-host-replay mobile.demo.host.replay \
  'player.toggle|4|9'
```

The payload accepts one callback per line as
`actionId|lifecycleEpoch|surfaceGeneration`. The response follows
`canghui.mobile-host-replay.v0` and reports whether each callback is current or
stale. The JSON files under `fixtures/` are unsigned consumer package-plan
inputs represented by `canghui.mobile-application-host.v0` staged receipts.
They are not installable packages or device proof.
