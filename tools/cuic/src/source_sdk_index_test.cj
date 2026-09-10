package cuic

import std.fs.{Directory, File, removeIfExists}

private func sdkIndexRow(): Array<String> {
    ["stable", "macos-arm64", "0.18.0", "0.1.0", "0.6.0", "1.1.3",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "https://releases.example.invalid/chui.tar.gz", "15.0.0", ""]
}

private func sdkIndexText(row: Array<String>): String {
    "canghui.sdk-release-index/v1\n" + SOURCE_SDK_INDEX_HEADER + "\n" + joinStrings(row, "\t") + "\n"
}

private func sdkIndexCurrent(): SourceSdkInspection {
    let manifest = "schema=canghui.source-sdk/v1\nsourceCommit=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n" +
        "cuicVersion=0.6.0\nframeworkVersion=0.17.0\nkitVersion=0.1.0\ncompilerVersion=1.1.3\n" +
        "target=macos-arm64\nminimumOS=15.0\nnativeFiles=libSDL3.dylib,libSDL3_ttf.dylib\n"
    SourceSdkInspection(sourceSdkFields(manifest, "", "", "", paired: false), "fixture-ledger")
}

@Test
func sdkIndexSelectsExplicitChannelAndTargetWithoutOrderingCommits(): Unit {
    let row = sdkIndexRow()
    let preview = sdkIndexRow(); preview[0] = "preview"; preview[2] = "0.19.0"
    let linux = sdkIndexRow(); linux[1] = "linux-arm64"; linux[9] = ""; linux[10] = "2.38"
    let text = sdkIndexText(row) + joinStrings(preview, "\t") + "\n" + joinStrings(linux, "\t") + "\n"
    let entries = parseSourceSdkIndex(text)
    @Expect(entries.size, Int64(3))
    let current = sdkIndexCurrent()
    let report = sourceSdkUpdateReport(current, entries, "stable")
    @Expect(report.contains("\"status\":\"newer-declared-version\""))
    @Expect(report.contains("different-commit-order-unknown"))
    @Expect(!report.contains("0.19.0"))
    for (fact in ["\"publisherAuthenticated\":false", "\"candidatePayloadVerified\":false",
        "\"automaticUpdate\":false", "\"networkAccessed\":false", "\"modifiedFiles\":false", "caller-pinned-index-only"]) {
        @Expect(report.contains(fact))
    }
    @Expect(sourceSdkUpdateReport(current, entries, "preview").contains("0.19.0"))
    @Expect(sourceSdkUpdateReport(current, parseSourceSdkIndex(sdkIndexText(linux)), "stable").contains("no-matching-target-channel"))
}

@Test
func sdkIndexClassifiesDowngradesCompilerChangesAndSameVersionRebuilds(): Unit {
    let current = sdkIndexCurrent()
    for ((version, kit, compiler, commit, expected) in [
        ("0.16.0", "0.2.0", "1.1.3", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "component-downgrade-review-required"),
        ("0.18.0", "0.0.9", "1.1.3", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "component-downgrade-review-required"),
        ("0.18.0", "0.1.0", "1.2.0", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "compiler-change-review-required"),
        ("0.17.0", "0.1.0", "1.1.3", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "different-source-order-unknown"),
        ("0.17.0", "0.1.0", "1.1.3", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "same-source-and-versions-payload-unverified")
    ]) {
        let row = sdkIndexRow(); row[2] = version; row[3] = kit; row[5] = compiler; row[6] = commit
        @Expect(sourceSdkUpdateReport(current, parseSourceSdkIndex(sdkIndexText(row)), "stable").contains(expected))
    }
}

@Test
func sdkIndexRejectsMalformedUnboundedAndAmbiguousMetadata(): Unit {
    let good = sdkIndexText(sdkIndexRow())
    for (text in ["", "canghui.sdk-release-index/v2\n" + SOURCE_SDK_INDEX_HEADER + "\n",
        good + joinStrings(sdkIndexRow(), "\t") + "\n", good + "\n", good + "bad\n"]) {
        var rejected = false
        try { let _ = parseSourceSdkIndex(text) } catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
    for ((column, value) in [(0, "nightly"), (1, "windows-x86_64"), (2, "0.18"), (3, "-1.0.0"),
        (4, "0.6.0\r"), (5, "1.1.3-beta"), (6, "HEAD"), (7, "abc"), (9, ""), (10, "2.38")]) {
        let row = sdkIndexRow(); row[column] = value
        var rejected = false
        try { let _ = parseSourceSdkIndex(sdkIndexText(row)) } catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
    var oversized = good
    while (oversized.size <= 262144) { oversized += good }
    var rejected = false
    try { let _ = parseSourceSdkIndex(oversized) } catch (_: CuicError) { rejected = true }
    @Expect(rejected)
}

@Test
func sdkIndexRejectsUnsafeArchiveLocationsAndDigestForms(): Unit {
    for (url in ["http://example.org/a", "file:///tmp/a", "https://user:pass@example.org/a",
        "https://example.org/a#fragment", "https://example.org/", "https://example.org/a b",
        "https://example.org/a\nb", "https://example.org/a\\b", "https://example.org:443/a", "https:///a"]) {
        @Expect(!sourceSdkArchiveUrlValid(url))
    }
    @Expect(sourceSdkArchiveUrlValid("https://example.org/releases/a.tar.gz?download=1"))
    @Expect(!sourceSdkDigestValid("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"))
    @Expect(!sourceSdkDigestValid(""))
}

@Test
func sdkIndexVerifiesPinnedDigestBeforeParsingAndRejectsSpecialMetadata(): Unit {
    let root = joinPath(currentDirectory(), "target/sdk-index-digest-fixture")
    Directory.create(root, recursive: true)
    let input = joinPath(root, "index with spaces")
    File.writeTo(input, "abc".toArray())
    let digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    @Expect(readTrustedSourceSdkIndex(input, digest), "abc")
    for ((path, expected) in [(input, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        (root, digest), (input, "bad")]) {
        var rejected = false
        try { let _ = readTrustedSourceSdkIndex(path, expected) } catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
    _ = removeIfExists(root, recursive: true)
}

@Test
func sdkUpdatesRejectsInvalidCommandShape(): Unit {
    for (args in [["updates", "--json"], ["updates", "/missing", "--json"],
        ["updates", "/missing", "--index", "file", "--index", "file", "--json"],
        ["updates", "/missing", "--json", "--json"],
        ["updates", "/missing", "--unknown", "value", "--json"]]) {
        @Expect(sourceSdkCommand(args, 0), 1)
    }
    @Expect(helpText().contains("cuic sdk updates"))
}
