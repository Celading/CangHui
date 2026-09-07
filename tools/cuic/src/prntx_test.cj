package cuic

@Test
func prntxValidatesOutputBoundsAndModes(): Unit {
    validatePrntxOptions("summary", 32, "save")
    validatePrntxOptions("tree", 32, "save")
    validatePrntxOptions("json", 128, "-")
    validatePrntxOptions("diff", 1, "-")
    validatePrntxOptions("ascii", 32, "-")
    for (mode in ["", "html", "execute"]) {
        var refused = false
        try { validatePrntxOptions(mode, 32, "-") } catch (_: CuicError) { refused = true }
        @Expect(refused)
    }
    for (limit in [Int64(0), Int64(129)]) {
        var refused = false
        try { validatePrntxOptions("summary", limit, "-") } catch (_: CuicError) { refused = true }
        @Expect(refused)
    }
}

@When[!debug]
@Test
func prntxReleaseRefusesBeforeProjectOrProcessAccess(): Unit {
    var refused = false
    try { let _ = prntxCommand(["/missing/project", "probe"], 0) }
    catch (error: CuicError) { refused = error.message.contains("unavailable in release cuic") }
    @Expect(refused)
}
