# CangHui Probe Protocol

`cui.probe.v0` is CangHui's deterministic, device-free instrumentation
protocol. It verifies callable behavior, component structure, event routing,
animation samples, and renderer command shape without creating an SDL window.
Pixel output remains the appropriate proof for font appearance, clipping,
platform integration, and final visual review.

## Function Probes

Import the probe macro and annotate a top-level `(String) -> String` function:

```cangjie
import cui.*
import cui.kmode.macros.*

@CuiProbe["settings.reset-preview"]
func resetPreview(payload: String): String {
    // Parse the application's bounded payload and return a stable result.
    "{\"ok\":true}"
}
```

Probe names use dot-separated segments. Each segment starts with a letter and
may contain letters, digits, `-`, or `_`. A generated symbol makes duplicate
names in one compilation scope fail at compile time. The runtime registry
rejects duplicates across loaded packages, and `cuic probe diff` reports all
duplicate locations across recursive local path dependencies before execution.

The annotation does not expose arbitrary functions, shell commands, or file
system access. Only explicitly annotated string-in/string-out functions are
registered.

## Component Probes

Use `ProbeNode` or the `.probe(...)` modifier to publish stable component facts.
`probedAction` records callback activation while preserving the original
action:

```cangjie
@CuiProbe["gallery.primary-button"]
func primaryButtonProbe(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("gallery.primary-button", width: 320.0, height: 120.0).run(script) {
        Button("Run", probedAction("primary-button.click", { => clicks.value += 1 }))
            .key("primary-button")
            .probe(
                "primary-button",
                "Button",
                [ProbeProperty("label", "Run")],
                { => [ProbeProperty("clicks", clicks.value.toString())] }
            )
    }
}
```

Default reports contain only deterministic public facts:

- stable node id, type, parent, child order, properties, and semantic state;
- measured and laid-out rectangles;
- focus, hover, press, disabled, and selected state when supplied;
- routed events, consume results, and callback activations;
- animation id, motion level, duration, curve, logical time, progress, and target;
- Draw IR for scopes, clipping, transforms, paint, text, and symbols.

Object addresses, wall-clock timestamps, and local paths are not emitted.

## Event Scripts

Scripts contain one command per line. Blank lines and lines beginning with `#`
are ignored.

```text
move-in 80 35
press 80 35
advance 60
release 80 35
assert activation primary-button.click 1
assert state primary-button selected true
assert draw text 1
```

Supported commands are:

| Command | Purpose |
|---|---|
| `move-in x y`, `move-out x y`, `move x y`, `hover x y` | Route a pointer move at logical coordinates. |
| `press x y`, `release x y` | Route the primary pointer button. |
| `key name` | Route a supported key such as `Enter`, `Space`, `Tab`, or an arrow key. |
| `focus id` | Move deterministic keyboard focus to a stable id. |
| `text value` | Route text input. |
| `advance ms` | Advance logical animation time and route a frame event. |
| `draw` | Capture another frame without changing logical time. |

Supported assertions are:

```text
assert node <id>
assert state <id> <name> <true|false>
assert property <id> <name> <value>
assert activation <name> <count>
assert event <command-prefix> consumed <true|false>
assert animation <node> <kind> active
assert animation <node> <kind> between <minimum> <maximum>
assert draw <kind> <minimum-count>
```

An assertion failure remains in the JSON report and makes `cuic probe run`
return a nonzero status.

## CLI

```bash
./tools/cuic/bin/cuic probe diff component-gallery
./tools/cuic/bin/cuic probe list component-gallery --json
./tools/cuic/bin/cuic probe describe component-gallery gallery.primary-button --json
./tools/cuic/bin/cuic probe run component-gallery gallery.primary-button \
  --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
  --json
```

Use `--script path/to/events.txt` for a checked-in event script. The stable
report contract is published as
[`contracts/cui-probe-v0.schema.json`](../contracts/cui-probe-v0.schema.json).
