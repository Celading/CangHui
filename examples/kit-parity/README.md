# Same workflow, different Kits

One application-owned library selection flow rendered as a neutral form (`0`),
an Editorial split composition (`1`), or a Glass preview and floating control surface (`2`).
Choose, validate, review, and return use the same state, action IDs and focus order.
The example deliberately depends on both optional packages for comparison; normal applications select only what they use.

```sh
cuic prntx examples/kit-parity parity.editorial --format summary
cuic prnt examples/kit-parity --output editorial.png --frames 4 -- --style 1 --width 960
cuic prnt examples/kit-parity --output glass.png --frames 4 -- --style 2 --width 360 --theme dark --reduced true
```

Run from the framework root using a source-compatible debug CUIC for probes.
`parity.base`, `parity.editorial`, `parity.glass`, `parity.compact` are stable probe entries.
Replay `focus continue`, `key Enter`, `focus choose`, `key Enter`, `focus continue`,
`key Enter`, `focus back`, `key Enter` as separate lines to exercise validation and recovery.
This example performs no file access or network request and is not a finished reader application.

See [basic styles and Kit ownership](../../manual/reference/basic-styles-and-kits.md)
for opt-in dependencies, safe owned-source export and upgrade rules.
