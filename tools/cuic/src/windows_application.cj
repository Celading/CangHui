package cuic

import std.fs.{File, FileInfo, OpenMode}
import std.collection.ArrayList

// Post-link, pre-signing transformation. Preserve the compiler-selected runtime
// entry point: switching linker defaults can instead select WinMainCRTStartup.
// This is a structural safety gate, not a Windows loader or an antivirus check.
let WINDOWS_APPLICATION_MAX_BYTES: Int64 = 256 * 1024 * 1024

func validateWindowsExecutableRequest(platform: String, executable: String, console: Bool,
    harden: Bool, exports: Bool, runtimeManifest: String): Unit {
    if (console && executable.isEmpty()) { throw CuicError("--console requires --executable") }
    if (executable.isEmpty()) { return }
    if (platform != "windows" || harden || exports || !runtimeManifest.isEmpty()) {
        throw CuicError("--executable is Windows-only and cannot be combined with runtime/hardening options")
    }
    validateManifestRelativePath(executable, "executable")
    if (packagingExtension(executable) != "exe") { throw CuicError("Windows executable must end in .exe") }
}

func readWindowsApplicationExecutable(project: String, executable: String): Array<UInt8> {
    validateWindowsExecutableRequest("windows", executable, false, false, false, "")
    let root = canonicalPackagingPath(project, "project")
    let source = joinPath(project, executable)
    ensurePackagingInputTreeStaysInsideProject(root, source, "Windows executable")
    let info = FileInfo(source)
    if (!info.isRegular() || info.size < 128 || info.size > WINDOWS_APPLICATION_MAX_BYTES) {
        throw CuicError("Windows executable must be a regular PE file of at most 256 MiB")
    }
    let bytes = Array<UInt8>(info.size, repeat: UInt8(0))
    let input = File(source, OpenMode.Read)
    try {
        let buffer = Array<UInt8>(65536, repeat: UInt8(0))
        var filled: Int64 = 0
        while (filled < bytes.size) {
            let count = input.read(buffer)
            if (count <= 0 || count > bytes.size - filled) {
                throw CuicError("Windows executable changed size while being read")
            }
            for (index in 0..count) { bytes[filled + index] = buffer[index] }
            filled += count
        }
        if (input.read(buffer) != 0) { throw CuicError("Windows executable grew while being read") }
    } finally { input.close() }
    bytes
}

func buildProvidedWindowsArtifact(project: String, executable: String, requestedOutput: String,
    console: Bool, json: Bool): Int64 {
    let manifest = loadApplicationManifest(project)
    let output = resolvePackagingOutputRoot(project, "windows", manifest, requestedOutput)
    ensurePackagingOutputDoesNotOverlapInputs(project, output, manifest)
    // Reject malformed/signed inputs before creating the output tree. Re-read
    // and revalidate under the output lease before writing the actual image.
    let _ = windowsApplicationImage(readWindowsApplicationExecutable(project, executable), console)
    return withPackagingOutputLease(project, output, {=>
        let limitations = ArrayList<String>()
        for (item in applicationPackagingPlanForManifest(project, "windows", manifest).unsupportedCapabilities) {
            limitations.add(item)
        }
        for (item in ["unsigned-artifact", "native-runtime-dlls-not-included",
            "resource-inputs-not-compiled-into-pe", "windows-launch-and-input-not-verified",
            "console-output-requires-redirection-or-explicit-console-build"]) { limitations.add(item) }
        let receipt = writeApplicationPackagingArtifact(project, "windows", manifest, output, executable,
            "supplied-pe-validated-not-launched", limitations.toArray(), windowsConsole: console)
        File.writeTo(joinPath(output, applicationPackagingReceiptPath("windows")),
            renderApplicationPackagingReceiptJson(receipt).toArray())
        if (json) { println(renderApplicationPackagingReceiptJson(receipt)) }
        else { renderApplicationPackagingReceipt(receipt, output) }
        0
    })
}

func peRead16(bytes: Array<UInt8>, offset: Int64): Int64 {
    if (offset < 0 || offset > bytes.size - 2) { throw CuicError("truncated PE field") }
    Int64(bytes[offset]) + Int64(bytes[offset + 1]) * 256
}

func peRead32(bytes: Array<UInt8>, offset: Int64): Int64 {
    peRead16(bytes, offset) + peRead16(bytes, offset + 2) * 65536
}

