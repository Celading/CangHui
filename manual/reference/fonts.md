# Font Resolution

**English** | [中文](fonts.zh-CN.md)

CangHui ships the unmodified HarmonyOS Sans SC font and uses it as the default
cross-platform text face. Installing the font into the host operating system is
optional.

## Resolution Order

Each text run resolves faces in this order:

1. a family explicitly selected by a component, such as `Label.fontFamily`;
2. a family selected by `Theme.withFontFamily`;
3. a process-wide application family selected by `Fonts.useApplicationFamily`;
4. the packaged HarmonyOS Sans SC fallback;
5. a platform system UI font.

Families in the first three tiers must be registered with `Fonts.register`.
Unknown or unreadable files are skipped. On a live SDL_ttf renderer, CangHui
checks glyph coverage for the complete text run and advances to the next face
when the current face is incomplete.

If no single face covers the run, the live backend combines the usable faces in
that same order through an SDL_ttf fallback chain, with matching sizes and styles.
For example, an Arabic-capable application face and the bundled Chinese face can
render one mixed Arabic/Chinese label. Chains own separate native font copies and
are cached; changing another label's family must not mutate an already-shaped
label's fallback configuration. Unknown glyphs still use the missing-glyph marker
when none of the supplied fonts covers them.

For `.bold()`, CangHui first selects a real `Bold` named instance carried by a
variable font (the bundled HarmonyOS Sans SC includes one), then tries a
separate bold companion file, and only then synthesizes bold on the selected
base face. The family/fallback order therefore stays unchanged when weight
changes.

```cangjie
Fonts.register("brand", "assets/fonts/Brand-Regular.ttf")
let theme = Theme.light().withFontFamily(Some("brand"))
let app = DesktopApp(WindowSpec("Example", 720, 480), theme: theme)
```

Use `Fonts.useApplicationFamily("brand")` when the application wants one default
without coupling it to a particular Theme value. A component-level family still
wins over both defaults.

## Packaging

The integrated `cuic init` command copies the default TTF and license into the
new application's `assets/fonts` directory. `cuic build`, `test`, `run`, and
`prnt` also provide the framework-owned asset path through
`CANGHUI_HARMONYOS_SANS` for the supervised process.

Other build systems should package these files together:

```text
assets/fonts/HarmonyOS_Sans_SC.ttf
assets/fonts/HARMONYOS_SANS_LICENSE.txt
assets/fonts/HARMONYOS_SANS_SOURCE.txt
```

An application host with a different resource layout can call
`Fonts.registerBundledFallback(path)` before creating a window, or set
`CANGHUI_HARMONYOS_SANS` before process startup.

The SDL text engine can also initialize from this packaged fallback or the selected
application family when no supported system font is installed. Configure it before
creating the first window. Existing system-default selection and per-run resolution
order are unchanged. Missing or invalid font files still produce a startup error if
no usable face remains; carrying a font does not guarantee every language's glyphs.

## Diagnostics

`Renderer.fontResolution()` reports the first logical tier. On a live renderer,
`Renderer.fontResolutionForText(text)` also applies glyph coverage and reports
the tier actually selected for that string. For a combined chain it reports its
primary face, **not** a complete per-glyph font map. The recording renderer includes
`resolvedFamily` and `fontSource` in text Draw IR.

```bash
./tools/cuic/bin/cuic font status macos
./tools/cuic/bin/cuic doctor macos --verbose
```

The stable machine-readable contract is
[`canghui.font-resolution.v0`](../../contracts/canghui-font-resolution-v0.json).

## Optional native layout preview

`DesktopApp` can explicitly enable CoreText on macOS or Pango on Linux before its first `run`:

```cangjie
let app = DesktopApp(WindowSpec("Native text", 720, 480))
let enabled = app.usePlatformTextLayout(true)
// Check enabled before calling app.run { ... }.
```

After startup the setter returns `false` without changing the mode. SDL_ttf
remains the default. Custom renderer hosts can set the mode before measuring and drawing:

