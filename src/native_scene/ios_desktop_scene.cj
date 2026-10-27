package chui.native_scene

import std.collection.ArrayList
import std.sync.Mutex

/**
 * iPad desktop shell scene.
 *
 * The scene reproduces the macOS desktop reading order on an iPad: window
 * chrome, a library sidebar, a toolbar, a content grid and an inspector, with
 * the width breakpoint deciding how many regions survive. All state stays in
 * Cangjie; UIKit owns the surface, pointer, keyboard and IME.
 */
let IOS_DESKTOP_MAX_FRAME_MILLI: Int64 = 10_000_000
let IOS_DESKTOP_MAX_TEXT_BYTES: Int64 = 4096
let IOS_DESKTOP_SECTION_COUNT: Int64 = 4
let IOS_DESKTOP_CARD_COUNT: Int64 = 6
let IOS_DESKTOP_KEY_SPACE: Int64 = 44
let IOS_DESKTOP_KEY_LEFT: Int64 = 80
let IOS_DESKTOP_KEY_RIGHT: Int64 = 79
let IOS_DESKTOP_KEY_DIGIT_1: Int64 = 30
let IOS_DESKTOP_MODIFIER_COMMAND: Int64 = 1_048_576

let IOS_DESKTOP_BREAKPOINT_COMPACT: Int64 = 1
let IOS_DESKTOP_BREAKPOINT_MEDIUM: Int64 = 2
let IOS_DESKTOP_BREAKPOINT_EXPANDED: Int64 = 3
let IOS_DESKTOP_DEVICE_IPAD_MINI: Int64 = 3

let IOS_DESKTOP_SECTIONS = ["资料库", "最近播放", "收藏", "电台"]
let IOS_DESKTOP_SECTION_SYMBOLS = ["book", "clock", "heart", "radio"]
let IOS_DESKTOP_SECTION_COUNTS = ["12 首", "6 首", "4 首", "3 台"]
let IOS_DESKTOP_CARD_TITLES = [
    "夜间飞行", "海边的房间", "缓慢的光", "城市回声", "远山", "低空"
]
let IOS_DESKTOP_CARD_ARTISTS = [
    "仓绘室内乐团", "林间", "白噪音计划", "午夜电台", "山海", "低空"
]
let IOS_DESKTOP_PLACEHOLDER_SEARCH = "搜索资料库"

class DesktopLayout {
    let width: Float32
    let height: Float32
    let breakpoint: Int64
    let deviceClass: Int64
    let usesSidebar: Bool
    let usesInspector: Bool
    let margin: Float32
    let titlebarHeight: Float32
    let statusHeight: Float32
    let sidebarWidth: Float32
    let inspectorWidth: Float32
    let window: NativeRect
    let sidebar: NativeRect
    let content: NativeRect
    let inspector: NativeRect
    let statusbar: NativeRect
    let titlebar: NativeRect

    init(width: Float32, height: Float32, breakpoint: Int64, deviceClass: Int64,
        sidebarHint: Bool) {
        this.width = width
        this.height = height
        this.breakpoint = breakpoint
        this.deviceClass = deviceClass
        this.margin = if (breakpoint == IOS_DESKTOP_BREAKPOINT_EXPANDED) { 18.0 } else { 10.0 }
        this.titlebarHeight = if (breakpoint == IOS_DESKTOP_BREAKPOINT_COMPACT) { 54.0 } else { 52.0 }
        this.statusHeight = 28.0
        this.usesSidebar = sidebarHint && breakpoint != IOS_DESKTOP_BREAKPOINT_COMPACT
        this.sidebarWidth = if (!this.usesSidebar) { 0.0 } else if (
            deviceClass == IOS_DESKTOP_DEVICE_IPAD_MINI) { 208.0 } else { 252.0 }
        this.usesInspector = breakpoint == IOS_DESKTOP_BREAKPOINT_EXPANDED && width >= 1180.0
        this.inspectorWidth = if (this.usesInspector) { 292.0 } else { 0.0 }
        let windowWidth = max(240.0, width - 2.0 * this.margin)
        let windowHeight = max(320.0, height - 2.0 * this.margin)
        this.window = NativeRect(this.margin, this.margin, windowWidth, windowHeight)
        this.titlebar = NativeRect(this.window.x, this.window.y, windowWidth, this.titlebarHeight)
        let innerY = this.window.y + this.titlebarHeight
        let innerHeight = max(120.0, windowHeight - this.titlebarHeight - this.statusHeight)
        this.sidebar = NativeRect(this.window.x, innerY, this.sidebarWidth, innerHeight)
        this.content = NativeRect(this.window.x + this.sidebarWidth, innerY,
            max(200.0, windowWidth - this.sidebarWidth - this.inspectorWidth), innerHeight)
        this.inspector = NativeRect(this.content.x + this.content.width, innerY,
            this.inspectorWidth, innerHeight)
        this.statusbar = NativeRect(this.window.x,
            this.window.y + windowHeight - this.statusHeight, windowWidth, this.statusHeight)
    }

    func sectionRow(index: Int64): NativeRect {
        NativeRect(this.sidebar.x + 10.0, this.sidebar.y + 50.0 + Float32(index) * 40.0,
            max(80.0, this.sidebar.width - 20.0), 38.0)
    }

