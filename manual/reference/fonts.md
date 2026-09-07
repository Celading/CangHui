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

## macOS native layout preview

`DesktopApp` can explicitly enable CoreText before its first `run`:

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
renderers and other platforms return `false` when asked to enable this preview.

For regular and bold runs, one retained CoreText line supplies advances, raster
output and native caret geometry. Registered font files remain the
primary source; ordered fallback descriptors and CoreText's system fallback can
provide missing glyphs and color emoji. The bundled HarmonyOS Sans Regular and
Bold named faces are selected separately. Fallback glyphs can vary with macOS.
Italic, underline and strikethrough still use SDL_ttf for both measurement and
drawing; this preview does not promise all-font style parity.

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

This is not a complete native editor. `TextArea` has not adopted whole-line native
editing geometry; do not use this switch for pages requiring correct bidi TextArea
editing. The TextField IME anchor follows the native caret, but native composition,
candidate-window testing and screen-reader integration still need separate work.
The multi-window host does not yet expose this startup setting.
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
a fallback for both paint and geometry together. This is a native colored-line
interface, not completed TextArea decorations, wrapping or cross-style editing.

## Remaining native-text limits

Mixed-font fallback is not a guarantee of complete Unicode shaping or bidi layout.
In particular, complex clusters that must move together to a fallback face, bitmap
emoji strike scaling on the default SDL path, and cross-style glyph shaping still
require separate backend work and target-platform tests. Prefer keeping a complex cluster in one span and
selecting a face that covers the complete cluster. Grapheme-safe editing and line
breaking are described separately in [text boundaries](text-boundaries.md).