```cangjie
let enabled = renderer.usePlatformTextLayout(true)
// Inspect enabled; false means this renderer cannot provide the native path.
```

`platformTextLayoutEnabled()` reports the active mode. Passing `false` restores
SDL_ttf. Switching clears measurement caches; do not switch between measurement
and drawing, or toggle it for each label. SDL_ttf remains the default, and headless
renderers, unsupported platforms and Linux hosts missing the required native
libraries return `false` when asked to enable this preview.

For regular and bold runs, one retained native line supplies advances, raster
output and native caret geometry. On macOS, registered font files remain the
primary source; ordered fallback descriptors and CoreText's system fallback can
provide missing glyphs and color emoji. The bundled HarmonyOS Sans Regular and
Bold named faces are selected separately. Fallback glyphs can vary with macOS.
Italic, underline and strikethrough still use SDL_ttf for both measurement and
drawing; this preview does not promise all-font style parity.

Linux requires Pango1.48+ with PangoCairo/PangoFT2, Cairo, Fontconfig, GObject
and GLib system libraries. No additional CJPM dependency is needed; CUIC does
not install these OS packages automatically. The loader checks its required
symbols before enabling the preview. Linux uses only files from the resolved
application/bundled/default font chain, with private per-map aliases preserving
file order even when families share a name. It does not register fonts globally
or discover an unrestricted system fallback cascade. HarmonyOS Sans variable
bold selects weight700; a regular-only font does not gain an invented bold face.
Missing glyphs remain missing until an appropriate font is supplied. In
particular, available monochrome emoji do not imply complete ZWJ/color-emoji support.

Pango byte indices and scalar hit counts are converted internally to the existing
UTF-16 API. Unhinted fractional geometry avoids integer advance rounding when
the raster scale changes. Rasterization still occurs at the requested size,
not by stretching one low-resolution bitmap. Native engines may produce different
pixels on different platforms. Linux rejects embedded NUL and lines over1MiB
with an explicit text error rather than truncating the string. Its line, font-map
and texture references are released on disable/close; native GType libraries
remain process-resident to keep registered callbacks valid.

Linux native test fixtures require `CANGHUI_TEST_PANGO=1`, these libraries,
DejaVu Sans, the bundled HarmonyOS font and an owned display session. Without
that opt-in, ordinary unit-test totals do not prove native Pango coverage.

Native line and texture caches are renderer-owned and released on disable/close.
One raster is limited to 16384 × 4096 pixels and 16 MiB RGBA; an oversized run
throws a text-backend error rather than silently clipping. Wrap or virtualize long
content. Texture scaling follows both render-target axes and the existing clip.

In this mode, `TextField` uses whole-line native geometry for clicks, caret,
horizontal following, selection and visual Left/Right navigation. A bidi boundary
can have two visual positions; a click retains its chosen position. One logical
selection can paint multiple disjoint highlights. Home/End remain logical and
word selection keeps its existing rules. Editing state stays in UTF-8 bytes at
extended-grapheme boundaries; secure fields send only the mask to native layout.

Custom editors can query `Renderer.textCaretPositionsUtf16` (one index or a batch),
`textHitUtf16` and `textSelectionSpansUtf16`. Indices are UTF-16 units; positions
are logical pixels. `None` means unsupported backend/style. An empty native hit
can return `-1`; convert to UTF-8 and normalize to grapheme boundaries before
assigning editing state. The framework uses its internal `NativeTextIndex` for
this; that internal type is not a public custom-editor API.

`Renderer.textRightToLeftUtf16(text, indices)` reads resolved character directions
from that same native line (`true` is RTL). The `NativeTextLineSpec` overload
preserves colored-line layout. Pass exact UTF-16 **character starts**, not UTF-8
bytes, surrogate interiors or the end boundary. Invalid indices throw; an empty
batch is valid, and order/duplicates are preserved. Unsupported backends/styles
return `None`, not guessed LTR values. Direction is per character: an RTL run
may contain LTR numbers, neutral characters follow context, and caret affinity
alone cannot determine direction.
This query does not itself supply screen-reader character bounds.