func peWrite32(bytes: Array<UInt8>, offset: Int64, value: Int64): Unit {
    var remaining = value
    for (index in 0..4) {
        bytes[offset + index] = UInt8(remaining % 256)
        remaining /= 256
    }
}

func windowsApplicationImage(source: Array<UInt8>, console: Bool): Array<UInt8> {
    if (source.size < 128 || source.size > WINDOWS_APPLICATION_MAX_BYTES || peRead16(source, 0) != 0x5a4d) {
        throw CuicError("not a bounded DOS/PE executable")
    }
    let pe = peRead32(source, 0x3c)
    if (pe < 64 || pe > source.size - 24 || peRead32(source, pe) != 0x4550) {
        throw CuicError("invalid PE signature or offset")
    }
    let machine = peRead16(source, pe + 4)
    let sectionCount = peRead16(source, pe + 6)
    let optionalSize = peRead16(source, pe + 20)
    let flags = peRead16(source, pe + 22)
    let optional = pe + 24
    if ((flags & 2) == 0 || (flags & 0x2000) != 0 || sectionCount < 1 || sectionCount > 96 ||
        optionalSize > source.size - optional) { throw CuicError("PE must be an executable image, not a DLL") }
    let magic = peRead16(source, optional)
    let pe64 = magic == 0x20b
    if (!((pe64 && (machine == 0x8664 || machine == 0xaa64)) || (magic == 0x10b && machine == 0x14c))) {
        throw CuicError("unsupported PE architecture or optional header")
    }
    let directoryBase: Int64 = if (pe64) { 112 } else { 96 }
    if (optionalSize < directoryBase) { throw CuicError("truncated PE optional header") }
    let directoryCount = peRead32(source, optional + directoryBase - 4)
    if (directoryCount > 16 || directoryBase + directoryCount * 8 > optionalSize) {
        throw CuicError("invalid PE data directory bounds")
    }
    if (directoryCount > 4 && (peRead32(source, optional + directoryBase + 32) != 0 ||
        peRead32(source, optional + directoryBase + 36) != 0)) {
        throw CuicError("signed PE refused: supply an unsigned build and sign after packaging")
    }
    if (directoryCount > 14 && (peRead32(source, optional + directoryBase + 112) != 0 ||
        peRead32(source, optional + directoryBase + 116) != 0)) {
        throw CuicError("managed PE images are not supported")
    }
    let subsystem = peRead16(source, optional + 68)
    if (subsystem != 2 && subsystem != 3) { throw CuicError("PE is not a Windows GUI/console application") }
    let sections = optional + optionalSize
    let headers = peRead32(source, optional + 60)
    let entry = peRead32(source, optional + 16)
    if (sections + sectionCount * 40 > source.size || headers < sections + sectionCount * 40 || headers > source.size) {
        throw CuicError("truncated PE section table or headers")
    }
    var executableEntry = false
    for (index in 0..sectionCount) {
        let section = sections + index * 40
        let virtualSize = peRead32(source, section + 8)
        let address = peRead32(source, section + 12)
        let rawSize = peRead32(source, section + 16)
        let rawOffset = peRead32(source, section + 20)
        if (rawSize > 0 && (rawOffset < headers || rawOffset > source.size || rawSize > source.size - rawOffset)) {
            throw CuicError("PE section data is out of bounds")
        }
        let extent = if (virtualSize == 0) { rawSize } else { virtualSize }
        if ((peRead32(source, section + 36) & 0x20000000) != 0 && entry >= address &&
            entry - address < extent && entry - address < rawSize) { executableEntry = true }
    }
    if (!executableEntry) { throw CuicError("PE entry point is not backed by executable section data") }
    let result = source.clone()
    result[optional + 68] = if (console) { UInt8(3) } else { UInt8(2) }
    result[optional + 69] = 0
    peWrite32(result, optional + 64, 0)
    // IMAGE_OPTIONAL_HEADER.CheckSum: folded 16-bit words plus file length.
    var sum: Int64 = 0
    var index: Int64 = 0
    while (index < result.size) {
        sum += Int64(result[index])
        if (index + 1 < result.size) { sum += Int64(result[index + 1]) * 256 }
        sum = (sum & 0xffff) + (sum >> 16)
        index += 2
    }
    sum = (sum & 0xffff) + (sum >> 16)
    peWrite32(result, optional + 64, sum + result.size)
    result
}
