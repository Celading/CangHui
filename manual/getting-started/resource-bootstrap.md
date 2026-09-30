# Resource bootstrap

Use this page when an application needs fonts, symbols, packaged data, images, or an application icon. It is the shortest path from a new `cuic` project to a declared and checked resource graph.

## 1. Pin the consumer surface first

From the application root, record the framework commit in `cjpm.toml`, the resolved entry in `cjpm.lock`, and the installed command version:

```bash
cuic version
cuic doctor macos --project . --verbose
cuic build macos .
```

If those three surfaces disagree, stop and repair the dependency selection with the application owner. Do not repair a consumer by editing a framework cache.

## 2. Declare logical resources

Keep package-relative paths in the manifest and resolve them through `ApplicationResources` at runtime. Do not scan the current working directory or guess a replacement file.

```cangjie
import chui.{ApplicationResourceDeclaration, ApplicationResourceRole,
    ApplicationResourceRoot, ApplicationResources, Fonts}

func applicationResources(projectRoot: String): ApplicationResources {
    ApplicationResources([
        ApplicationResourceDeclaration(
            "body-font", "assets/fonts/Body-Regular.ttf",
            role: ApplicationResourceRole.TextFont, family: "Demo Sans"),
        ApplicationResourceDeclaration(
            "fallback-font", "assets/fonts/Body-Fallback.ttf",
            role: ApplicationResourceRole.FallbackFont, family: "Demo Fallback"),
        ApplicationResourceDeclaration(
            "symbols", "assets/symbols/catalog.json",
            role: ApplicationResourceRole.SymbolCatalog),
        ApplicationResourceDeclaration(
            "seed-data", "assets/data/seed.json",
            role: ApplicationResourceRole.Data)
    ], [ApplicationResourceRoot.source(projectRoot)])
}

func registerApplicationFonts(resources: ApplicationResources): Unit {
    resources.registerFonts()
}
```

Call `registerFonts()` before creating the first window. `TextFont`, `FallbackFont`, and `SymbolFont` are separate roles. A symbol or icon font must not be installed as the Chinese text fallback; use `Icon`, `Symbol`, or a declared symbol catalog for icons.

## 3. Use the image path that the framework actually supports

The general image and network-resource path accepts PNG and BMP. SVG and JPEG are not general `ImageView` decoder inputs in this release. SVG is available in selected symbol or Linux application-icon paths; macOS application icons use ICNS or a square PNG, and Windows uses ICO. Convert or declare the asset for the target path instead of relying on extension guessing.

## 4. Package and inspect the graph

```bash
cuic doctor macos --project . --verbose
cuic package plan macos .
cuic package build macos .
```

The receipt should show the declared logical resource, its package-relative source, and its resolved destination. Missing files, duplicate logical names, traversal, symbolic-link inputs, and stale mobile generations are failures. A successful build does not prove that every platform host has been run.

## 5. macOS application icons

Declare a square PNG or a ready-made ICNS file:

```toml
[assets]
application-icon = "assets/app.png"
```

On a macOS host, `cuic package build macos .` converts a valid square PNG through `sips` and `iconutil` and writes `Contents/Resources/application.icns`. A non-macOS host cannot perform that PNG-to-ICNS conversion; provide ICNS or run the build on macOS. Finder icon refresh, signing, and notarization are separate acceptance gates.

## 6. When an incremental build behaves differently

Record the framework commit, `cjpm.lock`, `cuic version`, `cjpm --version`, target hash, and the first window's startup sequence. A clean rebuild is a diagnostic comparison, not a repair contract. If the failure mentions `native UI owner`, check that all pre-window blocking initialization is inside `DesktopThreadLease` and that background work returns through `DesktopApp.postToUi`.
