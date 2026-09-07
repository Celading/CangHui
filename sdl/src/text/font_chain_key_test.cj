package sdl.text

@Test
func fontPathChainKeySeparatesOrderAndArbitraryPathBytes(): Unit {
    @Expect(fontPathChainKey(["a", "b"]) != fontPathChainKey(["b", "a"]))
    @Expect(fontPathChainKey(["a\nb"]) != fontPathChainKey(["a", "b"]))
    @Expect(fontPathChainKey(["a|b", "c"]) != fontPathChainKey(["a", "b|c"]))
    @Expect(fontPathChainKey([]) != fontPathChainKey([""]))
    @Expect(fontPathChainKey(["a"]) + "|1:b|x" != fontPathChainKey(["a", "b"]) + "|x")
    @Expect(fontPathChainKey(["字体"]), "1|6:字体")
}
