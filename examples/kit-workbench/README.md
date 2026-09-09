# CangHuiKit workbench

Run from this directory. Use a debug-built CUIC for semantic inspection:

`CANGHUI_CUIC=/absolute/path/to/debug-cuic bash capture-matrix.sh /path/to/evidence`
replays the full matrix below. It writes only to the chosen output and normal CUIC/CJPM build caches.

```bash
cjpm build
cuic prntx . kit.editorial
cuic prntx . kit.editorial --format ascii --columns 100 --rows 32
cuic prntx . kit.editorial --format diff --events $'focus profiles\nkey Right\nfocus start\nkey Enter'
cuic probe run . kit.editorial --events $'focus reshape\nkey Enter\nadvance 230'
cuic prnt macos . --output editorial.png -- --profile 0
cuic prnt macos . --output focused.png -- --profile 1
cuic prnt macos . --output guided-dark.png -- --profile 2 --theme dark
cuic prnt macos . --output compact.png -- --width 390 --height 844
cuic prnt macos . --output reshaping.png --frames 12 -- --auto-reshape true
```

The process supports `--profile 0|1|2`, `--width`, `--height`, `--theme light|dark`
and `--auto-reshape true`. Auto-reshape is a bounded acceptance fixture: it changes
the same property target once after four frames and stops its frame hook. It is
not an external input/control channel. Frame 12 is a sampled frame, not a promise
of a hardware-independent millisecond timestamp; probe `advance` supplies exact time.

Click **Reshape** repeatedly to reverse width, height, padding, color and radius
mid-flight. Hold it to increment the long-press counter without clicking. Change
selection, toggle reduced motion, resize, scroll and keyboard-focus each action.
The screenshot matrix is three compositions × two themes × compact/wide, plus
in-flight/settled motion. These are desktop logical-layout previews, not device proof.

The waveform is original vector drawing code, not a screenshot or external asset.
No runtime Animator is held in the page model: ordinary widget attributes are the
animation targets. `kitIntro` and the stock adaptive grid consume the same model.

`cjpm test` replays selection, interrupted/reversed property targets, composition
switching and the primary action at seven widths (including both sides of the
760/840 breakpoints), all three profiles and both initial themes. A separate
editorial pointer flow checks long-press suppression, move-out cancellation and
keyboard activation against the same model. These are deterministic headless
flows, not physical touch/gamepad or native IME certification. The `profiles`
probe ID addresses the selector without relying on its generated focus key.

The current probe keeps its initial host Theme: toggling a setting in headless
replay alone does not prove live theme/reduced-motion propagation. Verify that
transition in the desktop application, whose event handler updates the host Theme.

Debug desktop runs print `KIT_WORKBENCH_RESULT` on normal exit. The JSON records
final selection, action counters, motion target and requested/applied theme flags.
Use it with the matching Debug CUIC `shell run` and verify both script receipts
and final state; successful event dispatch alone does not prove an action fired.
The applied flags record completed host `setTheme` calls, not pixel or animation
timing proof. Use `prnt` for pixels and timed probe replay for motion progression.
Release builds do not emit this receipt or enable script input.
