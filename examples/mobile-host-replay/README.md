# Mobile Host Replay

This consumer fixture exposes staged Android and provider-owned iOS input-tree
receipts through CangHui kMode without opening a window or generating a package.

```bash
cuic kmode list mobile-host-replay
cuic kmode call mobile-host-replay mobile.demo.host.replay
cuic kmode call mobile-host-replay mobile.demo.host.replay \
  'player.toggle|4|9'
cuic kmode call mobile-host-replay mobile.demo.ios.provider.replay \
  'player.toggle|4|9'
```

The payload accepts one callback per line as
`actionId|lifecycleEpoch|surfaceGeneration`. The response follows
`canghui.mobile-host-replay.v0` and reports whether each callback is current or
stale. The JSON files under `fixtures/` are unsigned consumer package-plan
inputs represented by `canghui.mobile-application-host.v0` staged receipts.
The iOS provider endpoint binds the checked-in UIKit probe/bootstrap/runtime
input tree to the current lifecycle and surface generation. These are not
installable packages or device proof.
