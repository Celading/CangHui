# Overlay motion replay

This source-owned fixture checks Modal entrance, nested content and a four-line
Toast. It is a regression scene, not a style template. Use a debug CUIC for
semantic inspection; input simulation remains debug-only.

From the framework root:

```bash
cuic pview tools/release-fixtures/overlay-motion overlay.motion --columns 96 --rows 32
cuic prnt macos "$PWD/tools/release-fixtures/overlay-motion" --output /tmp/chui-overlay.png --frames 30
```

The first semantic frame intentionally has an opening dialog: content actions
must not fire before the reveal finishes. Advance the probe by 300 ms for settled
event assertions. Verify Escape during entrance, Confirm after entrance, and
reopening. For accessibility/immediate tests use `Theme.dark(reduceMotion: true)`.
The toast preserves explicit line breaks and fits the fourth-line ellipsis.
