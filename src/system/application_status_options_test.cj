package chui.system

@Test
func statusItemOptionsSnapshotActionsAndAllowUserHiding(): Unit {
    let ids = ["app.settings"]
    let item = AppStatusItem("Example", actionIds: ids, title: "EX", visible: false, templateIcon: false)
    ids[0] = "app.changed"
    @Expect(item.actionIds[0], "app.settings")
    @Expect(!item.visible && !item.templateIcon)
    @Expect(item.title, "EX")
    var rejected = false
    try { let _ = AppStatusItem("bad\u{0}") } catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}