    func settingsRow(): NativeRect {
        NativeRect(this.sidebar.x + 10.0, this.sidebar.y + this.sidebar.height - 52.0,
            max(80.0, this.sidebar.width - 20.0), 38.0)
    }

    func cardsPerRow(): Int64 {
        if (this.content.width >= 700.0) { 3 } else if (this.content.width >= 440.0) { 2 } else { 1 }
    }

    func cardRect(index: Int64): NativeRect {
        let columns = this.cardsPerRow()
        let gap: Float32 = 14.0
        let inner = this.content.width - 56.0
        let cardWidth = max(120.0, (inner - Float32(columns - 1) * gap) / Float32(columns))
        let row = index / columns
        let column = index % columns
        NativeRect(this.content.x + 28.0 + Float32(column) * (cardWidth + gap),
            this.content.y + 268.0 + Float32(row) * 142.0, cardWidth, 128.0)
    }

    func heroRect(): NativeRect {
        NativeRect(this.content.x + 28.0, this.content.y + 96.0,
            max(240.0, this.content.width - 56.0), 150.0)
    }

    func playButtonRect(): NativeRect {
        let hero = this.heroRect()
        NativeRect(hero.x + hero.width - 206.0, hero.y + 55.0, 44.0, 44.0)
    }

    func searchRect(): NativeRect {
        NativeRect(this.window.x + this.window.width - 328.0, this.window.y + 12.0, 196.0, 28.0)
    }

    func plusRect(): NativeRect {
        NativeRect(this.window.x + this.window.width - 56.0, this.window.y + 12.0, 28.0, 28.0)
    }

    func sidebarToggleRect(): NativeRect {
        NativeRect(this.window.x + 86.0, this.window.y + 12.0, 28.0, 28.0)
    }

    func queueRowRect(index: Int64): NativeRect {
        let gridRows = (IOS_DESKTOP_CARD_COUNT + this.cardsPerRow() - 1) / this.cardsPerRow()
        let top = this.content.y + 268.0 + Float32(gridRows) * 142.0 + 36.0
        NativeRect(this.content.x + 28.0, top + Float32(index) * 36.0,
            max(160.0, this.content.width - 56.0), 34.0)
    }

    func queueFits(): Bool {
        let gridRows = (IOS_DESKTOP_CARD_COUNT + this.cardsPerRow() - 1) / this.cardsPerRow()
        let needed = 268.0 + Float32(gridRows) * 142.0 + 36.0 + 3.0 * 36.0 + 12.0
        return needed <= this.content.height
    }

    func inspectorTransportRect(index: Int64): NativeRect {
        let baseY = this.inspector.y + this.inspector.height - 78.0
        let startX = this.inspector.x + this.inspector.width / 2.0 - 66.0
        NativeRect(startX + Float32(index) * 48.0, baseY, 36.0, 36.0)
    }
}

class NativeSceneDesktopState {
    private let stateMutex = Mutex()
    private let pointer = NativeScenePointer()
    private var section: Int64 = 0
    private var track: Int64 = 0
    private var playing = false
    private var progress: Float32 = 0.42
    private var searchText = ""
    private var hoverId = ""
    private var lastAction = ""
    private var renders: Int64 = 0
    private var inputs: Int64 = 0
    private var keys: Int64 = 0
    private var ime: Int64 = 0
    private var idiom: Int64 = 0
    private var deviceClass: Int64 = 0
    private var breakpoint: Int64 = IOS_DESKTOP_BREAKPOINT_EXPANDED
    private var sidebarHint = true
    private var scaleMilli: Int64 = 2000
    private var lastWidth: Float32 = 0.0
    private var lastHeight: Float32 = 0.0

    func updateProfile(idiom: Int64, deviceClass: Int64, breakpoint: Int64,
        sidebarHint: Bool, scaleMilli: Int64): Bool {
        if (idiom < 0 || idiom > 6 || deviceClass < 0 || deviceClass > 4 ||
            breakpoint < 1 || breakpoint > 3 || scaleMilli <= 0) {
            return false
        }
        synchronized(this.stateMutex) {
            this.idiom = idiom
            this.deviceClass = deviceClass
            this.breakpoint = breakpoint
            this.sidebarHint = sidebarHint
            this.scaleMilli = scaleMilli
        }
        true
    }

    func report(width: Float32, height: Float32, eventKind: Int64, x: Float32,
        y: Float32, applyEvent: Bool): String {
        synchronized(this.stateMutex) {
            this.renders += 1
            this.lastWidth = width
            this.lastHeight = height
            let layout = this.layoutFor(width, height)
            var scene = this.buildScene(layout)
            if (applyEvent && eventKind != 0) {
                this.inputs += 1
                let action = this.pointer.dispatch(scene, eventKind, x, y)
                match (action) {
                    case Some(value) =>
                        this.applyAction(value)
                    case None => ()
                }
                scene = this.buildScene(layout)
            }
            scene.report(inputCount: this.inputs, selectedAction: this.lastAction)
        }
    }

