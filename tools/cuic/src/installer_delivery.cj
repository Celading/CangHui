package cuic

import std.collection.ArrayList
import std.env.getCommandLine
import std.fs.exists
import std.process.executeWithOutput

// Delivery resources belong to CUIC, not to the application's framework checkout.
func installerDeliveryScript(): String {
    let source = joinPath(cliRoot(), "delivery/installer.py")
    if (exists(source)) { return source }
    var command = getCommandLine()[0]
    if (!startsWithText(command, "/") && !isWindowsAbsolute(command)) {
        let finder = if (hostPlatform() == "windows") { "where" } else { "which" }
        let (code, output, _) = executeWithOutput(finder, [command])
        if (code == 0) { command = trimAscii(String.fromUtf8(output).split("\n")[0]) }
    }
    if (!command.isEmpty() && exists(command)) {
        let directory = parentPath(canonicalPackagingPath(command, "CUIC executable"))
        let installed = joinPath(directory, "cuic-delivery/installer.py")
        if (exists(installed)) { return installed }
    }
    throw CuicError("CUIC delivery resources are missing; install a delivery-enabled CUIC bundle")
}

func applicationInstallerCommand(args: Array<String>, start: Int64): Int64 {
    let forwarded = ArrayList<String>()
    forwarded.add(installerDeliveryScript())
    for (i in start..args.size) { forwarded.add(args[i]) }
    executeCommand("python3", forwarded.toArray(), currentDirectory())
}
