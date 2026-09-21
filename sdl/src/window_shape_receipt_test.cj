package sdl

@Test
func transparentWindowCanOptInWithoutInitialRadius(): Unit {
    let spec = WindowSpec("Later corners", 320, 200, frameless: true, transparent: true)
    @Expect((windowCreationFlags(spec) & SDL_WINDOW_TRANSPARENT) != UInt64(0))
    @Expect(spec.cornerRadius, Float32(0.0))
    for (value in [Float32.Inf, -Float32.Inf, Float32.NaN]) {
        var rejected = false
        try { let _ = WindowSpec("Invalid", 320, 200, cornerRadius: value) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func windowShapeCapabilityReceiptsStayFieldProofPending(): Unit {
    for (platform in ["windows", "linux-x11", "linux-wayland", "macos"]) {
        let receipt = WindowShapeCapabilityReceipt(platform)
        @Expect(receipt.contractAvailable)
        @Expect(!receipt.softwareConformanceComplete)
        @Expect(!receipt.hostRuntimeComplete)
        @Expect(receipt.fieldProofPending)
    }
}

@Test
func windowShapeNoRequestReceiptDoesNotClaimHostApplication(): Unit {
    let receipt = applyRoundedWindowShape(CPointer<Unit>(), 100, 100, 0.0)
    @Expect(receipt.status == WindowShapeApplyStatus.NotRequested)
    @Expect(!receipt.softwareConformanceComplete)
    @Expect(!receipt.hostRuntimeComplete)
    @Expect(receipt.fieldProofPending)
}