    func hover(phase: Int64, x: Float32, y: Float32): Bool {
        if (phase != 1 && phase != 2) { return false }
        synchronized(this.stateMutex) {
            if (this.lastWidth <= 0.0 || this.lastHeight <= 0.0) { return false }
            let previous = this.hoverId
            if (phase == 2) {
                this.hoverId = ""
            } else {
                this.hoverId = this.hitTest(this.layoutFor(this.lastWidth, this.lastHeight), x, y)
            }
            previous != this.hoverId
        }
    }

    func key(phase: Int64, keyCode: Int64, modifiers: Int64, repeat: Bool): Bool {
        if (phase < 0 || phase > 1 || keyCode < 0 || keyCode > 65535) { return false }
        synchronized(this.stateMutex) {
            this.keys += 1
            if (phase != 1) { return true }
            let command = (modifiers & IOS_DESKTOP_MODIFIER_COMMAND) != 0
            if (command && keyCode >= IOS_DESKTOP_KEY_DIGIT_1 &&
                keyCode < IOS_DESKTOP_KEY_DIGIT_1 + IOS_DESKTOP_SECTION_COUNT) {
                this.section = keyCode - IOS_DESKTOP_KEY_DIGIT_1
                this.lastAction = "key.section"
                return true
            }
            if (keyCode == IOS_DESKTOP_KEY_SPACE) {
                this.playing = !this.playing
                this.lastAction = if (this.playing) { "key.play" } else { "key.pause" }
                return true
            }
            if (keyCode == IOS_DESKTOP_KEY_LEFT) {
                this.section = max(0, this.section - 1)
                this.lastAction = "key.section"
                return true
            }
            if (keyCode == IOS_DESKTOP_KEY_RIGHT) {
                this.section = min(IOS_DESKTOP_SECTION_COUNT - 1, this.section + 1)
                this.lastAction = "key.section"
                return true
            }
            this.lastAction = if (repeat) { "key.repeat" } else { "key.ignored" }
            true
        }
    }

    func setText(value: String): Bool {
        if (value.toArray().size > IOS_DESKTOP_MAX_TEXT_BYTES) { return false }
        synchronized(this.stateMutex) {
            this.searchText = value
            this.ime += 1
            this.lastAction = "ime"
        }
        true
    }

    func activate(id: String): Bool {
        synchronized(this.stateMutex) {
            if (!this.knownAction(id)) { return false }
            this.inputs += 1
            this.applyAction(id)
        }
        true
    }

    func stateJson(): String {
        synchronized(this.stateMutex) {
            if (this.lastWidth > 0.0 && this.lastHeight > 0.0) {
                let layout = this.layoutFor(this.lastWidth, this.lastHeight)
                let scene = this.buildScene(layout)
                "{\"protocol\":" + nativeSceneQuote(CANGHUI_NATIVE_SCENE_PROTOCOL) +
                    ",\"layout\":" + nativeSceneQuote(this.layoutName(layout)) +
                    ",\"breakpoint\":" + this.breakpoint.toString() +
                    ",\"deviceClass\":" + this.deviceClass.toString() +
                    ",\"orientation\":" + nativeSceneQuote(if (this.lastWidth >= this.lastHeight) {
                        "landscape" } else { "portrait" }) +
                    ",\"usesSidebar\":" + layout.usesSidebar.toString() +
                    ",\"usesInspector\":" + layout.usesInspector.toString() +
                    ",\"sidebarWidth\":" + layout.sidebarWidth.toString() +
                    ",\"cardsPerRow\":" + layout.cardsPerRow().toString() +
                    ",\"section\":" + this.section.toString() +
                    ",\"sectionTitle\":" + nativeSceneQuote(IOS_DESKTOP_SECTIONS[this.section]) +
                    ",\"track\":" + this.track.toString() +
                    ",\"playing\":" + this.playing.toString() +
                    ",\"searchText\":" + nativeSceneQuote(this.searchText) +
                    ",\"hover\":" + nativeSceneQuote(this.hoverId) +
                    ",\"lastAction\":" + nativeSceneQuote(this.lastAction) +
                    ",\"renders\":" + this.renders.toString() +
                    ",\"inputs\":" + this.inputs.toString() +
                    ",\"keys\":" + this.keys.toString() +
                    ",\"ime\":" + this.ime.toString() +
                    ",\"commands\":" + scene.commandCount().toString() +
                    ",\"actions\":" + scene.actionCount().toString() +
                    ",\"textLayout\":" + scene.hasMeasuredTextLayout().toString() +
                    ",\"width\":" + this.lastWidth.toString() +
                    ",\"height\":" + this.lastHeight.toString() +
                    ",\"scaleMilli\":" + this.scaleMilli.toString() + "}"
            } else {
                "{\"protocol\":" + nativeSceneQuote(CANGHUI_NATIVE_SCENE_PROTOCOL) +
                    ",\"layout\":\"unmeasured\",\"renders\":" + this.renders.toString() + "}"
            }
        }
    }

