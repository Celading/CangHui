package cuic

import std.collection.{ArrayList, HashMap}
import std.fs.{File, FileInfo, Path, exists}
import std.process.executeWithOutput

let PACKAGE_COMPILE_ENV = "CUIC_PACKAGE_COMPILE_OPTIONS"
let PACKAGE_LINK_ENV = "CUIC_PACKAGE_LINK_OPTIONS"
let PACKAGE_EXPORTS_FILE = "Contents/Resources/canghui-release-exports.txt"

func packageVariable(name: String): String { "$" + "{" + name + "}" }

class MacPackagingHardening {
    let enabled: Bool
    let exports: Array<String>

    init(enabled!: Bool = false, exports!: Array<String> = []) {
        if (!enabled && !exports.isEmpty()) { throw CuicError("--export-symbol requires --harden") }
        let names = ArrayList<String>()
        names.add("_main")
        if (exports.size > 128) { throw CuicError("package export policy exceeds 128 additional symbols") }
        for (name in exports) {
            if (!validMacExportSymbol(name) || applicationListContains(names.toArray(), name)) {
                throw CuicError("invalid or duplicate Mach-O export symbol: ${name}")
            }
            names.add(name)
        }
        this.enabled = enabled
        this.exports = names.toArray()
    }

    func linkOptions(): String {
        if (!enabled) { return "" }
        let out = StringBuilder()
        for (name in exports) { out.append("-exported_symbol ${name} ") }
        trimAscii(out.toString())
    }

    func exportList(): String {
        let out = StringBuilder()
        for (name in exports) { out.append(name + "\n") }
        out.toString()
    }
}

func validMacExportSymbol(name: String): Bool {
    if (!startsWithText(name, "_") || name.size < 2 || name.size > 256) { return false }
    for (r in name.toRuneArray()) {
        if (!(r >= r'a' && r <= r'z') && !(r >= r'A' && r <= r'Z') &&
            !(r >= r'0' && r <= r'9') && r != r'_') { return false }
    }
    true
}

// CJPM 1.1.3 splits single-quoted options at spaces; double quotes preserve one
// argument. Reject ambiguous characters instead of invoking a shell or widening
// the trim prefix to a user's home directory.
func quotedPackagingRoot(root: String): String {
    if (!startsWithText(root, "/") || root == "/" || root.size > 4096) {
        throw CuicError("hardening requires a bounded absolute source root")
    }
    for (r in root.toRuneArray()) {
        if (r < r' ' || r == r'"' || r == r'\\' || r == r'$' || r == r'`') {
            throw CuicError("source root cannot be represented safely in CJPM hardening options")
        }
    }
    "\"" + root + (if (endsWithText(root, "/")) { "" } else { "/" }) + "\""
}

func macPackagingCompileOptions(project: String, framework: String): String {
    let out = StringBuilder()
    for (root in [project, framework]) {
        let canonical = canonicalPackagingPath(root, "hardening source root")
        out.append("--trimpath " + quotedPackagingRoot(canonical) + " ")
        if (startsWithText(canonical, "/private/tmp/")) {
            out.append("--trimpath " + quotedPackagingRoot(substringFrom(canonical, 8)) + " ")
        }
    }
    trimAscii(out.toString())
}

// This is a narrow opt-in contract, not a TOML rewrite. CJPM retains ownership
// of profile/target merging, relative paths, locks and dependency resolution.
func requirePackagingBindings(text: String): Unit {
    var inPackage = false
    var compileBound = false
    var linkBound = false
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        if (startsWithText(line, "[")) { inPackage = line == "[package]"; continue }
        if (!inPackage) { continue }
        let separator = indexOfText(line, "=")
        if (separator < 0) { continue }
        let key = trimAscii(substringTo(line, separator))
        if (key != "override-compile-option" && key != "link-option") { continue }
        let value = parseManifestString(substringFrom(line, separator + 1), 0)
        if (key == "override-compile-option") { compileBound = value.contains(packageVariable(PACKAGE_COMPILE_ENV)) }
        else { linkBound = value.contains(packageVariable(PACKAGE_LINK_ENV)) }
    }
    if (!compileBound || !linkBound) {
        throw CuicError("--harden needs package override-compile-option/link-option CUIC bindings; " +
            "see manual/reference/application-packaging.zh-CN.md. No project configuration was rewritten.")
    }
}

