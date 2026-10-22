package chui.core

import std.collection.ArrayList

/** Isolate constructor emission before replacing the original parent entry exactly once. */
protected func applyScrollable(child: Widget, key: ?String, options: ScrollOptions): ScrollView {
    let result = ArrayList<ScrollView>()
    let _ = buildChildren {=> result.add(ScrollView(key: key) { emit(child) }.scrollOptions(options)) }
    let view = result[0]
    replaceLastEmission(child, view)
    view
}