    func currentSection(): Int64 { synchronized(this.stateMutex) { this.section } }
    func currentTrack(): Int64 { synchronized(this.stateMutex) { this.track } }
    func isPlaying(): Bool { synchronized(this.stateMutex) { this.playing } }
    func currentSearchText(): String { synchronized(this.stateMutex) { this.searchText } }
    func currentHover(): String { synchronized(this.stateMutex) { this.hoverId } }
    func currentLastAction(): String { synchronized(this.stateMutex) { this.lastAction } }
    func totalRenders(): Int64 { synchronized(this.stateMutex) { this.renders } }
    func totalInputs(): Int64 { synchronized(this.stateMutex) { this.inputs } }
    func totalKeys(): Int64 { synchronized(this.stateMutex) { this.keys } }
    func totalIme(): Int64 { synchronized(this.stateMutex) { this.ime } }
    func currentLayoutName(): String {
        synchronized(this.stateMutex) {
            if (this.lastWidth > 0.0 && this.lastHeight > 0.0) {
                this.layoutName(this.layoutFor(this.lastWidth, this.lastHeight))
            } else { "unmeasured" }
        }
    }

    private func layoutName(layout: DesktopLayout): String {
        if (this.breakpoint == IOS_DESKTOP_BREAKPOINT_COMPACT) { "compact-desktop" }
        else if (layout.usesInspector) { "three-pane-desktop" }
        else if (layout.usesSidebar) { "two-pane-desktop" }
        else { "single-pane-desktop" }
    }

    private func layoutFor(width: Float32, height: Float32): DesktopLayout {
        DesktopLayout(width, height, this.breakpoint, this.deviceClass, this.sidebarHint)
    }

    private func knownAction(id: String): Bool {
        if (id == "play.toggle" || id == "search.focus" || id == "toolbar.plus" ||
            id == "sidebar.toggle" || id == "settings.open") { return true }
        for (index in 0..IOS_DESKTOP_SECTION_COUNT) {
            if (id == "section." + index.toString()) { return true }
        }
        for (index in 0..IOS_DESKTOP_CARD_COUNT) {
            if (id == "card." + index.toString()) { return true }
        }
        for (index in 0..3) {
            if (id == "transport." + index.toString()) { return true }
        }
        for (index in 0..3) {
            if (id == "queue." + index.toString()) { return true }
        }
        false
    }

    private func applyAction(id: String): Unit {
        this.lastAction = id
        for (index in 0..IOS_DESKTOP_SECTION_COUNT) {
            if (id == "section." + index.toString()) {
                this.section = index
                return
            }
        }
        for (index in 0..IOS_DESKTOP_CARD_COUNT) {
            if (id == "card." + index.toString()) {
                this.track = index
                this.progress = 0.32 + Float32(index) * 0.08
                this.playing = true
                return
            }
        }
        for (index in 0..3) {
            if (id == "queue." + index.toString()) {
                this.track = index
                this.progress = 0.32 + Float32(index) * 0.08
                this.playing = true
                return
            }
        }
        if (id == "play.toggle") {
            this.playing = !this.playing
        } else if (id == "transport.0") {
            this.track = max(0, this.track - 1)
        } else if (id == "transport.1") {
            this.playing = !this.playing
        } else if (id == "transport.2") {
            this.track = min(IOS_DESKTOP_CARD_COUNT - 1, this.track + 1)
        } else if (id == "sidebar.toggle") {
            this.sidebarHint = !this.sidebarHint
        }
    }

    private func hitTest(layout: DesktopLayout, x: Float32, y: Float32): String {
        if (layout.usesSidebar) {
            for (index in 0..IOS_DESKTOP_SECTION_COUNT) {
                if (layout.sectionRow(index).contains(x, y)) { return "section." + index.toString() }
            }
            if (layout.settingsRow().contains(x, y)) { return "settings.open" }
        }
        if (layout.searchRect().contains(x, y)) { return "search.focus" }
        if (layout.plusRect().contains(x, y)) { return "toolbar.plus" }
        if (!layout.usesSidebar && layout.sidebarToggleRect().contains(x, y)) { return "sidebar.toggle" }
        if (layout.playButtonRect().contains(x, y)) { return "play.toggle" }
        for (index in 0..IOS_DESKTOP_CARD_COUNT) {
            if (layout.cardRect(index).contains(x, y)) { return "card." + index.toString() }
        }
        if (layout.usesInspector) {
            for (index in 0..3) {
                if (layout.inspectorTransportRect(index).contains(x, y)) {
                    return "transport." + index.toString()
                }
            }
        }
        if (layout.queueFits()) {
            for (index in 0..3) {
                if (layout.queueRowRect(index).contains(x, y)) {
                    return "queue." + index.toString()
                }
            }
        }
        ""
    }

