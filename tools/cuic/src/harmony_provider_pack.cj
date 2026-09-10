package cuic

import std.collection.{ArrayList, HashSet}
import std.fs.{FileInfo, Path, exists}

let HARMONY_PROVIDER_SCHEMA = "canghui.harmony-provider/v1"
let HARMONY_FRAMEWORK_VERSION = "0.18.0"
let HARMONY_FRAMEWORK_ABI = "canghui.harmony-native-surface/v1"
let HARMONY_INPUT_ABI = "canghui.harmony-pointer/v2"
let HARMONY_PROVIDER_MANIFEST = "canghui-harmony-provider.env"

class HarmonyProviderPack {
    let root: String
    let providerVersion: String
    let frameworkCommit: String
    let targetAbi: String
    let artifacts: Array<String>
    let manifestDigest: String

    init(root: String, providerVersion: String, frameworkCommit: String, targetAbi: String,
        artifacts: Array<String>, manifestDigest: String) {
        this.root = root
        this.providerVersion = providerVersion
        this.frameworkCommit = frameworkCommit
        this.targetAbi = targetAbi
        this.artifacts = artifacts.clone()
        this.manifestDigest = manifestDigest
    }
}

func loadHarmonyProviderPack(requestedRoot: String): HarmonyProviderPack {
    if (requestedRoot.isEmpty()) { throw CuicError("--provider requires a directory") }
    let root = canonicalPackagingPath(requestedRoot, "Harmony provider root")
    if (!packagingDirectoryExists(root) || FileInfo(root).isSymbolicLink()) {
        throw CuicError("Harmony provider root must be a real directory: ${requestedRoot}")
    }
    let manifestPath = joinPath(root, HARMONY_PROVIDER_MANIFEST)
    if (!exists(manifestPath) || FileInfo(manifestPath).isSymbolicLink()) {
        throw CuicError("Harmony provider manifest is missing: ${manifestPath}")
    }
    let text = String.fromUtf8(readHarmonyRegularFile(manifestPath))
    let keys = HashSet<String>()
    var schema = ""
    var providerVersion = ""
    var frameworkVersion = ""
    var frameworkCommit = ""
    var frameworkAbi = ""
    var inputAbi = ""
    var projectionProtocol = ""
    var targetAbi = ""
    var artifactText = ""
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        let separator = indexOfText(line, "=")
        if (separator <= 0) { throw CuicError("invalid Harmony provider manifest line: ${line}") }
        let key = trimAscii(substringTo(line, separator))
        let value = trimAscii(substringFrom(line, separator + 1))
        if (value.isEmpty() || keys.contains(key)) {
            throw CuicError("invalid or duplicate Harmony provider key: ${key}")
        }
        keys.add(key)
        if (key == "schema") { schema = value }
        else if (key == "providerVersion") { providerVersion = value }
        else if (key == "frameworkVersion") { frameworkVersion = value }
        else if (key == "frameworkCommit") { frameworkCommit = value }
        else if (key == "frameworkAbi") { frameworkAbi = value }
        else if (key == "inputAbi") { inputAbi = value }
        else if (key == "projectionProtocol") { projectionProtocol = value }
        else if (key == "targetAbi") { targetAbi = value }
        else if (key == "artifacts") { artifactText = value }
        else { throw CuicError("unknown Harmony provider manifest key: ${key}") }
    }
    if (schema != HARMONY_PROVIDER_SCHEMA) {
        throw CuicError("Harmony provider schema mismatch: expected ${HARMONY_PROVIDER_SCHEMA}")
    }
    if (frameworkVersion != HARMONY_FRAMEWORK_VERSION) {
        throw CuicError("Harmony provider framework mismatch: expected ${HARMONY_FRAMEWORK_VERSION}, got ${frameworkVersion}")
    }
    if (frameworkAbi != HARMONY_FRAMEWORK_ABI || inputAbi != HARMONY_INPUT_ABI ||
        projectionProtocol != HARMONY_PROJECTION_PROTOCOL) {
        throw CuicError("Harmony provider ABI/projection contract does not match this CangHui release")
    }
    if (providerVersion.isEmpty() || !validGitCommitId(frameworkCommit) ||
        targetAbi != "arm64-v8a" || artifactText.isEmpty()) {
        throw CuicError("Harmony provider manifest is incomplete or targets an unsupported ABI")
    }
    let artifacts = ArrayList<String>()
    let paths = HashSet<String>()
    for (raw in artifactText.split(",")) {
        let relative = Path(trimAscii(raw)).normalize().toString()
        if (relative.isEmpty() || relative == "." || startsWithText(relative, "/") ||
            relative == ".." || startsWithText(relative, "../")) {
            throw CuicError("Harmony provider artifact path is unsafe: ${raw}")
        }
        let source = canonicalPackagingPath(joinPath(root, relative), "Harmony provider artifact")
        if (source == root || !startsWithText(source, root + "/") ||
            FileInfo(source).isSymbolicLink() || !FileInfo(source).isRegular()) {
            throw CuicError("Harmony provider artifact must be a regular file inside the provider root: ${relative}")
        }
        if (paths.contains(relative)) {
            throw CuicError("duplicate Harmony provider artifact path: ${relative}")
        }
        paths.add(relative)
        artifacts.add(relative)
    }
    HarmonyProviderPack(root, providerVersion, frameworkCommit, targetAbi, artifacts.toArray(),
        harmonyByteDigest(readHarmonyRegularFile(manifestPath)))
}

func validGitCommitId(value: String): Bool {
    if (value.toRuneArray().size != 40) { return false }
    for (r in value.toRuneArray()) {
        if (!((r >= r'0' && r <= r'9') || (r >= r'a' && r <= r'f'))) { return false }
    }
    true
}

func copyHarmonyProviderPack(pack: HarmonyProviderPack, output: String,
    generated: ArrayList<String>): Unit {
    let manifestSource = joinPath(pack.root, HARMONY_PROVIDER_MANIFEST)
    let manifestDestination = "native/provider/${HARMONY_PROVIDER_MANIFEST}"
    copyPackagingFile(manifestSource, joinPath(output, manifestDestination))
    generated.add(manifestDestination)
    for (relative in pack.artifacts) {
        let destination = "native/provider/pack/${relative}"
        copyPackagingFile(joinPath(pack.root, relative), joinPath(output, destination))
        generated.add(destination)
    }
}

func harmonyProviderDigest(pack: HarmonyProviderPack): String {
    let value = StringBuilder()
    value.append(pack.manifestDigest)
    for (relative in pack.artifacts) {
        value.append("|"); value.append(relative); value.append("=")
        value.append(harmonyByteDigest(readHarmonyRegularFile(joinPath(pack.root, relative))))
    }
    harmonyStableDigest(value.toString())
}
