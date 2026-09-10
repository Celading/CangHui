package sdl.text

@Test
func systemFontCandidatesPreferInstalledHarmonyAndCjkMacFaces(): Unit {
    let candidates = systemFontCandidatesFor("/Users/example")

    @Expect(candidates[0], "/Users/example/Library/Fonts/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[1], "/Users/example/Library/Fonts/HarmonyOS Sans SC.ttf")
    @Expect(candidates[7], "/System/Library/Fonts/Hiragino Sans GB.ttc")
    @Expect(candidates[10], "/System/Library/Fonts/SFNS.ttf")
}

@Test
func startupFontCandidatesRetainSystemPriorityAndApplicationOrder(): Unit {
    let candidates = startupFontCandidates(["system.ttf", "cjk.ttc"], ["brand.ttf", "bundle.ttf"])
    @Expect(candidates.size, 4)
    @Expect(candidates[0], "system.ttf")
    @Expect(candidates[1], "cjk.ttc")
    @Expect(candidates[2], "brand.ttf")
    @Expect(candidates[3], "bundle.ttf")
}

@Test
func startupFontCandidatesAcceptPackagedFacesWithoutSystemFonts(): Unit {
    let candidates = startupFontCandidates([], ["/bundle/assets/font.ttf"])
    @Expect(candidates.size, 1)
    @Expect(candidates[0], "/bundle/assets/font.ttf")
    @Expect(startupFontCandidates([], []).isEmpty())
}

@Test
func startupFontCandidatesRejectEmptyAndNulPathsAndPreserveSpaces(): Unit {
    let candidates = startupFontCandidates(["system.ttf"],
        ["", "system.ttf", "bad\u{0}.ttf", "font with spaces.ttf", "font with spaces.ttf"])
    @Expect(candidates.size, 2)
    @Expect(candidates[0], "system.ttf")
    @Expect(candidates[1], "font with spaces.ttf")
}
