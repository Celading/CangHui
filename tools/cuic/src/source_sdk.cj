package cuic

import std.collection.{ArrayList, HashMap, HashSet}
import std.convert.*
import std.fs.{Directory, File, FileInfo, Path, exists}
import std.process.executeWithOutput

let SOURCE_SDK_MANIFEST = "canghui-sdk.env"

// A source SDK is an immutable delivery directory, not a writable framework checkout.
// Checksums detect corruption; they do not authenticate a publisher.
func sourceSdkFields(text: String, revision: String, cliVersion: String, target: String): HashMap<String, String> {
    let fields = HashMap<String, String>()
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        let separator = indexOfText(line, "=")
        if (separator <= 0) { throw CuicError("invalid source SDK manifest") }
        let key = substringTo(line, separator)
        let value = substringFrom(line, separator + 1)
        if (fields.contains(key) || value.isEmpty()) { throw CuicError("duplicate or empty source SDK field") }
        if (key != "schema" && key != "sourceCommit" && key != "cuicVersion" && key != "frameworkVersion" &&
            key != "kitVersion" && key != "compilerVersion" && key != "target" && key != "minimumOS" &&
            key != "nativeFiles") { throw CuicError("unknown source SDK field: " + key) }
        fields[key] = value
    }
    for (key in ["schema", "sourceCommit", "cuicVersion", "frameworkVersion", "kitVersion",
        "compilerVersion", "target", "minimumOS", "nativeFiles"]) {
        if (!fields.contains(key)) { throw CuicError("missing source SDK field: " + key) }
    }
    if (fields["schema"] != "canghui.source-sdk/v1" || fields["target"] != target || target != "macos-arm64") {
        throw CuicError("source SDK schema/target mismatch; v1 currently supports macos-arm64 only")
    }
    if (!validGitCommitId(fields["sourceCommit"]) || fields["sourceCommit"] != revision ||
        fields["cuicVersion"] != cliVersion) {
        throw CuicError("source SDK/CUIC identity mismatch; use the CUIC shipped in this SDK")
    }
    if (fields["compilerVersion"] != "1.1.3") { throw CuicError("unsupported source SDK compiler ABI") }
    fields
}

func sourceSdkNativeNames(value: String): Array<String> {
    let names = value.split(",")
    let seen = HashSet<String>()
    for (name in names) {
        if (name.isEmpty() || name == "." || name == ".." || name.contains("/") || name.contains("\\") ||
            !endsWithText(name, ".dylib") || seen.contains(name)) { throw CuicError("unsafe SDK native filename") }
        for (r in name.toRuneArray()) {
            let c = r.toString()
            if (!(c >= "a" && c <= "z") && !(c >= "A" && c <= "Z") && !(c >= "0" && c <= "9") &&
                c != "_" && c != "." && c != "-") { throw CuicError("unsafe SDK native filename") }
        }
        seen.add(name)
    }
    if (!seen.contains("libSDL3.dylib") || !seen.contains("libSDL3_ttf.dylib")) {
        throw CuicError("source SDK is missing required SDL libraries")
    }
    names
}

func verifySourceSdkFiles(root: String, nativeNames: Array<String>): Unit {
    let ledger = joinPath(root, "SHA256SUMS")
    requireFile(ledger, "source SDK checksum ledger is missing")
    let seen = HashSet<String>()
    for (line in String.fromUtf8(File.readFrom(ledger)).split("\n")) {
        if (line.isEmpty()) { continue }
        if (line.size < 67 || substringTo(substringFrom(line, 64), 2) != "  ") {
            throw CuicError("invalid source SDK checksum entry")
        }
        let relative = substringFrom(line, 66)
        validateManifestRelativePath(relative, "SDK checksum entry")
        let input = joinPath(root, relative)
        if (seen.contains(relative) || FileInfo(input).isSymbolicLink()) {
            throw CuicError("duplicate or symlink source SDK entry")
        }
        ensurePackagingPathStaysInsideProject(root, input, "SDK checksum entry")
        requireFile(input, "source SDK artifact is missing")
        seen.add(relative)
    }
    for (required in ["framework/" + SOURCE_SDK_MANIFEST, "framework/cjpm.toml", "framework/src/chui.cj",
        "bin/cuic", "bin/cuic-debug", "native/libSDL3.dylib", "native/libSDL3_ttf.dylib"]) {
        if (!seen.contains(required)) { throw CuicError("source SDK checksum coverage missing: " + required) }
    }
    for (name in nativeNames) {
        if (!seen.contains("native/" + name)) { throw CuicError("source SDK native checksum coverage missing") }
    }
    verifySourceSdkCoverage(root, seen)
    let (code, _, _) = executeWithOutput("/usr/bin/shasum", ["-a", "256", "-c", "SHA256SUMS"],
        workingDirectory: Path(root))
    if (code != 0) { throw CuicError("source SDK checksum verification failed") }
}

