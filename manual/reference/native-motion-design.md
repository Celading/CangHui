# Native motion design capture

Motion Studio can sample its real SDL renderer and original font to export
measured, editable design observations. Headless snapshots remain deterministic
layout tests; they identify their measurements as heuristic.

```sh
cd examples/motion-lab
cjpm build
cd ../..
python3 scripts/capture-motion-design.py --output /tmp/motion-observations
```

The exporter samples five families, two widths, light/dark and reduced motion at
0,160,480 and1600milliseconds. Native BMP captures accompany settled samples.
The source font and SDL prerequisites follow the normal application setup.

`Renderer.setDrawIrRecording(true)` opts into capturing the owned renderer. Each
switch clears the command log. `ComponentProbe(...,renderer:Some(renderer))`
borrows an already recording renderer synchronously, without closing it. The
caller owns the native thread, window and renderer and must avoid concurrent
rendering. Supplied renderers are labeled `provided-renderer`; text commands
independently identify native versus heuristic metrics, measured size and origin.
Rectangular outlines carry `width` for geometry and `strokeWidth` for line width.

A reviewed design library with native motion support can consume observations:

```sh
node scripts/build-motion-design.mjs --input /tmp/motion-observations \
  --base existing.hmd --source-root . --design-root /path/to/reviewed-design \
  --output /tmp/motion-candidate.hmd
```

This creates a new candidate, preserves existing identities and annotations,
checks source file hashes and embeds the original font with its license. It
never overwrites a file or installs the design library. Typed controls retain
Int64 strings and the source event ownership. Capability rows remain drafts.
A successful compilation or save does not replace actual editor interaction,
font loading, same-state native comparison or target-host acceptance. Unsupported
paint and source behavior remain in the generated proof ledger.

Native soft fills can carry a bounded `canghui.paint-mesh/v1` coverage mesh. Its
relative vertices, per-vertex alpha and triangle indices come from the same cache
used by the native draw pass; a Gaussian blur is not equivalent. Headless samplers
keep `mesh:null`, without allocating native geometry. Importers must retain an
explicit fidelity gap when a native mesh is unavailable. A source-measured text
advance constrains design line width; original font bytes remain unchanged and
raw browser font metrics can still differ from the native backend.
