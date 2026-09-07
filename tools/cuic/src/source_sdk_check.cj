package cuic

import std.collection.{ArrayList, HashMap}
import std.process.executeWithOutput

class SourceSdkInspection {
    let fields: HashMap<String, String>
    let ledger: String
    init(fields: HashMap<String, String>, ledger: String) {
        this.fields = fields
        this.ledger = ledger
    }
}

func inspectSourceSdk(framework: String): SourceSdkInspection {
    let resolved = canonicalPackagingPath(framework, "SDK framework")
    let manifest = joinPath(resolved, SOURCE_SDK_MANIFEST)
    requireFile(manifest, "expected an SDK framework directory with canghui-sdk.env")
    let fields = sourceSdkFields(readSourceSdkText(manifest, 16384), "", "", "macos-arm64", paired: false)
    let root = canonicalPackagingPath(joinPath(resolved, ".."), "SDK root")
    if (resolved != joinPath(root, "framework")) { throw CuicError("SDK framework must use its declared layout") }
    verifySourceSdkFiles(root, sourceSdkNativeNames(fields["nativeFiles"]))
    verifySourceSdkPackageIdentity(root, fields)
    SourceSdkInspection(fields, readSourceSdkText(joinPath(root, "SHA256SUMS"), 4194304))
}

func sourceSdkVersionRelation(current: String, candidate: String): String {
    let a = sourceSdkVersionParts(current, 3)
    let b = sourceSdkVersionParts(candidate, 3)
    for (i in 0..3) {
        if (b[i] > a[i]) { return "higher" }
        if (b[i] < a[i]) { return "lower" }
    }
    "equal"
}

func sourceSdkInspectionJson(info: SourceSdkInspection): String {
    let parts = ArrayList<String>()
    for (key in ["sourceCommit", "frameworkVersion", "kitVersion", "cuicVersion", "compilerVersion", "target", "minimumOS"]) {
        parts.add(cuicJsonQuote(key) + ":" + cuicJsonQuote(info.fields[key]))
    }
    let paired = info.fields["sourceCommit"] == CUIC_BUILD_REVISION && info.fields["cuicVersion"] == VERSION
    "{" + joinStrings(parts.toArray(), ",") +
        ",\"pairedWithThisCuic\":" + paired.toString() + ",\"integrityVerified\":true," +
        "\"publisherAuthenticated\":false}"
}

func sourceSdkComparisonJson(current: SourceSdkInspection, candidate: SourceSdkInspection): String {
    let changes = ArrayList<String>()
    for (key in ["sourceCommit", "frameworkVersion", "kitVersion", "cuicVersion", "compilerVersion", "target", "minimumOS", "nativeFiles"]) {
        if (current.fields[key] != candidate.fields[key]) { changes.add(cuicJsonQuote(key)) }
    }
    let sameCommit = current.fields["sourceCommit"] == candidate.fields["sourceCommit"]
    "{\"sourceRelation\":" + cuicJsonQuote(if (sameCommit) { "same-commit" } else { "different-commit-order-unknown" }) +
        ",\"frameworkVersionRelation\":" + cuicJsonQuote(sourceSdkVersionRelation(current.fields["frameworkVersion"], candidate.fields["frameworkVersion"])) +
        ",\"kitVersionRelation\":" + cuicJsonQuote(sourceSdkVersionRelation(current.fields["kitVersion"], candidate.fields["kitVersion"])) +
        ",\"samePayloadLedger\":" + (current.ledger == candidate.ledger).toString() +
        ",\"changedFields\":[" + joinStrings(changes.toArray(), ",") +
        "],\"runtimeCompatibility\":\"requires-consumer-regression\",\"automaticUpdate\":false}"
}

func sourceSdkHostCheck(fields: HashMap<String, String>): String {
    if (hostPlatform() != "macos" || hostArch() != "arm64") { return "unsupported-host-target" }
    try {
        let (code, output, _) = executeWithOutput("cjc", ["--version"])
        if (code != 0 || !sourceSdkCompilerMatches(String.fromUtf8(output))) { return "compiler-mismatch-or-unavailable" }
        let (osCode, osOutput, _) = executeWithOutput("/usr/bin/sw_vers", ["-productVersion"])
        if (osCode != 0 || !sourceSdkOSAtLeast(trimAscii(String.fromUtf8(osOutput)), fields["minimumOS"])) {
            return "minimum-os-not-met"
        }
        "prerequisites-match"
    } catch (_: Exception) {
        "host-check-unavailable"
    }
}

func sourceSdkCommand(args: Array<String>, start: Int64): Int64 {
    var json = false
    let values = ArrayList<String>()
    for (i in start..args.size) {
        if (args[i] == "--json") { json = true } else { values.add(args[i]) }
    }
    try {
        if (values.size < 2 || (values[0] != "verify" && values[0] != "compare") ||
            (values[0] == "verify" && values.size != 2) || (values[0] == "compare" && values.size != 3)) {
            throw CuicError("usage: cuic sdk verify <framework> [--json] | sdk compare <current-framework> <candidate-framework> [--json]")
        }
        let current = inspectSourceSdk(values[1])
        var report = "{\"protocol\":\"canghui.sdk-check/v1\",\"ok\":true,\"operation\":" + cuicJsonQuote(values[0]) +
            ",\"current\":" + sourceSdkInspectionJson(current)
        var host = sourceSdkHostCheck(current.fields)
        if (values[0] == "compare") {
            let candidate = inspectSourceSdk(values[2])
            report += ",\"candidate\":" + sourceSdkInspectionJson(candidate) +
                ",\"comparison\":" + sourceSdkComparisonJson(current, candidate)
            host = sourceSdkHostCheck(candidate.fields)
        }
        report += ",\"hostPrerequisites\":" + cuicJsonQuote(host) + ",\"modifiedFiles\":false}"
        if (!json) {
            println("SDK integrity and package identity verified. Host: " + host)
            println("Use the candidate's paired CUIC; verify its publisher and replay your application before upgrading.")
        }
        println(report)
        0
    } catch (error: Exception) {
        if (json) {
            println("{\"protocol\":\"canghui.sdk-check/v1\",\"ok\":false,\"error\":" + cuicJsonQuote(error.message) +
                ",\"modifiedFiles\":false}")
        } else { println("error: " + error.message) }
        1
    }
}
