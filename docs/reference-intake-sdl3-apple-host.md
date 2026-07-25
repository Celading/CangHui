# SDL3 Apple Host Reference Intake

## Sources

- `Ravbug/sdl3-sample@d6c3c1b46cfab879a4cae71e3da5fb908dc02563`
  under CC0-1.0.
- `KevinVitale/SwiftSDL@c9c26670c6aaa8130001064e3133a305082f70dc`
  under MIT.

The sources were reviewed as design references. No Swift or C++ source was
copied into CangjieGUI.

## Adopted

### Two host modes

An SDL3 application and an embedded native view are different deployment
shapes and should not be forced through one fake window model:

- `OwnedWindow`: SDL3 owns application callbacks, event pumping, the window
  and renderer. This is the preferred route for a standalone CangjieGUI app.
- `EmbeddedSurface`: UIKit, Harmony or another application owns the native
  view and forwards a generation-bearing surface to CangjieGUI.

Both modes share `HostApplicationLoop`, host lifecycle/input services and the
same Cangjie widget/layout tree.

### Callback lifecycle

SDL3's `SDL_AppInit`, `SDL_AppIterate`, `SDL_AppEvent` and `SDL_AppQuit`
separate initialization, frame work, event delivery and guaranteed shutdown.
CangjieGUI adopts the portable part as `HostLoopResult` and
`HostApplicationLoop`; the platform adapter remains responsible for mapping
those callbacks onto the fixed Cangjie scheduler thread.

### Apple packaging facts

The Apple host must preserve:

- a real application bundle and launch-screen declaration;
- high-pixel-density window creation;
- logical and pixel-size queries as separate facts;
- statically linked or correctly embedded runtime dependencies on iOS;
- resources placed in the application bundle rather than process-relative
  desktop paths.

## Already Covered

SwiftSDL's generic pointer owner, destroy callback, typed SDL failure and
allocate-copy-free helpers are good binding design, but CangjieGUI already has
the equivalent rules:

- `Resource` implementations with idempotent deterministic `close`;
- `CuiException` plus checked SDL return values;
- conversion of native arrays and strings into Cangjie-owned values before
  releasing SDL memory;
- reverse-order managed-resource shutdown in `DesktopApp`.

Adding a second generic owner abstraction would weaken rather than improve the
current ownership model.

## Deferred

- Direct `SDL_EnterAppMainCallbacks` binding is deferred until the Cangjie iOS
  static-package initialization entry is established.
- SDL3 GPU wrappers and shader packaging are a separate renderer packet.
- Vendoring SDL3 source or an XCFramework is not part of this intake.
- A SwiftUI/UIKit application shell is not framework source.
