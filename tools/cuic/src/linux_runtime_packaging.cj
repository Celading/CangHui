package cuic

func validateLinuxRuntimeRequest(platform: String, host: String, manifest: String): Unit {
    if (manifest.isEmpty()) { return }
    if (platform != "linux" || host != "linux") {
        throw CuicError("--runtime-manifest requires a same-host Linux package build")
    }
    validateManifestRelativePath(manifest, "runtime manifest")
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