    private func buildScene(layout: DesktopLayout): NativeScene {
        let width = layout.width
        let height = layout.height
        let windowFill = NativeColor.rgb(26, 30, 38)
        let edgeColor = NativeColor.rgb(52, 60, 72)
        let titlebarFill = NativeColor.rgb(31, 36, 45)
        let sidebarFill = NativeColor.rgb(21, 25, 32)
        let divider = NativeColor.rgb(38, 44, 54)
        let accent = NativeColor.rgb(64, 140, 255)
        let primary = NativeColor.rgb(232, 238, 247)
        let secondary = NativeColor.rgb(154, 166, 184)
        let icon = NativeColor.rgb(168, 180, 198)
        let selectedRow = NativeColor.rgba(64, 140, 255, 58)
        let hoverRow = NativeColor.rgba(255, 255, 255, 18)
        let cardFill = NativeColor.rgb(30, 36, 46)
        let cardEdge = NativeColor.rgb(44, 52, 64)
        let scene = NativeScene("canghui-ios-desktop", width, height,
            NativeColor.rgb(11, 14, 19))
        scene.fillCircle(width * 0.86, height * 0.04, max(width, height) * 0.42,
            NativeColor.rgba(38, 74, 126, 30))
        scene.fillCircle(width * 0.08, height * 0.98, max(width, height) * 0.38,
            NativeColor.rgba(92, 44, 122, 22))
        scene.panel(layout.window, windowFill, edge: edgeColor, radius: 18.0)

        scene.pushClip(NativeRect(layout.window.x + 1.0, layout.window.y + 1.0,
            layout.window.width - 2.0, layout.window.height - 2.0))
        scene.fill(layout.titlebar, titlebarFill)
        scene.fill(layout.statusbar, NativeColor.rgb(23, 27, 34))
        if (layout.usesSidebar) { scene.fill(layout.sidebar, sidebarFill) }
        scene.popClip()
        scene.line(layout.window.x, layout.titlebar.y + layout.titlebar.height,
            layout.window.x + layout.window.width, layout.titlebar.y + layout.titlebar.height,
            divider, width: 1.0)

        this.drawTitlebar(scene, layout, primary, secondary, icon, divider)
        if (layout.usesSidebar) {
            this.drawSidebar(scene, layout, accent, primary, secondary, icon, selectedRow,
                hoverRow, divider)
        }
        this.drawContent(scene, layout, accent, primary, secondary, icon, cardFill, cardEdge,
            divider)
        if (layout.usesInspector) {
            this.drawInspector(scene, layout, accent, primary, secondary, icon,
                cardEdge, divider)
        }
        this.drawStatusbar(scene, layout, secondary, divider)
        scene
    }

    private func drawTitlebar(scene: NativeScene, layout: DesktopLayout,
        primary: NativeColor, secondary: NativeColor, icon: NativeColor, divider: NativeColor) {
        let bar = layout.titlebar
        let lightY = bar.y + 26.0
        scene.fillCircle(bar.x + 22.0, lightY, 6.0, NativeColor.rgb(255, 95, 87))
        scene.fillCircle(bar.x + 40.0, lightY, 6.0, NativeColor.rgb(254, 188, 46))
        scene.fillCircle(bar.x + 58.0, lightY, 6.0, NativeColor.rgb(40, 200, 64))
        if (!layout.usesSidebar) {
            let toggle = layout.sidebarToggleRect()
            scene.symbol("sf", "sidebar.left",
                NativeRect(toggle.x + 5.0, toggle.y + 5.0, 18.0, 18.0), icon)
            scene.action("sidebar.toggle", toggle)
        }
        let title = "仓绘 · " + IOS_DESKTOP_SECTIONS[this.section]
        scene.text(title, bar.x + bar.width / 2.0 - 62.0, bar.y + 18.0, primary,
            pointSize: 13.0, bold: true)

        let search = layout.searchRect()
        scene.panel(search, NativeColor.rgba(255, 255, 255, 10), radius: 8.0)
        scene.symbol("sf", "magnifyingglass",
            NativeRect(search.x + 8.0, search.y + 7.0, 14.0, 14.0), secondary)
        let searchLabel = if (this.searchText.isEmpty()) {
            IOS_DESKTOP_PLACEHOLDER_SEARCH
        } else {
            this.searchText
        }
        scene.text(searchLabel, search.x + 28.0, search.y + 6.0,
            if (this.searchText.isEmpty()) { secondary } else { primary }, pointSize: 12.0)
        scene.action("search.focus", search)

        let plus = layout.plusRect()
        scene.panel(plus, NativeColor.rgba(255, 255, 255, 14), radius: 8.0)
        scene.symbol("sf", "plus", NativeRect(plus.x + 6.0, plus.y + 6.0, 16.0, 16.0), primary)
        scene.action("toolbar.plus", plus)
        scene.line(bar.x, bar.y + bar.height - 1.0, bar.x + bar.width,
            bar.y + bar.height - 1.0, divider, width: 1.0)
    }

