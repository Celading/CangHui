package cuic

import std.collection.{ArrayList, HashMap, HashSet}
import std.process.executeWithOutput

let SOURCE_SDK_INDEX_HEADER = "channel\ttarget\tframeworkVersion\tkitVersion\tcuicVersion\tcompilerVersion\tsourceCommit\tarchiveSha256\tarchiveUrl\tminimumOS\tminimumLibc"

func sourceSdkDigestValid(value: String): Bool {
    if (value.size != 64) { return false }
    for (r in value.toRuneArray()) {
        if (!(r >= r'0' && r <= r'9') && !(r >= r'a' && r <= r'f')) { return false }
    }
    true
}

func sourceSdkArchiveUrlValid(value: String): Bool {
    if (!value.startsWith("https://") || value.size > 2048) { return false }
    let rest = substringFrom(value, 8)
    let slash = indexOfText(rest, "/")
    if (slash <= 0 || slash == rest.size - 1) { return false }
    let host = substringTo(rest, slash)
    if (host.startsWith(".") || host.endsWith(".") || !host.contains(".")) { return false }
    for (r in host.toRuneArray()) {
        if (!(r >= r'a' && r <= r'z') && !(r >= r'A' && r <= r'Z') &&
            !(r >= r'0' && r <= r'9') && r != r'.' && r != r'-') { return false }
    }
    for (r in rest.toRuneArray()) {
        if (r <= r' ' || r > r'~' || r == r'\\' || r == r'#' || r == r'@') { return false }
    }
    true
}

/** A channel points to one declared candidate per target, not a trusted Git ordering. */
func parseSourceSdkIndex(text: String): Array<HashMap<String, String>> {
    if (text.size > 262144) { throw CuicError("SDK release index exceeds 256 KiB") }
    let lines = text.split("\n")
    if (lines.size < 3 || lines[0] != "canghui.sdk-release-index/v1" || lines[1] != SOURCE_SDK_INDEX_HEADER) {
        throw CuicError("invalid SDK release index schema/header")
    }
    let keys = SOURCE_SDK_INDEX_HEADER.split("\t")
    let seen = HashSet<String>()
    let releases = ArrayList<HashMap<String, String>>()
    for (i in 2..lines.size) {
        if (i == lines.size - 1 && lines[i].isEmpty()) { continue }
        let values = lines[i].split("\t")
        if (values.size != keys.size || releases.size >= 64) { throw CuicError("invalid SDK release index row/count") }
        let fields = HashMap<String, String>()
        for (j in 0..keys.size) { fields[keys[j]] = values[j] }
        if (fields["channel"] != "stable" && fields["channel"] != "preview") { throw CuicError("invalid SDK release channel") }
        let target = fields["target"]
        if (!sourceSdkExecutionImplemented(target)) { throw CuicError("unsupported SDK release target") }
        let identity = fields["channel"] + "/" + target
        if (seen.contains(identity)) { throw CuicError("duplicate SDK release channel/target") }
        seen.add(identity)
        for (key in ["frameworkVersion", "kitVersion", "cuicVersion", "compilerVersion"]) {
            let _ = sourceSdkVersionParts(fields[key], 3)
        }
        if (!validGitCommitId(fields["sourceCommit"]) || !sourceSdkDigestValid(fields["archiveSha256"]) ||
            !sourceSdkArchiveUrlValid(fields["archiveUrl"])) { throw CuicError("invalid SDK release commit/archive descriptor") }
        if (target == "macos-arm64") {
            if (!fields["minimumLibc"].isEmpty()) { throw CuicError("macOS release cannot declare minimumLibc") }
            let _ = sourceSdkVersionParts(fields["minimumOS"], 1)
        } else {
            if (!fields["minimumOS"].isEmpty()) { throw CuicError("Linux release cannot declare minimumOS") }
            let _ = sourceSdkVersionParts(fields["minimumLibc"], 2)
        }
        releases.add(fields)
    }
    releases.toArray()
}

func readTrustedSourceSdkIndex(path: String, digest: String): String {
    if (!sourceSdkDigestValid(digest)) { throw CuicError("index --sha256 requires 64 lowercase hex digits") }
    // Reject special files before invoking an external checksum reader.
    let text = readSourceSdkText(path, 262144)
    let resolved = canonicalPackagingPath(path, "SDK release index")
    let checker = if (hostPlatform() == "linux") { "/usr/bin/sha256sum" } else { "/usr/bin/shasum" }
    let args = if (hostPlatform() == "linux") { ["--", resolved] } else { ["-a", "256", "--", resolved] }
    let (code, bytes, _) = executeWithOutput(checker, args)
    let output = String.fromUtf8(bytes)
    if (code != 0 || output.size < 64 || substringTo(output, 64) != digest) {
        throw CuicError("SDK release index digest mismatch")
    }
    if (readSourceSdkText(path, 262144) != text) { throw CuicError("SDK release index changed during verification") }
    text
}

