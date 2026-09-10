package cuic

import std.collection.ArrayList
import std.convert.*

func prntxCommand(args: Array<String>, start: Int64): Int64 {
    requireDebugChannelBuild("cuic prntx")
    let forwarded = ArrayList<String>()
    var mode = "summary"
    var limit: Int64 = 32
    var node = "-"
    var i = start
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--format" || arg == "--limit" || arg == "--node") {
            if (i + 1 >= args.size) { throw CuicError(arg + " requires a value") }
            let value = args[i + 1]
            if (arg == "--format") { mode = value }
            else if (arg == "--limit") { limit = Int64.parse(value) }
            else { node = value }
            i += 2
        } else if (arg == "--json") { mode = "json"; i += 1 }
        else {
            forwarded.add(arg)
            // Script contents are opaque data, never parsed as prntx options.
            if (arg == "--events" || arg == "--script" || arg == "--columns" || arg == "--rows") {
                if (i + 1 >= args.size) { throw CuicError(arg + " requires a value") }
                forwarded.add(args[i + 1])
                i += 1
            }
            i += 1
        }
    }
    validatePrntxOptions(mode, limit, node)
    let parsed = parseProbeTarget(forwarded.toArray(), 0, true, allowAscii: mode == "ascii")
    let request = if (mode == "ascii") { "@cui-ascii ${parsed.columns} ${parsed.rows}\n" }
        else { "@cui-prntx ${mode} ${limit} ${node}\n" }
    runProbeExchange(parsed.project, "cui.probe.run", parsed.name + "\n" + request + parsed.script,
        parsed.name, mode == "json" || mode == "diff", quiet: true)
}

func validatePrntxOptions(mode: String, limit: Int64, node: String): Unit {
    if (mode != "summary" && mode != "tree" && mode != "json" && mode != "diff" && mode != "ascii") {
        throw CuicError("prntx --format requires summary, tree, json, diff, or ascii")
    }
    if (limit < 1 || limit > 128) { throw CuicError("prntx --limit must be between 1 and 128") }
    if (node.isEmpty() || node.contains(" ") || node.contains("\n") || node.contains("\r") || node.contains("\t")) {
        throw CuicError("prntx --node requires a nonempty single-token stable id")
    }
    if (node != "-" && (mode == "diff" || mode == "ascii")) {
        throw CuicError("prntx --node is supported by summary, tree and json")
    }
}