    private func drawSidebar(scene: NativeScene, layout: DesktopLayout, accent: NativeColor,
        primary: NativeColor, secondary: NativeColor, icon: NativeColor,
        selectedRow: NativeColor, hoverRow: NativeColor, divider: NativeColor) {
        let bar = layout.sidebar
        scene.line(bar.x + bar.width, bar.y, bar.x + bar.width, bar.y + bar.height,
            divider, width: 1.0)
        scene.text("资料库", bar.x + 18.0, bar.y + 18.0, secondary, pointSize: 11.0, bold: true)
        for (index in 0..IOS_DESKTOP_SECTION_COUNT) {
            let row = layout.sectionRow(index)
            let selected = index == this.section
            let hovered = this.hoverId == "section." + index.toString()
            if (selected) {
                scene.fillRounded(row, 8.0, selectedRow)
            } else if (hovered) {
                scene.fillRounded(row, 8.0, hoverRow)
            }
            scene.symbol("sf", IOS_DESKTOP_SECTION_SYMBOLS[index],
                NativeRect(row.x + 10.0, row.y + 9.0, 18.0, 18.0),
                if (selected) { accent } else { icon })
            scene.text(IOS_DESKTOP_SECTIONS[index], row.x + 38.0, row.y + 9.0,
                if (selected) { primary } else { secondary }, pointSize: 13.5,
                bold: selected)
            scene.text(IOS_DESKTOP_SECTION_COUNTS[index], row.x + row.width - 42.0,
                row.y + 11.0, secondary, pointSize: 11.0)
            scene.action("section." + index.toString(), row)
        }
        let settings = layout.settingsRow()
        let settingsHovered = this.hoverId == "settings.open"
        if (settingsHovered) { scene.fillRounded(settings, 8.0, hoverRow) }
        scene.line(bar.x + 10.0, settings.y - 10.0, bar.x + bar.width - 10.0,
            settings.y - 10.0, divider, width: 1.0)
        scene.symbol("sf", "gearshape",
            NativeRect(settings.x + 10.0, settings.y + 9.0, 18.0, 18.0), icon)
        scene.text("设置", settings.x + 38.0, settings.y + 9.0, secondary, pointSize: 13.0)
        scene.action("settings.open", settings)
        scene.text("CangHui iPad 1.0", bar.x + 18.0, bar.y + bar.height - 100.0,
            secondary, pointSize: 10.0)
    }

    private func drawContent(scene: NativeScene, layout: DesktopLayout, accent: NativeColor,
        primary: NativeColor, secondary: NativeColor, icon: NativeColor, cardFill: NativeColor,
        cardEdge: NativeColor, divider: NativeColor) {
        let area = layout.content
        let sectionTitle = IOS_DESKTOP_SECTIONS[this.section]
        scene.text(sectionTitle, area.x + 28.0, area.y + 22.0, primary,
            pointSize: 26.0, bold: true)
        scene.text("在 iPad 上还原 macOS 阅读顺序：侧栏、工具栏、内容与检查器。",
            area.x + 28.0, area.y + 60.0, secondary, pointSize: 12.5,
            width: max(120.0, area.width - 56.0), height: 20.0, lineLimit: 1,
            alignment: "left")

        let hero = layout.heroRect()
        scene.panel(hero, cardFill, edge: cardEdge, radius: 14.0)
        scene.text("继续播放", hero.x + 20.0, hero.y + 16.0, secondary, pointSize: 11.0,
            bold: true)
        scene.text(IOS_DESKTOP_CARD_TITLES[this.track], hero.x + 20.0, hero.y + 38.0,
            primary, pointSize: 21.0, bold: true)
        scene.text(IOS_DESKTOP_CARD_ARTISTS[this.track], hero.x + 20.0, hero.y + 70.0,
            secondary, pointSize: 12.5)
        scene.progress(NativeRect(hero.x + 20.0, hero.y + hero.height - 30.0,
            max(90.0, hero.width - 250.0), 6.0), this.progress,
            NativeColor.rgb(52, 62, 76), accent, secondary)
        let artwork = NativeRect(hero.x + hero.width - 138.0, hero.y + 16.0, 118.0, 118.0)
        scene.panel(artwork, NativeColor.rgb(35, 43, 56), edge: cardEdge, radius: 10.0)
        scene.symbol("sf", "music.note",
            NativeRect(artwork.x + 39.0, artwork.y + 39.0, 40.0, 40.0), icon)
        let play = layout.playButtonRect()
        scene.fillCircle(play.x + 22.0, play.y + 22.0, 22.0, accent)
        scene.symbol("sf", if (this.playing) { "pause.fill" } else { "play.fill" },
            NativeRect(play.x + 12.0, play.y + 12.0, 20.0, 20.0),
            NativeColor.rgb(255, 255, 255))
        scene.action("play.toggle", NativeRect(play.x, play.y, 44.0, 44.0))

        scene.text("最近添加", area.x + 28.0, area.y + 244.0, primary, pointSize: 13.0,
            bold: true)
        for (index in 0..IOS_DESKTOP_CARD_COUNT) {
            let card = layout.cardRect(index)
            if (card.y + card.height > area.y + area.height - 6.0) { continue }
            let hovered = this.hoverId == "card." + index.toString()
            let selected = index == this.track
            scene.panel(card, if (hovered) { NativeColor.rgb(36, 43, 55) } else { cardFill },
                edge: if (selected) { accent } else { cardEdge }, radius: 12.0)
            let tile = NativeRect(card.x + 14.0, card.y + 14.0, 40.0, 40.0)
            scene.panel(tile, NativeColor.rgb(40, 49, 62), edge: cardEdge, radius: 8.0)
            scene.symbol("sf", IOS_DESKTOP_SECTION_SYMBOLS[index % IOS_DESKTOP_SECTION_COUNT],
                NativeRect(tile.x + 11.0, tile.y + 11.0, 18.0, 18.0),
                if (selected) { accent } else { icon })
            scene.text(IOS_DESKTOP_CARD_TITLES[index], card.x + 14.0, card.y + 66.0,
                primary, pointSize: 14.0, bold: true)
            scene.text(IOS_DESKTOP_CARD_ARTISTS[index], card.x + 14.0, card.y + 88.0,
                secondary, pointSize: 11.5)
            scene.text("3:4${index}", card.x + card.width - 46.0, card.y + 70.0,
                secondary, pointSize: 11.0)
            scene.action("card." + index.toString(), card)
        }
        if (layout.queueFits()) {
            let listTop = layout.queueRowRect(0).y - 26.0
            scene.text("播放队列", area.x + 28.0, listTop, primary, pointSize: 13.0, bold: true)
            for (index in 0..3) {
                let row = layout.queueRowRect(index)
                let hovered = this.hoverId == "queue." + index.toString()
                if (hovered) { scene.fillRounded(row, 8.0, NativeColor.rgba(255, 255, 255, 14)) }
                scene.text("${index + 1}", row.x + 8.0, row.y + 9.0, secondary, pointSize: 12.0)
                scene.text(IOS_DESKTOP_CARD_TITLES[index], row.x + 34.0, row.y + 8.0,
                    if (index == this.track) { accent } else { primary }, pointSize: 13.5,
                    bold: index == this.track)
                scene.text(IOS_DESKTOP_CARD_ARTISTS[index], row.x + 200.0, row.y + 10.0,
                    secondary, pointSize: 11.5)
                scene.text("3:4${index}", row.x + row.width - 44.0, row.y + 9.0,
                    secondary, pointSize: 11.0)
                scene.action("queue." + index.toString(), row)
            }
        }
        scene.line(area.x + 28.0, area.y + area.height - 1.0, area.x + area.width - 28.0,
            area.y + area.height - 1.0, divider, width: 1.0)
    }

