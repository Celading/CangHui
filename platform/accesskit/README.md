# AccessKit semantic tree bridge

This optional C bridge projects CangHui semantic snapshots into AccessKit C
0.23.0 trees. The separate `unix_adapter` provides optional Linux native adapter
registration and a bounded action inbox. Neither loads libraries nor enables a
debug control channel. Desktop hosts now provide an optional
`DesktopAccessibilityFactory`/`DesktopAccessibilityAdapter` lifecycle port.
The opt-in Linux `linuxAccessKitAccessibility(nativeLibrary, bridgeLibrary)`
factory loads explicit trusted absolute paths and connects this bridge to either
desktop host. The factory currently requires measured X11 screen geometry;
multiline text, glyph geometry, native selection editing, other geometry backends and SDK delivery remain open;
this preview is not a complete reader SDK or part of the default dependency closure.

Supply the upstream source at commit
`0824c4a1e3a4d13ce5582df20e394fba49485a15` and a matching native library:

```sh
bash platform/accesskit/test.sh /path/to/accesskit-c /path/to/native /tmp/chui-ak-test
```

The Linux test builds the shared bridge plus an AddressSanitizer/UndefinedBehaviorSanitizer
test executables (tree validation and adapter lifecycle). It uses the supplied C header, not copied enum values or
handwritten upstream structs. This does not verify the supplied library's publisher,
minimum OS, transitive licenses or deployment closure. AccessKit source and binary
are not vendored by this directory. See the upstream MIT/Apache-2.0 and included
third-party notices when preparing an eventual native distribution.

## Integration contract

1. Keep `SemanticRuntime` as the semantic fact owner. Use `SemanticNativeSession`
   for native IDs and lifetime; never derive native IDs from array indexes.
2. Create a tree transaction, then add every committed node in semantic order.
   Pass parent native IDs, owned strings, rectangle and explicit state/action bits
   from `semantic_bridge.h`. Parent nodes may arrive after their children.
3. `finish` consumes the transaction on success and failure. Only a non-null update
   can transfer to AccessKit. `free` abandons an unfinished transaction. Do not use
   a potentially null result directly in a callback that forbids null returns.
4. Route native actions through the existing owner queue and final semantic
   dispatcher; tree construction cannot invoke application callbacks.

Limits are 4096 semantic nodes, 64 non-root ancestors and 1 MiB combined UTF-8
strings. Invalid UTF-8, duplicate/reserved IDs, unknown parents, cycles, conflicting
focus, non-finite/negative geometry or unknown bit flags reject the whole update.
Input C pointers must still be valid; the bridge cannot validate arbitrary addresses.
String adapters must reject embedded NUL bytes before converting managed strings
to this NUL-terminated interface; otherwise those strings would be truncated.
Upstream allocation failure/abort behavior is not replaced by a recovery promise.

Known standard roles map explicitly; custom roles remain groups, not invented
buttons. Checkbox/radio/switch selection maps to toggled state; other selection
and expansion preserve unknown versus false. Disabled nodes expose no actions;
readonly nodes retain declared Focus only. Password values are redacted again.
Focus, Activate, Increment and Decrement map to native actions. AccessKit 0.23 has
no generic Dismiss equivalent; it is not mislabeled as Collapse or HideTooltip.

Rectangle conversion to the native adapter coordinate space remains the host's
responsibility. Tree projection does not supply DPI transforms, numeric ranges,
glyph/selection geometry, IME or reader speech. Those remain separate
integration requirements, not implied by a valid tree.

## Single-line text reading

The Linux factory projects plain single-line `TextField` values through the
additive `chui_ak_tree_text` and `chui_ak_tree_selection` symbols. Rebuild the bridge with this loader;
an older ABI1 bridge missing either symbol fails before adapter creation. Existing
ABI1 call signatures are unchanged.

Character spans reuse CangHui's `GraphemeIndex`, the editor's selection-boundary
owner. Combining sequences and ZWJ emoji are not split into scalar-sized editing
units. AT-SPI text offsets/counts are Unicode scalar offsets, converted by
AccessKit from those spans; they are not UTF-8 byte offsets or grapheme counts.
Empty values also expose Text. Passwords never receive a text run.

The stock controls publish sorted UTF-8 `selectionStart`/`selectionEnd` and an
optional `selectionFocus`, the actual caret endpoint. The Linux loader converts
exact editor boundaries into native anchor/focus indices. A reversed selection
keeps the same sorted range but has its caret at the start, not the end. Missing
direction, out-of-range endpoints or interior-grapheme positions remain unknown;
they are never clamped or inferred. Passwords redact all three positions.

This is read access, not a text-editing protocol. No SetTextSelection action or
per-character rectangle is invented. Selection follows committed text, not IME
preedit display text; native composition/marked ranges require separate mapping.
`TextArea`, values containing CR/LF, and graphemes longer than AccessKit's
255-byte character-span limit retain normal semantic metadata without this Text
projection. Multi-line/wrapped layout requires a later mapping.

Each generated leaf uses its parent's native ID XOR `2^63`, preserving the
session's identity lifetime without depending on array order. The bridge checks
the entire transaction for semantic/generated ID collisions and rejects them,
including semantic IDs added after a text run. Fields with semantic children are
also rejected rather than flattening their content. Generated leaves have no
actions; existing semantic node/depth/text limits remain, with at most one extra
leaf/value copy per semantic field. C callers supply valid editor boundaries;
the bridge validates total byte lengths and UTF-8 boundaries, not a second
grapheme segmentation algorithm.

## Optional Linux adapter lifecycle