`TextArea` also uses complete colored display lines for paint, hit testing, caret,
selection, decorations and preedit. Left/Right move visually; Up/Down hit the next
logical row at the current visual x coordinate. Home/End remain logical. Durable
text and undo keep UTF-8 grapheme boundaries; paint/preedit ranges retain exact
scalar offsets. Empty rows and CRLF preserve their positions. Requests are cached
by display text, decoration snapshot and theme color; maximum width is cached by
the actual font environment instead of reshaping the entire document each frame.

Advanced hosts can compare `Renderer.textLayoutEnvironmentKey()` to detect font
chain, registry version, backend and raster-scale changes. This is an in-process
equality key, not something to parse, persist or transmit. Include text, point size
and style in the application's own cache key as well.

This is not complete native-editor certification. SDL composition events already
reach the controls, and the desktop host forwards the caret area to SDL. Real
system-IME/candidate-window testing and screen-reader integration still need work. Soft wrap,
full typography inheritance and incremental long-document edit performance remain
open. The multi-window host does not yet expose this startup setting.
Headless probe rectangles do not verify native glyphs; use `cuic prnt` for pixels.

On Cangjie 1.1.3 / macOS arm64, native pixel tests exposed a GC unwind failure
associated with a generated cross-package FFI accessor. Capture and pixel tests
now share a managed readback method and owned Surface, avoiding that observed
path. This does not repair the compiler/runtime or certify all native call shapes;
the text preview is still not production-editor certification.

### Colored lines for custom hosts

Advanced hosts with a direct `sdl` dependency can use
`sdl.text.NativeTextLineSpec` to freeze one line's source, default RGBA and
foreground ranges into an immutable request:

```cangjie
import sdl.text.{NativeTextLineSpec, NativeTextColorSpan}

let line = NativeTextLineSpec("abc אבג def", red: 30, green: 30, blue: 30,
    colors: [NativeTextColorSpan(1, 5, 230, 70, 40, 255)])
let size = renderer.textSize(line, pointSize: 24.0)
let caret = renderer.textCaretPositionsUtf16(line, Int64(3), pointSize: 24.0)
let drawn = renderer.text(line, 12.0, 20.0, pointSize: 24.0)
```

Ranges use UTF-16 scalar boundaries, never surrogate interiors. Invalid ranges
throw `IllegalArgumentException`. Arrays are copied and later overlapping ranges
win. Default color also belongs to the request; drawing cannot override it.
Color boundaries can change ligatures, emoji clusters and caret positions. Use
the same spec, size, style and font for measurement, drawing, scalar/batched
carets, `textHitUtf16` and `textSelectionSpansUtf16`. Editors must still convert
native indices into their UTF-8 grapheme positions.

Do not use caret rounding to convert color ranges. A valid paint range can start
between `e` and its combining accent, or inside an emoji ZWJ sequence. Convert
each UTF-8 code-point boundary exactly to UTF-16; reject byte/surrogate interiors
and out-of-range offsets rather than expanding or shrinking the range. For
example, in `A😀é`, the accent's UTF-8 range `[6,8)` is UTF-16 `[4,5)`, while
the preceding editor caret is at UTF-8 byte `5`. Retain the encoding index per
source line instead of rescanning the entire line for every decoration.

Specs hold no native pointers; the existing renderer owns line and texture caches.
Rebuild a spec when source or colors change, not for each caret query. Unsupported
backends/styles return `None` or draw `false` without substituting content. Choose
a fallback for both paint and geometry together. TextArea uses it for foreground,
background and underline decorations; that does not add wrapping or arbitrary
mixed-size/style editing.

## Remaining native-text limits

Mixed-font fallback is not a guarantee of complete Unicode shaping or bidi layout.
In particular, complex clusters that must move together to a fallback face, bitmap
emoji strike scaling on the default SDL path, and cross-style glyph shaping still
require separate backend work and target-platform tests. Prefer keeping a complex cluster in one span and
selecting a face that covers the complete cluster. Grapheme-safe editing and line
breaking are described separately in [text boundaries](text-boundaries.md).
