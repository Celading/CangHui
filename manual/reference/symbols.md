# Symbols

**English** | [中文](symbols.zh-CN.md)

CangHui exposes provider-neutral vector symbols through `SymbolName`,
`Symbol`, `SymbolProvider`, `SymbolAdapter`, and `Symbols`. The core package
contains a small built-in compatibility provider. Material Symbols, Ant Design
Icons, and Arco Design Icons remain separate optional packages.

## Core Use

```cangjie
import chui.*

Symbol(SymbolName("save", provider: "builtin"),
    size: 24.vp, weight: 500.0, accessibilityLabel: "Save")
```

`Icon` and `IconButton` accept either the legacy `IconName` enum or a
`SymbolName`, so existing callers do not need to migrate in one step.

## Icon Selection Rules

Choose an icon by checking the built-in catalog or an adopted provider first,
then declare its meaning with `SymbolName`. Use `IconButton(SymbolName(...))`
for an action and provide a visible `label` or an `accessibilityLabel`.
`.iconSize(...)` changes the drawn square without shrinking the hit target.

Do not replace an available Symbol with a text glyph, emoji, icon font, or a
one-off path drawing. Run `cuic symbol list` to confirm a name and use
`cuic symbol generate` when an application needs a smaller registry. If a
required icon is absent, add an audited catalog entry to the provider with its
source record, then consume it through `SymbolName`; keep variants, direction
mirroring, fallback state, and accessibility metadata in the shared resolution
path.

## Optional Providers

Add only the providers used by the application:

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_symbol_material = { path = "../CangHui/packages/symbol-material" }
canghui_symbol_ant = { path = "../CangHui/packages/symbol-ant" }
canghui_symbol_arco = { path = "../CangHui/packages/symbol-arco" }
```

Inspect the currently adapted inventory and its frozen source revisions:

```bash
./tools/cuic/bin/cuic symbol list --json
./tools/cuic/bin/cuic symbol list material
```

The canonical provider ids are `material`, `ant`, and `arco`. `material-design`,
`antd`, and the common `acro` misspelling are accepted as CLI compatibility
aliases.

## Declared-Subset Generation

Generate one application-owned registry from the symbols actually referenced
by the application:

```bash
./tools/cuic/bin/cuic symbol generate \
  material:add@primary_add ant:check arco:right \
  --output src/generated_symbols.cj \
  --package example_app
```

Call `registerCangHuiSymbols()` once during application startup, before the
first `Symbol` is resolved. The generated file contains only the declared
registry entries and imports only the selected provider packages. Canonical
duplicates and cross-provider export-name collisions fail before source is
written.

Provider catalogs are validated before they can contribute generated Cangjie
imports or type names. Symbol names, variants, and source paths also use a
restricted grammar. The machine-readable catalog and generation receipts are
defined by [`canghui-symbol-v0.schema.json`](../../contracts/canghui-symbol-v0.schema.json).

## Resolution

- A qualified name first passes through its provider adapter, allowing stable
  aliases such as `material:plus` to resolve to `material.add`.
- Unsupported variants degrade to an available provider variant and set
  `SymbolResolution.variantFallback`.
- Directional symbols can mirror automatically in right-to-left contexts.
- Missing symbols use the built-in missing mark by default. Strict mode throws
  a deterministic diagnostic instead.
- Draw IR records requested and resolved names, provider, variant, weight,
  direction, mirroring, accessibility label, and fallback state.

The current optional packages adapt a small audited fixture inventory rather
than bundling each complete upstream collection. Their `UPSTREAM.md`,
`symbols.catalog`, and license files freeze the exact repository revision and
source paths used by that inventory.
