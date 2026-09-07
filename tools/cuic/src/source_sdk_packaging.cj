package cuic

import std.collection.ArrayList
import std.fs.File
import std.process.executeWithOutput

func sdkMacDependencyAllowed(dependency: String, names: Array<String>, native: Bool): Bool {
    if (startsWithText(dependency, "/usr/lib/") || startsWithText(dependency, "/System/Library/")) { return true }
    for (name in names) {
        if (dependency == "@rpath/" + name || (native && dependency == "@loader_path/" + name)) { return true }
    }
    false
}

func verifySdkMacDependencies(binary: String, names: Array<String>, native: Bool): Unit {
    let (code, bytes, _) = executeWithOutput("/usr/bin/otool", ["-L", binary])
    if (code != 0) { throw CuicError("cannot inspect source SDK application dependencies") }
    var first = true
    for (raw in String.fromUtf8(bytes).split("\n")) {
        if (first) { first = false; continue }
        let line = trimAscii(raw)
        if (line.isEmpty()) { continue }
        let separator = indexOfText(line, " (compatibility")
        if (separator < 0 || !sdkMacDependencyAllowed(substringTo(line, separator), names, native)) {
            throw CuicError("source SDK app has an unbundled dependency; use the static Cangjie runtime template: " + line)
        }
    }
}

func closeSourceSdkMacApp(framework: String, output: String, executableName: String,
    generated: ArrayList<String>, copied: ArrayList<String>): Unit {
    let manifest = joinPath(framework, SOURCE_SDK_MANIFEST)
    let fields = sourceSdkFields(String.fromUtf8(File.readFrom(manifest)), CUIC_BUILD_REVISION, VERSION,
        hostPlatform() + "-" + hostArch())
    let names = sourceSdkNativeNames(fields["nativeFiles"])
    let sdkRoot = canonicalPackagingPath(joinPath(framework, ".."), "source SDK root")
    verifySourceSdkFiles(sdkRoot, names)
    let binary = joinPath(output, "Contents/MacOS/" + executableName)
    verifySdkMacDependencies(binary, names, false)
    let nativeRoot = joinPath(output, "Contents/Frameworks")
    ensurePackagingDirectory(nativeRoot)
    for (name in names) {
        let source = joinPath(sdkRoot, "native/" + name)
        verifySdkMacDependencies(source, names, true)
        copyNativeLibrary(source, joinPath(nativeRoot, name))
        generated.add("Contents/Frameworks/" + name)
    }
    if (executeCommandQuiet("/usr/bin/install_name_tool", ["-add_rpath", "@executable_path/../Frameworks", binary], output) != 0) {
        throw CuicError("cannot add the app-relative SDK runtime search path")
    }
    if (executeCommandQuiet("/usr/bin/codesign", ["--force", "--sign", "-", binary], output) != 0) {
        throw CuicError("cannot ad-hoc sign the relocated app executable")
    }
    if (executeCommandQuiet("/usr/libexec/PlistBuddy", ["-c", "Add :LSMinimumSystemVersion string " + fields["minimumOS"],
        joinPath(output, "Contents/Info.plist")], output) != 0) {
        throw CuicError("cannot record the source SDK deployment floor")
    }
    let resourceRoot = joinPath(output, "Contents/Resources")
    copyPackagingResources(sdkRoot, ["licenses", "native-inventory.json"], resourceRoot,
        copied, "Contents/Resources")
}
