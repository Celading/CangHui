package cuic

import std.collection.ArrayList
import std.fs.exists

func validateLinuxRuntimeRequest(platform: String, host: String, manifest: String): Unit {
    if (manifest.isEmpty()) { return }
    if (platform != "linux" || host != "linux") {
        throw CuicError("--runtime-manifest requires a same-host Linux package build")
    }
    validateManifestRelativePath(manifest, "runtime manifest")
}

func linuxSdkPackagingFramework(project: String, platform: String, host: String, explicitManifest: String): String {
    if (platform != "linux" || host != "linux" || !explicitManifest.isEmpty()) { return "" }
    let spec = frameworkDependencySpec(project)
    if (!spec.isLocal()) { return "" }
    let dependency = if (startsWithText(spec.path, "/") || isWindowsAbsolute(spec.path)) { spec.path }
        else { joinPath(project, spec.path) }
    if (!exists(joinPath(dependency, SOURCE_SDK_MANIFEST))) { return "" }
    ensureFrameworkRoot(project)
}

func assembleLinuxSdkRuntime(framework: String, output: String, executable: String,
    identifier: String, copied: ArrayList<String>): Unit {
    let root = canonicalPackagingPath(joinPath(framework, ".."), "SDK root")
    let info = inspectSourceSdk(framework)
    let _ = sourceSdkFields(readSourceSdkText(joinPath(framework, SOURCE_SDK_MANIFEST), 16384),
        CUIC_BUILD_REVISION, VERSION, sourceSdkHostTarget())
    if (!sourceSdkLinuxTarget(info.fields["target"])) { throw CuicError("Linux packaging requires a Linux SDK") }
    let profile = joinPath(root, "runtime/native-input.json")
    let script = joinPath(framework, "scripts/assemble-linux-runtime.py")
    requireFile(profile, "SDK native input inventory is missing")
    requireFile(script, "SDK Linux assembler is missing")
    let code = executeCommandQuiet("python3", [script, "--output", output, "--binary", executable,
        "--manifest", profile, "--identifier=${identifier}", "--select-used-libraries"], output)
    if (code != 0) { throw CuicError("Linux SDK runtime assembly failed; no complete receipt was issued") }
    copyPackagingResources(root, ["licenses"], output, copied, "")
}

func assembleLinuxApplicationRuntime(project: String, output: String, executable: String,
    manifest: String, identifier: String): Unit {
    let framework = ensureFrameworkRoot(project)
    let script = joinPath(framework, "scripts/assemble-linux-runtime.py")
    requireFile(script, "Linux runtime assembler is missing from the resolved framework")
    requireFile(joinPath(framework, "scripts/audit-linux-runtime.py"), "Linux ELF auditor is missing")
    let code = executeCommandQuiet("python3", [script, "--output", output, "--binary", executable,
        "--manifest", joinPath(project, manifest), "--identifier=${identifier}"], project)
    if (code != 0) {
        throw CuicError("Linux runtime assembly failed; no complete packaging receipt was issued")
    }
}
