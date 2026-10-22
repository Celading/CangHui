# Scroll appearance example

Build with Cangjie1.2.0 using `cjpm build -j1`. Run the executable with
`--mode reserved`, `--mode overlay`, `--mode hidden` or `--mode transparent`;
`--width 390` selects a logical window width. Wheel and opt-in content dragging
remain available in every mode. Transparent chrome retains its requested layout
reservation; hidden chrome removes the bar reservation. Neither owns invisible
bar hit targets. A keyboard-focusable button remains outside the scroller.

`Widget.scrollable` wraps a parent container in the same `ScrollView` used by the
explicit component. Apply its viewport height after wrapping; a height applied to
the content before wrapping constrains content instead. Store the returned
ScrollView and call `metrics()` after layout to read the actual viewport, content,
offsets and reserved insets. Scrollbar colors are independent from content colors.

`--export-native <existing-output-directory>` captures the four modes at390,1024
and1440logical pixels using an owned native renderer, with DrawIR and post-layout
metrics. It writes proof files only; it is not cross-platform/device acceptance.
