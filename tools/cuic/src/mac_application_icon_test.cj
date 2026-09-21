package cuic

@Test
func macIconPngRejectsMalformedAndUnboundedDimensions(): Unit {
    for (size in [16,128,512,1024,4096]) { @Expect(macPngIconSize(linuxTestPngHeader(size,size)), size) }
    for (header in [linuxTestPngHeader(0,0),linuxTestPngHeader(1024,512),
        linuxTestPngHeader(4097,4097),linuxTestPngHeader(15,15),Array<UInt8>(24, repeat: 0)]) {
        var rejected = false
        try { let _ = macPngIconSize(header) } catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}
