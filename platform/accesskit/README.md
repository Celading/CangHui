# AccessKit semantic tree bridge

This optional C bridge projects CangHui semantic snapshots into AccessKit C
0.23.0 trees. It does not register a platform adapter, load a library, start a
listener, or enable a debug control channel. It is not yet a complete native
accessibility provider or part of the default SDK dependency closure.

Supply the upstream source at commit
`0824c4a1e3a4d13ce5582df20e394fba49485a15` and a matching native library:

```sh
bash platform/accesskit/test.sh /path/to/accesskit-c /path/to/native /tmp/chui-ak-test
```

The Linux test builds the shared bridge plus an AddressSanitizer/UndefinedBehaviorSanitizer
test executable. It uses the supplied C header, not copied enum values or
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
responsibility. This bridge does not supply DPI transforms, numeric ranges, text
runs/selection geometry, IME, reader speech or window registration/teardown.
Those are separate integration requirements, not implied by a valid tree.

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
