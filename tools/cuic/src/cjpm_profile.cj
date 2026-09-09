package cuic

import std.collection.ArrayList
import std.convert.*

/** Bound before parsing to reject overflow and avoid ambiguous signed/whitespace forms. */
func parseCjpmJobs(value: String): Int64 {
    if (value.isEmpty() || value.size > 3) { throw CuicError("--jobs must be an integer from 1 to 256") }
    for (r in value.toRuneArray()) {
        if (r < r'0' || r > r'9') { throw CuicError("--jobs must be an integer from 1 to 256") }
    }
    let jobs = Int64.parse(value)
    if (jobs < 1 || jobs > 256) { throw CuicError("--jobs must be an integer from 1 to 256") }
    jobs
}

/** Build/test options are strict: an ignored profile would invalidate the test evidence. */
func parseCjpmProfile(args: Array<String>, start: Int64): (ProjectSelection, String, Int64) {
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
    var jobs: Int64 = 0
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
        } else if (value == "--jobs") {
            if (jobs != 0 || index + 1 >= args.size) {
                throw CuicError("build/test requires one --jobs 1..256 value")
            }
            jobs = parseCjpmJobs(args[index + 1])
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
    (ProjectSelection(platform, resolveProject(requested, "")), mode, jobs)
}

func cjpmProfileArguments(action: String, mode: String, jobs!: Int64 = 0): Array<String> {
    if (action != "build" && action != "test") { throw CuicError("unsupported profile action: ${action}") }
    if (jobs < 0 || jobs > 256) { throw CuicError("build/test jobs must be omitted or from 1 to 256") }
    let result = ArrayList<String>()
    result.add(action)
    match (mode) {
        case "debug" => result.add("-g")
        case "release" => ()
        case _ => throw CuicError("build/test mode must be release or debug")
    }
    if (jobs != 0) { result.add("-j"); result.add(jobs.toString()) }
    result.toArray()
}
