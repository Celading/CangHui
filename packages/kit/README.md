# CangHuiKit

Optional `canghui_kit` source package for CangHui Multiplatform. It provides
composable choice cards, settings toggles, decorative steps, density-aware actions
and three responsive intro compositions. It reuses `chui` interaction and property
animation; it is not a new renderer, theme runtime or application state store.

See the [usage guide](../../manual/reference/canghui-kit.md) and
[runnable workbench](../../examples/kit-workbench/README.md).

`kitIntro` consumes `ComponentContext` with the available region's logical size.
Update it when the host's available size changes. Editorial, Focused and Guided
reorganize the same visual/actions/steps slots; they are not palette aliases.
State and business callbacks remain application-owned. Use a ScrollView for tall
content and long translations; never force the page into a fixed text height.

This version is common-source and macOS SDL verified; it does not certify every
native host. No third-party art or platform-private material is included.
