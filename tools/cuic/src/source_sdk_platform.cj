package cuic

import std.collection.{HashMap, HashSet}

func sourceSdkLinuxTarget(target: String): Bool {
    target == "linux-arm64" || target == "linux-x86_64"
}

func sourceSdkTargetForHost(platform: String, arch: String): String {
    let normalized = if (platform == "linux" && arch == "aarch64") { "arm64" } else { arch }
    platform + "-" + normalized
}

func sourceSdkHostTarget(): String {
    sourceSdkTargetForHost(hostPlatform(), hostArch())
}

func requireSourceSdkExecutionTarget(target: String): Unit {
    if (target != "macos-arm64") {
        throw CuicError("Linux source SDK execution is not enabled in this build; metadata inspection only")
    }
}

func validateSourceSdkPlatformFields(fields: HashMap<String, String>, requested: String): Unit {
    let target = fields["target"]
    if (!requested.isEmpty() && target != requested) { throw CuicError("source SDK target mismatch") }
    if (fields["schema"] == "canghui.source-sdk/v1" && target == "macos-arm64") {
        if (!fields.contains("minimumOS") || fields.contains("libc") || fields.contains("minimumLibc")) {
            throw CuicError("macOS source SDK requires minimumOS, not libc metadata")
        }
        let _ = sourceSdkVersionParts(fields["minimumOS"], 1)
    } else if (fields["schema"] == "canghui.source-sdk/v2" && sourceSdkLinuxTarget(target)) {
        if (fields.contains("minimumOS") || !fields.contains("libc") || !fields.contains("minimumLibc")) {
            throw CuicError("Linux source SDK requires explicit libc and minimumLibc")
        }
        if (fields["libc"] != "glibc") { throw CuicError("unsupported Linux source SDK libc") }
        let _ = sourceSdkVersionParts(fields["minimumLibc"], 2)
    } else {
        throw CuicError("unsupported source SDK schema/target")
    }
}

func sourceSdkTargetTriple(target: String): String {
    match (target) {
        case "macos-arm64" => "aarch64-apple-darwin"
        case "linux-arm64" => "aarch64-unknown-linux-gnu"
        case "linux-x86_64" => "x86_64-unknown-linux-gnu"
        case _ => ""
    }
}

func sourceSdkLibcMatches(output: String, minimum: String): Bool {
    let value = trimAscii(output)
    if (!startsWithText(value, "glibc ")) { return false }
    try { sourceSdkOSAtLeast(substringFrom(value, 6), minimum) }
    catch (_: CuicError) { false }
}

func sourceSdkLinuxLibraryName(name: String): Bool {
    if (!startsWithText(name, "lib") || name.size > 128) { return false }
    for (r in name.toRuneArray()) {
        if (!(r >= r'a' && r <= r'z') && !(r >= r'A' && r <= r'Z') &&
            !(r >= r'0' && r <= r'9') && r != r'_' && r != r'.' && r != r'-' && r != r'+') { return false }
    }
    let marker = indexOfText(name, ".so")
    if (marker <= 3) { return false }
    let suffix = substringFrom(name, marker + 3)
    if (suffix.isEmpty()) { return true }
    if (!startsWithText(suffix, ".")) { return false }
    for (part in substringFrom(suffix, 1).split(".")) {
        if (part.isEmpty()) { return false }
        for (r in part.toRuneArray()) { if (r < r'0' || r > r'9') { return false } }
    }
    true
}

func sourceSdkLinuxNativeNames(value: String): Array<String> {
    let names = value.split(",")
    if (names.size > 128) { throw CuicError("source SDK native file count exceeds limit") }
    let seen = HashSet<String>()
    for (name in names) {
        if (!sourceSdkLinuxLibraryName(name) || seen.contains(name)) { throw CuicError("unsafe or duplicate Linux SDK library") }
        for (system in ["libc.so.6", "libm.so.6", "libpthread.so.0", "libdl.so.2", "librt.so.1", "libresolv.so.2", "libutil.so.1"]) {
            if (name == system) { throw CuicError("Linux SDK must not carry system baseline libraries") }
        }
        seen.add(name)
    }
    for (name in ["libSDL3.so", "libSDL3.so.0", "libSDL3_ttf.so", "libSDL3_ttf.so.0"]) {
        if (!seen.contains(name)) { throw CuicError("Linux SDK is missing SDL loader or linker files") }
    }
    names
}

func sourceSdkFieldOrEmpty(fields: HashMap<String, String>, key: String): String {
    if (fields.contains(key)) { fields[key] } else { "" }
}
