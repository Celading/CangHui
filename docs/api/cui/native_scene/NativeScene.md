# NativeScene

`cui.native_scene` is the SDL-free display-list boundary for embedded mobile
surfaces. It lets Cangjie product code emit deterministic Draw IR while UIKit,
ArkUI or another native host owns pixel presentation.

The package currently provides:

- `NativeScene`, `NativeRect` and `NativeColor`;
- fill, rounded panel, line, circle, text, symbol and clip commands;
- button and progress helpers;
- `NativeScenePointer`, including press, move-out cancellation, release and a
  deterministic synthetic tap used by host acceptance tests;
- a stable `canghui.native-scene.v0` JSON report with Draw IR and hit regions.

The package does not own product state, native text shaping, accessibility,
IME, retained SceneDiff or platform packaging. Consumers import
`cui.native_scene` directly; the umbrella `cui` export remains unchanged while
the mobile renderer is incubating.
