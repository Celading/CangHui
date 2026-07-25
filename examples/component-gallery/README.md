# Component Gallery

This desktop gallery mounts a normal CJPM component package against the common
host, capability, and viewport contracts exported by CangjieGUI.

Run one interactive matrix:

```bash
cjpm run
```

Capture a deterministic target through the framework snapshot argument:

```bash
cjpm run -- --preview desktop --snapshot /tmp/cangjiegui-desktop.bmp
```

Use `--theme light` or `--theme dark` to capture either stable theme endpoint:

```bash
cjpm run -- --preview desktop --theme light --snapshot /tmp/cangjiegui-desktop-light.bmp
```

The Android, HarmonyOS, and iOS entries are common-layout previews. They do not
claim platform runtime, lifecycle, input method, accessibility, packaging, or
device support.