func sourceSdkUpdateReport(current: SourceSdkInspection, entries: Array<HashMap<String, String>>, channel: String): String {
    var candidate: ?HashMap<String, String> = None
    for (entry in entries) {
        if (entry["target"] == current.fields["target"] && entry["channel"] == channel) { candidate = Some(entry) }
    }
    var detail = "\"status\":\"no-matching-target-channel\",\"candidate\":null"
    if (let Some(fields) <- candidate) {
        let relations = ArrayList<String>()
        var higher = false
        var lower = false
        for (key in ["frameworkVersion", "kitVersion", "cuicVersion"]) {
            let relation = sourceSdkVersionRelation(current.fields[key], fields[key])
            higher = higher || relation == "higher"
            lower = lower || relation == "lower"
            relations.add(cuicJsonQuote(key) + ":" + cuicJsonQuote(relation))
        }
        let sameCommit = fields["sourceCommit"] == current.fields["sourceCommit"]
        let sameCompiler = fields["compilerVersion"] == current.fields["compilerVersion"]
        let status = if (!sameCompiler) { "compiler-change-review-required" }
            else if (lower) { "component-downgrade-review-required" }
            else if (higher) { "newer-declared-version" }
            else if (!sameCommit) { "different-source-order-unknown" }
            else { "same-source-and-versions-payload-unverified" }
        let values = ArrayList<String>()
        for (key in SOURCE_SDK_INDEX_HEADER.split("\t")) { values.add(cuicJsonQuote(key) + ":" + cuicJsonQuote(fields[key])) }
        detail = "\"status\":" + cuicJsonQuote(status) + ",\"candidate\":{" + joinStrings(values.toArray(), ",") +
            "},\"componentVersionRelations\":{" + joinStrings(relations.toArray(), ",") +
            "},\"sourceRelation\":" + cuicJsonQuote(if (sameCommit) { "same-commit" } else { "different-commit-order-unknown" })
    }
    "{\"protocol\":\"canghui.sdk-updates/v1\",\"ok\":true,\"channel\":" + cuicJsonQuote(channel) +
        ",\"current\":" + sourceSdkInspectionJson(current) + "," + detail +
        ",\"indexDigestVerified\":true,\"publisherAuthenticated\":false,\"candidatePayloadVerified\":false," +
        "\"runtimeCompatibility\":\"requires-consumer-regression\",\"freshness\":\"caller-pinned-index-only\"," +
        "\"automaticUpdate\":false,\"networkAccessed\":false,\"modifiedFiles\":false}"
}

func sourceSdkUpdatesCommand(args: Array<String>, start: Int64): Int64 {
    var json = false
    for (i in start..args.size) { if (args[i] == "--json") { json = true } }
    try {
        if (start >= args.size || args[start].startsWith("-")) { throw CuicError("sdk updates requires a current framework") }
        let options = HashMap<String, String>()
        var index = start + 1
        var jsonSeen = false
        while (index < args.size) {
            let flag = args[index]
            if (flag == "--json") {
                if (jsonSeen) { throw CuicError("duplicate --json") }
                jsonSeen = true; index += 1; continue
            }
            if ((flag != "--index" && flag != "--sha256" && flag != "--channel") ||
                options.contains(flag) || index + 1 >= args.size || args[index + 1].isEmpty() || args[index + 1].startsWith("--")) {
                throw CuicError("invalid or duplicate sdk updates option: " + flag)
            }
            options[flag] = args[index + 1]; index += 2
        }
        if (!options.contains("--index") || !options.contains("--sha256")) { throw CuicError("sdk updates requires --index and trusted --sha256") }
        let channel = options.get("--channel") ?? "stable"
        if (channel != "stable" && channel != "preview") { throw CuicError("invalid SDK release channel") }
        let entries = parseSourceSdkIndex(readTrustedSourceSdkIndex(options["--index"], options["--sha256"]))
        let current = inspectSourceSdk(args[start])
        if (!json) { println("Read-only SDK release discovery; verify the archive and publisher before using the candidate's paired CUIC.") }
        println(sourceSdkUpdateReport(current, entries, channel))
        0
    } catch (error: Exception) {
        if (json) { println("{\"protocol\":\"canghui.sdk-updates/v1\",\"ok\":false,\"error\":" + cuicJsonQuote(error.message) + ",\"modifiedFiles\":false}") }
        else { println("error: " + error.message) }
        1
    }
}
