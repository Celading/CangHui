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

Select the theme-adjacent automatic motion expression with `--motion basic`,
`--motion standard`, or `--motion full`. Explicit component animation specs keep
their requested duration and easing:

```bash
cjpm run -- --preview desktop --motion full
```

Open one named specimen category directly with `--section actions`,
`selection`, `navigation`, or `feedback`:

```bash
cjpm run -- --preview harmony --section navigation
```

Capture a deterministic in-progress circular reveal by selecting the target
theme and an early snapshot frame. This route clicks the real theme IconButton,
so the image also contains its local InkWell ripple:

```bash
cjpm run -- --preview desktop --transition-theme light --snapshot-frame 12 \
  --snapshot /tmp/cangjiegui-desktop-reveal.bmp
```

The Android, HarmonyOS, and iOS entries are common-layout previews. They do not
claim platform runtime, lifecycle, input method, accessibility, packaging, or
device support.
