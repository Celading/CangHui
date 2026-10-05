# Adaptive scrolling

Run with `cuic run .`. Narrow windows scroll horizontally and, only when needed,
vertically. Wide, tall windows show both columns without scrollbars. Buttons remain
clickable; dragging the content locks to one axis and cancels the pending click.
Use `cuic run . -- --narrow` or `cuic run . -- --wide`; add `--dark` for dark mode.

Debug probes: `adaptive-scroll.narrow` (380 × 320) and `adaptive-scroll.wide`
(800 × 700). Inspect with `cuic prntx . adaptive-scroll.narrow`.
See [the scrolling guide](../../manual/guide/how-to/adaptive-scrolling.md) for
state ownership, nested input and opt-in drag limitations.
