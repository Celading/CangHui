---
name: canghui-agent-ui
description: Implement or review a CangHui consumer UI with direct chui dependency boundaries, intrinsic controls, ContentRow alignment, and cuic ASCII/pixel evidence before platform screenshots.
---

# CangHui Agent UI

Use this skill when an agent builds or reviews product UI on CangHui Multiplatform. It is a consumer workflow,
not authority to edit the CangHui framework, dependency cache, sibling repositories, or platform host.

## Mandatory read order

1. `manual/index.md`
2. `manual/getting-started/agent-first-workflow.md`
3. `manual/getting-started/sdk-consumption.md`
4. `manual/guide/how-to/agent-ui-review.md`
5. the one task guide and API page directly needed by the change

Stop if the consumer's registered framework version, `cjpm.lock`, and installed `cuic version` disagree. Report
the mismatch instead of changing framework source or a CJPM cache behind the application owner's back.

## Preflight

Run from the consumer root and record the real results:

```bash
cuic version
cuic doctor <platform> .
cuic build <platform> .
cuic test <platform> .
```

The default dependency is `chui` pinned by `commitId` and `cjpm.lock`. Use a local CangHui path only when the
task explicitly owns framework development or an offline source checkout.

## Layout rules

- Use `ContentRow` for leading/content/trailing information. Do not approximate it with equal distribution.
- Let `Button` and `IconButton` keep intrinsic height. Add `.fillHeight()` only when the design explicitly asks
  for a full-height control, and mention that choice in the receipt.
- Preserve theme padding; do not make a text-tight button. Use `contentPadding` intentionally for slot buttons.
- Use `Icon`, `IconButton`, or generated `Symbol`; do not rely on emoji, text glyphs, or iconfont metrics.
- Use `FlowRow` for variable chips in narrow sidebars and one state-derived theme across every surface.
- Keep title, supporting text, trailing state, and action visually distinct; move long explanation to details/help.

## Evidence order

Prefer deterministic framework evidence before OS capture:

```bash
cuic pview . <probe-id> --columns 96 --rows 32
cuic prnt <platform> . --output artifacts/ui.png
```

`cuic probe ascii` is the pview alias. Probe/pview execution requires a debug cuic; release refusal is expected.
If no probe exists, add stable semantics for the changed view before claiming layout acceptance.

Use an OS or device screenshot only for platform chrome, IME, native menus, system composition, or device-host
integration. It supplements, never replaces, pview/probe and framework capture.

## Acceptance

Check narrow/common/wide viewports and light/dark themes. Return: exact source changes, build/test commands,
ASCII observations, pixel observations when visual output changed, interaction evidence, and every platform/device
gate not replayed. Do not call a screenshot-only review complete.
