# macOS window and application shell

Run from the framework root with a debug CUIC:

```sh
cuic run examples/macos-shell --mode debug
cuic prntx examples/macos-shell macos-shell.settings
```

The native run provides runtime corner-radius changes, an application menu with
About and Settings, and a menu-bar status item that can be hidden or shown. The
probe exercises only the content model; it is not native window or menu evidence.
Use `cuic prnt` for content pixels and native desktop inspection for the outer
window, About, Dock and status menu.

For an explicit local application/status icon, append `-- --icon /path/app.png`
to the run command. Without an icon the status item uses the text `CH` and About
uses the system application's current icon. The Settings action updates the demo
message; it does not implement a preferences window or persist settings.

`WindowSpec(..., frameless: true, transparent: true, cornerRadius: 18.0)` opts into
runtime shape changes. `app.setWindowCornerRadius(0.0)` clears the shape;
`app.setWindowCornerRadius(36.0)` restores custom corners. Inspect its receipt for
native failure. All updates run on the window owner thread.

For a packaged icon, declare a square PNG or ICNS in `[assets].application-icon`
of `canghui.toml`, then use `cuic package build macos .`. PNG conversion requires
macOS. Packaging and runtime manifests are separate: bundle-relative runtime
assets resolve under `Contents/Resources`. See the
[packaging guide](../../manual/reference/application-packaging.md).