func validateMacPackagingHardening(policy: MacPackagingHardening, platform: String,
    host: String, project: String, framework: String): Unit {
    if (!policy.enabled) { return }
    if (platform != "macos" || host != "macos") { throw CuicError("--harden requires a macOS host and target") }
    if (!exists(joinPath(framework, SOURCE_SDK_MANIFEST))) { throw CuicError("--harden currently requires a paired macOS source SDK") }
    requirePackagingBindings(readSourceSdkText(joinPath(project, "cjpm.toml"), 1048576))
    let audit = joinPath(framework, "scripts/audit-macos-release.sh")
    if (!exists(audit)) { throw CuicError("source SDK lacks the release audit; upgrade the paired SDK") }
    let info = FileInfo(audit)
    if (info.isSymbolicLink() || !info.isRegular()) { throw CuicError("source SDK lacks the regular release audit; upgrade the paired SDK") }
}

func packagingBuildEnvironment(inherited: HashMap<String, String>, compileOptions: String,
    linkOptions: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    for ((key, value) in inherited) { result.add(key, value) }
    result.add(PACKAGE_COMPILE_ENV, compileOptions)
    result.add(PACKAGE_LINK_ENV, linkOptions)
    result
}

func packagingInspectorEnvironment(): HashMap<String, String> {
    let result = HashMap<String, String>()
    result.add("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
    result.add("LC_ALL", "C")
    result.add("CANGHUI_MAX_RELEASE_SYMBOLS", "2000")
    return result
}

func runPackagingInspector(program: String, args: Array<String>, output: String, quiet: Bool): Unit {
    let (code, stdout, stderr) = executeWithOutput(program, args, workingDirectory: Path(output),
        environment: packagingInspectorEnvironment())
    if (!quiet || code != 0) {
        print(String.fromUtf8(stdout))
        print(String.fromUtf8(stderr))
    }
    if (code != 0) { throw CuicError("package hardening failed: ${program} (${code}); no acceptance receipt written") }
}

func hardenMacPackagingArtifact(receipt: ApplicationPackagingArtifactReceipt, output: String,
    framework: String, policy: MacPackagingHardening, quiet: Bool): ApplicationPackagingArtifactReceipt {
    let binary = joinPath(output, "Contents/MacOS/" + receipt.manifest.name)
    let exports = joinPath(output, PACKAGE_EXPORTS_FILE)
    File.writeTo(exports, policy.exportList().toArray())
    runPackagingInspector("/usr/bin/strip", ["-u", "-r", "-s", exports, binary], output, quiet)
    runPackagingInspector("/usr/bin/codesign", ["--force", "--sign", "-", binary], output, quiet)
    runPackagingInspector("/bin/bash", [joinPath(framework, "scripts/audit-macos-release.sh"), "--candidate", output], output, quiet)
    let generated = ArrayList<String>()
    for (file in receipt.generatedFiles) { generated.add(file) }
    generated.add(PACKAGE_EXPORTS_FILE)
    let limitations = ArrayList<String>()
    for (item in receipt.limitations) {
        if (item != "release-trimpath-and-strip-not-verified" && item != "release-security-audit-not-run") { limitations.add(item) }
    }
    limitations.add("export-policy-requires-application-and-plugin-runtime-regression")
    return ApplicationPackagingArtifactReceipt(receipt.platform, receipt.artifactKind, receipt.manifest,
        generated.toArray(), receipt.copiedAssets, receipt.executableIncluded, receipt.signed,
        receipt.hostReplay, limitations.toArray(), candidateAuditPassed: true)
}