func verifySourceSdkCoverage(root: String, seen: HashSet<String>): Unit {
    let pending = ArrayList<String>()
    pending.add("")
    var index: Int64 = 0
    var count: Int64 = 0
    while (index < pending.size) {
        let directory = pending[index]
        index += 1
        for (entry in Directory.readFrom(joinPath(root, directory))) {
            count += 1
            if (count > 20000 || entry.isSymbolicLink()) { throw CuicError("SDK symlink or file-count limit exceeded") }
            let relative = if (directory.isEmpty()) { basename(entry.path.toString()) }
                else { directory + "/" + basename(entry.path.toString()) }
            if (entry.isDirectory()) { pending.add(relative) }
            else if (relative != "SHA256SUMS" && !seen.contains(relative)) {
                throw CuicError("unlisted file in immutable source SDK: " + relative)
            }
        }
    }
}

func bootstrapSourceSdk(framework: String, staging: String): Bool {
    let manifest = joinPath(framework, SOURCE_SDK_MANIFEST)
    if (!exists(manifest)) { return false }
    let root = canonicalPackagingPath(joinPath(framework, ".."), "source SDK root")
    let fields = sourceSdkFields(String.fromUtf8(File.readFrom(manifest)), CUIC_BUILD_REVISION,
        VERSION, hostPlatform() + "-" + hostArch())
    let names = sourceSdkNativeNames(fields["nativeFiles"])
    let (compilerCode, compilerOut, _) = executeWithOutput("cjc", ["--version"])
    if (compilerCode != 0 || !String.fromUtf8(compilerOut).contains("Cangjie Compiler: 1.1.3")) {
        throw CuicError("this source SDK requires Cangjie compiler 1.1.3")
    }
    let (osCode, osOut, _) = executeWithOutput("/usr/bin/sw_vers", ["-productVersion"])
    if (osCode != 0 || !sourceSdkOSAtLeast(trimAscii(String.fromUtf8(osOut)), fields["minimumOS"])) {
        throw CuicError("source SDK requires macOS " + fields["minimumOS"] + " or newer")
    }
    verifySourceSdkFiles(root, names)
    ensurePackagingDirectory(joinPath(staging, "sdl/.sdl3"))
    for (name in names) { copyNativeLibrary(joinPath(root, "native/" + name), joinPath(staging, "sdl/.sdl3/" + name)) }
    true
}

func sourceSdkOSAtLeast(actual: String, minimum: String): Bool {
    let a = actual.split(".")
    let b = minimum.split(".")
    if (a.size < 1 || b.size < 1 || a.size > 3 || b.size > 3) { throw CuicError("invalid SDK OS version") }
    var result: Int64 = 0
    for (i in 0..3) {
        let av = if (i < a.size) { Int64.parse(a[i]) } else { 0 }
        let bv = if (i < b.size) { Int64.parse(b[i]) } else { 0 }
        if (av < 0 || bv < 0) { throw CuicError("invalid SDK OS version") }
        if (result == 0 && av != bv) { result = if (av > bv) { 1 } else { -1 } }
    }
    result >= 0
}
