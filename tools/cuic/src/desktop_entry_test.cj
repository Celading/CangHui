package cuic

@Test
func linuxDesktopExecutableUsesValidatedIdentityNotDisplayText(): Unit {
    for (name in ["Demo", "Space Player", "Price $5", "Percent %f", "Tick `echo`", "Equal=Player", "仓绘"] ) {
        let manifest = parseApplicationManifest("[application]\nname=\"" + name + "\"\n" +
            "identifier=\"dev.example.launch\"\nversion=\"1.0.0\"\n")
        @Expect(isApplicationNameSafe(manifest.name))
        let entry = linuxDesktopEntry(manifest)
        @Expect(entry.contains("\nName=" + name + "\n"))
        @Expect(entry.contains("\nExec=dev.example.launch\n"))
    }
}

@Test
func linuxDesktopEntryPreservesDisplayNameWithoutFieldCodeExpansion(): Unit {
    let manifest = parseApplicationManifest("[application]\nname=\"Percent %f\"\n" +
        "identifier=\"dev.example.percent\"\nversion=\"1.0.0\"\n")
    @Expect(isApplicationNameSafe(manifest.name))
    let entry = linuxDesktopEntry(manifest)
    @Expect(entry.contains("\nName=Percent %f\n"))
    @Expect(entry.contains("\nExec=dev.example.percent\n"))
}

@Test
func desktopExecutableIdentityCannotCarryArgumentsOrFieldCodes(): Unit {
    for (invalid in ["demo arg", "demo%f", "demo$5", "demo=app", "demo`cmd`", "demo\\app"]) {
        @Expect(!isApplicationIdentifier(invalid))
    }
}
