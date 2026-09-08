package cuic

/** Build/test options are strict: an ignored profile would invalidate the test evidence. */
func parseCjpmProfile(args: Array<String>, start: Int64): (ProjectSelection, String) {
    var platform = hostPlatform()
    var index = start
    if (index < args.size && isPlatform(args[index])) {
        platform = normalizePlatform(args[index])
        index += 1
    }
    var requested = ""
    var hasProject = false
    var hasMode = false
    var mode = "release"
    while (index < args.size) {
        let value = args[index]
        if (value == "--mode") {
            if (hasMode || index + 1 >= args.size) {
                throw CuicError("build/test requires one --mode release|debug value")
            }
            mode = args[index + 1]
            if (mode != "release" && mode != "debug") {
                throw CuicError("build/test mode must be release or debug")
            }
            hasMode = true
            index += 2
        } else {
            if (value.startsWith("-") || hasProject) {
                throw CuicError("unexpected build/test argument: ${value}")
            }
            requested = value
            hasProject = true
            index += 1
        }
    }
    (ProjectSelection(platform, resolveProject(requested, "")), mode)
}

func cjpmProfileArguments(action: String, mode: String): Array<String> {
    if (action != "build" && action != "test") { throw CuicError("unsupported profile action: ${action}") }
    match (mode) {
        case "debug" => [action, "-g"]
        case "release" => [action]
        case _ => throw CuicError("build/test mode must be release or debug")
    }
}
