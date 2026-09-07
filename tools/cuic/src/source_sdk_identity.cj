package cuic

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.fs.{File, FileInfo}

func readSourceSdkText(path: String, limit: Int64): String {
    let info = FileInfo(path)
    if (!info.isRegular() || info.isSymbolicLink() || info.size > limit) {
        throw CuicError("source SDK metadata must be a bounded regular file: " + path)
    }
    let bytes = File.readFrom(path)
    if (bytes.size > limit) { throw CuicError("source SDK metadata exceeds size limit") }
    String.fromUtf8(bytes)
}

func sourceSdkCompilerMatches(output: String): Bool {
    let lines = trimAscii(output).split("\n")
    lines.size == 2 && trimAscii(lines[0]) == "Cangjie Compiler: 1.1.3 (cjnative)" &&
        trimAscii(lines[1]) == "Target: aarch64-apple-darwin"
}

func sourceSdkVersionParts(value: String, minimumParts: Int64): Array<Int64> {
    let parts = value.split(".")
    if (parts.size < minimumParts || parts.size > 3) { throw CuicError("invalid SDK version: " + value) }
    let result = ArrayList<Int64>()
    for (part in parts) {
        if (part.isEmpty() || part.size > 9) { throw CuicError("invalid SDK version: " + value) }
        for (r in part.toRuneArray()) {
            if (r < r'0' || r > r'9') { throw CuicError("invalid SDK version: " + value) }
        }
        result.add(Int64.parse(part))
    }
    result.toArray()
}

func sourceSdkPackageIdentityMatches(text: String, name: String, version: String): Bool {
    if (text.size > 65536) { return false }
    var inPackage = false
    var packageSeen = false
    var foundName = ""
    var foundVersion = ""
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        if (startsWithText(line, "[")) {
            inPackage = line == "[package]"
            if (inPackage && packageSeen) { return false }
            if (inPackage) { packageSeen = true }
            continue
        }
        if (!inPackage) { continue }
        let separator = indexOfText(line, "=")
        if (separator < 0) { continue }
        let key = trimAscii(substringTo(line, separator))
        if (key != "name" && key != "version") { continue }
        // Exported CJPM package names/versions are simple quoted strings, not expressions.
        let value = trimAscii(substringFrom(line, separator + 1))
        if (key == "name") {
            if (!foundName.isEmpty()) { return false }
            foundName = value
        } else {
            if (!foundVersion.isEmpty()) { return false }
            foundVersion = value
        }
    }
    foundName == "\"" + name + "\"" && foundVersion == "\"" + version + "\""
}

func verifySourceSdkPackageIdentity(root: String, fields: HashMap<String, String>): Unit {
    let framework = joinPath(root, "framework/cjpm.toml")
    let kit = joinPath(root, "framework/packages/kit/cjpm.toml")
    requireFile(framework, "source SDK framework package is missing")
    requireFile(kit, "source SDK Kit package is missing")
    if (!sourceSdkPackageIdentityMatches(readSourceSdkText(framework, 65536), "chui", fields["frameworkVersion"]) ||
        !sourceSdkPackageIdentityMatches(readSourceSdkText(kit, 65536), "canghui_kit", fields["kitVersion"])) {
        throw CuicError("source SDK package name/version differs from its manifest")
    }
}