    private func drawInspector(scene: NativeScene, layout: DesktopLayout, accent: NativeColor,
        primary: NativeColor, secondary: NativeColor, icon: NativeColor,
        cardEdge: NativeColor, divider: NativeColor) {
        let area = layout.inspector
        scene.line(area.x, area.y, area.x, area.y + area.height, divider, width: 1.0)
        scene.text("正在播放", area.x + 18.0, area.y + 18.0, secondary, pointSize: 11.0,
            bold: true)
        let artSize = max(120.0, area.width - 36.0)
        let artwork = NativeRect(area.x + 18.0, area.y + 44.0, artSize, artSize)
        scene.panel(artwork, NativeColor.rgb(35, 43, 56), edge: cardEdge, radius: 12.0)
        scene.symbol("sf", "music.note",
            NativeRect(artwork.x + artSize / 2.0 - 28.0, artwork.y + artSize / 2.0 - 28.0,
                56.0, 56.0), icon)
        scene.text(IOS_DESKTOP_CARD_TITLES[this.track], area.x + 18.0,
            artwork.y + artSize + 16.0, primary, pointSize: 16.0, bold: true,
            width: max(120.0, area.width - 36.0), height: 24.0, lineLimit: 1,
            alignment: "left")
        scene.text(IOS_DESKTOP_CARD_ARTISTS[this.track], area.x + 18.0,
            artwork.y + artSize + 44.0, secondary, pointSize: 12.5)
        for (index in 0..3) {
            let button = layout.inspectorTransportRect(index)
            scene.fillCircle(button.x + 18.0, button.y + 18.0, 18.0,
                if (index == 1) { accent } else { NativeColor.rgba(255, 255, 255, 16) })
            let symbolName = if (index == 0) { "backward.fill" } else if (index == 1) {
                if (this.playing) { "pause.fill" } else { "play.fill" }
            } else { "forward.fill" }
            scene.symbol("sf", symbolName,
                NativeRect(button.x + 8.0, button.y + 8.0, 20.0, 20.0),
                if (index == 1) { NativeColor.rgb(255, 255, 255) } else { primary })
            scene.action("transport." + index.toString(), button)
        }
        scene.text("无缝播放 · 48 kHz", area.x + 18.0, area.y + area.height - 32.0,
            secondary, pointSize: 10.5)
    }

    private func drawStatusbar(scene: NativeScene, layout: DesktopLayout, secondary: NativeColor,
        divider: NativeColor) {
        let bar = layout.statusbar
        scene.line(bar.x, bar.y, bar.x + bar.width, bar.y, divider, width: 1.0)
        scene.text("12 首 · 48 kHz · 深色外观", bar.x + 18.0, bar.y + 8.0, secondary,
            pointSize: 10.5)
        let hint = if (bar.width >= 980.0) {
            "⌘1–4 切换 · 空格 播放 · 指针悬停高亮"
        } else {
            "⌘1–4 · 空格"
        }
        // Scene text has no measured right-alignment; keep the estimate generous.
        let hintWidth = Float32(hint.toArray().size) * 5.5
        scene.text(hint, bar.x + bar.width - hintWidth - 18.0, bar.y + 8.0, secondary,
            pointSize: 10.5)
    }
}

let iosDesktopState = NativeSceneDesktopState()

