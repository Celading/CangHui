package chui_adaptive_scroll

import chui.*
import chui.kmode.macros.*
import std.env.getCommandLine

@CuiProbe["adaptive-scroll.narrow"]
func narrowProbe(script: String): String {
    ComponentProbe("adaptive-scroll.narrow", width: 380.0, height: 320.0).run(script) { board() }
}

@CuiProbe["adaptive-scroll.wide"]
func wideProbe(script: String): String {
    ComponentProbe("adaptive-scroll.wide", width: 800.0, height: 700.0).run(script) { board() }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let args = getCommandLine()
    let narrow = args.contains("--narrow")
    let wide = args.contains("--wide")
    let width: Int32 = if (narrow) {380} else if (wide) {800} else {760}
    let height: Int32 = if (narrow) {320} else if (wide) {700} else {420}
    let theme = if (args.contains("--dark")) {Theme.dark()} else {Theme.light()}
    let app = DesktopApp(WindowSpec("CangHui Adaptive Scroll", width, height), theme: theme)
    app.run { board() }
    return 0
}

private func board(): Unit {
    let x = rememberState<Float32>("board.x") {0.0}
    let y = rememberState<Float32>("board.y") {0.0}
    let selected = rememberState<Int64>("board.selected") {0}
    VStack(spacing: 12.vp) {
        Label("Reading board").bold().fontSize(FontSizes.TITLE)
        Label("Drag to explore · Selected ${selected.value}").muted()
        ScrollView(key: "board") {
            HStack(spacing: 16.vp, flexible: false) {
                for (column in 0..2) {
                    VStack(spacing: 8.vp, flexible: false) {
                        Label(if (column == 0) {"Library"} else {"Reading queue"}).bold()
                        for (row in 0..10) {
                            let number = column * 10 + row + 1
                            Button("Book ${number}", {=> selected.value = number})
                                .height(40.vp).fillWidth()
                        }
                    }.crossAxisAlignment(CrossAxisAlignment.Stretch).width(320.vp)
                }
            }.hug()
        }.horizontalContent(656.0).horizontalScrollState(x).scrollState(y)
            .dragToScroll().probe("reading-board", "ScrollView")
    }.crossAxisAlignment(CrossAxisAlignment.Stretch).padding(16.vp)
}