`unix_adapter.h` exposes `new`, `publish`, `needs_refresh`, `refresh`, `focus`, `bounds`, `poll`, `dropped`
and `close` through opaque integer handles. Serialize all calls for a handle on
its UI owner; these public calls are not a concurrently callable owner API.

1. Create one adapter per window. Zero means allocation/capacity failure. There
   are at most 64 live adapters per loaded bridge; handles are never recycled.
2. Build a validated full tree before `publish`. The call always consumes that
   update, including invalid-handle/revision rejection or inactive native state.
   Revisions must increase. A null or rejected tree never reaches the upstream
   non-null update factory. Activation requests defer to an owner publication or
   idle replay; they never enter managed code or build a tree on a foreign thread.
   When `needs_refresh` is true, `refresh` accepts only the CURRENT revision and
   requires the identical cached full tree, not a newly invented semantic frame.
   It always consumes the update, including a request withdrawn by deactivation.
   An unused factory preserves the request; generation tracking prevents a replay
   from acknowledging a newer activation. Ordinary `publish` stays strictly increasing.
3. Poll native actions before advancing the next semantic frame. Each action is
   copied with the last submitted revision at callback ingress. Forward it through
   `SemanticNativeSession.postUnchangedTargetAction`, the existing UI owner queue and final
   `SemanticRuntime` validation. This inbox is not a second UI dispatcher, and
   AT-SPI requests do not carry the reader client's observed tree revision.
4. The inbox holds 128 actions per adapter. Unsupported/root-target/foreign-tree,
   prepublication and overflow requests are dropped; `dropped` is a saturating
   count, not an application callback. Deactivation clears pending inbox entries.
   During publication actions retain the previous revision, never an invented new
   revision; the managed continuity check determines whether they remain valid.
5. Forward actual window focus and, under X11, native outer/inner window bounds.
   Do not invent screen positions on Wayland. The adapter does not convert DPI.
6. Close the semantic session/owner queue, then close the native handle on its
   owner. `close` is idempotent and revokes pending/late callback tokens before
   calling the upstream asynchronous free. Removed handles cannot target newly
   opened windows. Native requests are freed even when their token is revoked.

Keep both bridge and AccessKit libraries loaded until process exit. AccessKit
Unix 0.23.0 destruction sends an asynchronous removal message; it does not join
all callback threads. Token revocation protects state memory, but cannot protect
callback machine code after library unload. No `dlclose` safety is promised.
Tests include deterministic lifecycle doubles and concurrent late-callback stress;
native AT-SPI acceptance is a separate integration check, not inferred from them.

Semantic revisions advance each frame. `postUnchangedAction` can bridge that
timing gap only when every intervening frame was published and its full ordered
semantic content remained identical. Changed-then-restored content, skipped
revisions, disabled/unsupported actions and revoked identities still reject.
The original `postAction` remains strictly revision-bound. A successful native
dispatch receipt is only ingress acknowledgment; inspect owner completion too.
Keep semantic IDs tied to the same user intent; hidden callback changes cannot
be inferred from identical public semantics. Full managed host and platform
input-reliability acceptance remain separate from this bounded continuity rule.

Desktop hosts explicitly use `postUnchangedTargetAction` to tolerate unrelated
geometry-only animation. Every intervening ordered tree must retain all other
semantic content, and the target plus every ancestor must retain their complete
rectangles. A sibling's hover translation can therefore coexist with focus on a
stationary field. Target/ancestor motion, topology changes, any state/value/action
change, missing revisions and changed-then-restored content still reject. This
does not change either older API or bypass the final runtime's source policy.

## Managed loader boundary

The Linux factory checks bridge ABI1 and required typed symbols before creating
an adapter. It rejects NUL text before C-string conversion and caches detached
tree/binding arrays for idle activation. No direct business callback is passed
to AccessKit; copied actions enter the existing host queue and final runtime.
No bridge library is loaded unless the application explicitly calls the factory.

The managed adapter also implements `DesktopAccessibilityGeometryAdapter`.
Both desktop owners supply current `WindowMetrics` and measured X11 client/outer
bounds. Node rectangles use the existing logical-to-backing-pixel transform,
excluding renderer supersampling. Window movement updates the native origin;
resize/scale changes wait for a matching semantic layout publication. Idle replay
keeps the committed tree's transform. Decorators must forward the geometry port.
Unknown global positions are `None`, not `(0,0)`. The current Linux factory rejects
Wayland, unknown positions and unsupported pixel densities rather than publishing
misleading screen rectangles. This is not cross-monitor DPI certification.

Supply matching trusted native and bridge binaries. ABI/symbol checks are NOT
publisher authentication or transitive compatibility verification. ELF dependency
resolution still follows the system loader; do not accept library paths from
untrusted documents or network messages. The default SDK does not yet carry this
dependency or its full transitive licensing/target evidence. Retained loader
references intentionally last until process exit, including partial load failures.

## Upstream AT-SPI state correction

The pinned C release resolves `accesskit_atspi_common` 0.20.0. Its state mapping
reports disabled buttons as Enabled/Sensitive when their role does not support
ReadOnly. This is separate from the bridge's disabled flag and action filtering.
`patches/0001-atspi-disabled-state.patch` separates availability from editability;
it also keeps a non-disabled readonly input Enabled/Sensitive.

Apply this source patch only to the exact 0.20.0 crate (archive SHA256
`c9d47ad644916f6cb7e432a5ca0dbd7cc78281a9772881057bb72d4aadb93257`) using an
explicit Cargo dependency override in an isolated build. Keep both lockfiles and
audit their difference. The patch is not automatically applied by `test.sh`,
and an upstream unpatched library must not be described as passing the disabled
native-state gate. Native distribution/adoption remains a separate step.