@C
public func canghui_ios_desktop_render(
    widthMilli: Int64,
    heightMilli: Int64,
    eventKind: Int64,
    xMilli: Int64,
    yMilli: Int64,
    output: CPointer<UInt8>,
    outputCapacity: Int64,
    outputLength: CPointer<Int64>
): Int32 {
    if (outputLength.isNull()) { return -1 }
    if (widthMilli <= 0 || heightMilli <= 0 ||
        widthMilli > IOS_DESKTOP_MAX_FRAME_MILLI || heightMilli > IOS_DESKTOP_MAX_FRAME_MILLI) {
        return -1
    }
    if (eventKind < 0 || eventKind > 5) { return -1 }
    if (eventKind != 0 &&
        (xMilli < -IOS_DESKTOP_MAX_FRAME_MILLI || xMilli > IOS_DESKTOP_MAX_FRAME_MILLI ||
         yMilli < -IOS_DESKTOP_MAX_FRAME_MILLI || yMilli > IOS_DESKTOP_MAX_FRAME_MILLI)) {
        return -1
    }
    let applyEvent = output.isNull() || outputCapacity <= 0
    let report = iosDesktopState.report(
        Float32(widthMilli) / Float32(1000),
        Float32(heightMilli) / Float32(1000),
        eventKind,
        Float32(xMilli) / Float32(1000),
        Float32(yMilli) / Float32(1000),
        applyEvent)
    copyNativeSceneUtf8ToCaller(report, output, outputCapacity, outputLength)
}

@C
public func canghui_ios_desktop_set_text(
    text: CPointer<UInt8>,
    length: Int64
): Int32 {
    if (length < 0 || length > IOS_DESKTOP_MAX_TEXT_BYTES) { return -1 }
    let value = match (iosDesktopUtf8String(text, length)) {
        case Some(decoded) => decoded
        case None => return -1
    }
    if (iosDesktopState.setText(value)) { 0 } else { -1 }
}

@C
public func canghui_ios_desktop_hover(phase: Int64, xMilli: Int64, yMilli: Int64): Int32 {
    if (xMilli < -IOS_DESKTOP_MAX_FRAME_MILLI || xMilli > IOS_DESKTOP_MAX_FRAME_MILLI ||
        yMilli < -IOS_DESKTOP_MAX_FRAME_MILLI || yMilli > IOS_DESKTOP_MAX_FRAME_MILLI) {
        return -1
    }
    if (iosDesktopState.hover(phase, Float32(xMilli) / Float32(1000),
        Float32(yMilli) / Float32(1000))) { 1 } else { 0 }
}

@C
public func canghui_ios_desktop_key(phase: Int64, keyCode: Int64, modifiers: Int64,
    repeat: Int32): Int32 {
    if (iosDesktopState.key(phase, keyCode, modifiers, repeat != 0)) { 1 } else { 0 }
}

@C
public func canghui_ios_desktop_activate(
    action: CPointer<UInt8>,
    length: Int64
): Int32 {
    if (length < 0 || length > IOS_DESKTOP_MAX_TEXT_BYTES) { return -1 }
    let value = match (iosDesktopUtf8String(action, length)) {
        case Some(decoded) => decoded
        case None => return -1
    }
    if (iosDesktopState.activate(value)) { 0 } else { -1 }
}

@C
public func canghui_ios_desktop_set_profile(
    idiom: Int64,
    deviceClass: Int64,
    breakpoint: Int64,
    usesSidebar: Int32,
    scaleMilli: Int64
): Int32 {
    if (iosDesktopState.updateProfile(idiom, deviceClass, breakpoint, usesSidebar != 0,
        scaleMilli)) { 0 } else { -1 }
}

@C
public func canghui_ios_desktop_state(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosDesktopState.stateJson(), output, capacity, length)
}

@C public func canghui_ios_desktop_section(): Int64 { iosDesktopState.currentSection() }
@C public func canghui_ios_desktop_track(): Int64 { iosDesktopState.currentTrack() }
@C public func canghui_ios_desktop_playing(): Int32 {
    if (iosDesktopState.isPlaying()) { 1 } else { 0 }
}
@C public func canghui_ios_desktop_render_count(): Int64 { iosDesktopState.totalRenders() }
@C public func canghui_ios_desktop_input_count(): Int64 { iosDesktopState.totalInputs() }
@C public func canghui_ios_desktop_key_count(): Int64 { iosDesktopState.totalKeys() }
@C public func canghui_ios_desktop_ime_count(): Int64 { iosDesktopState.totalIme() }

@C
public func canghui_ios_desktop_search_text(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosDesktopState.currentSearchText(), output, capacity, length)
}

@C
public func canghui_ios_desktop_hover_id(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosDesktopState.currentHover(), output, capacity, length)
}

@C
public func canghui_ios_desktop_last_action(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosDesktopState.currentLastAction(), output, capacity, length)
}

private func iosDesktopUtf8String(text: CPointer<UInt8>, length: Int64): ?String {
    if (text.isNull() || length <= 0) { return Some("") }
    let bytes = ArrayList<UInt8>()
    unsafe {
        for (i in 0..length) {
            bytes.add(text.read(i))
        }
    }
    try {
        Some(String.fromUtf8(bytes.toArray()))
    } catch (error: Exception) {
        None
    }
}
