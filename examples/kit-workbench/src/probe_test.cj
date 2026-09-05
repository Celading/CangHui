package canghui_kit_workbench

@Test
func workbenchMotionAndPrimaryActionAreReplayable(): Unit {
    let report = editorialProbe("focus reshape\nkey Enter\nadvance 230\nassert activation reshape 1\nfocus start\nkey Enter\nassert activation start 1")
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("motion-card"))
    @Expect(report.contains("editorial-split"))
}
