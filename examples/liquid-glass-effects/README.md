# Liquid Glass renderer effects

This example keeps composition in stock `Surface` and lets the optional
`sdl-readback` renderer-effect adapter sample the colour bands already painted
behind the two cards. Run it with a source-built debug CUIC:

```bash
cuic pview . liquid-glass-effects --columns 96 --rows 32
cuic prnt macos . --output liquid-glass-effects.bmp
```

The first adapter uses bounded synchronous SDL readback and a strict per-frame
pixel/effect budget. It proves the provider-neutral lifecycle on the current
macOS SDL renderer; it does not claim native Apple material identity, private
APIs, shape union, or Metal/Vulkan/D3D/GLES/WebGPU backend completeness.

When the adapter is absent, rejects a stale frame, exceeds its budget, or the
user requests reduced transparency, `canghui_style_liquid_glass` keeps the same
content/layout and paints its deterministic SDR/opaque fallback.
