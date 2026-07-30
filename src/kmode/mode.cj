package cui.kmode

import std.env.{getCommandLine, getVariable}

@When[debug]
public func kModeDebugDefault(): Bool {
    true
}

@When[!debug]
public func kModeDebugDefault(): Bool {
    false
}

/** kMode is automatic for compiler debug builds and explicit for supervised runs. */
public func kModeEnabled(): Bool {
    if (kModeDebugDefault()) {
        return true
    }
    let value = environmentValue("CANGHUI_KMODE")
    value == "1" || value == "true" || value == "on"
}

public func kModeStdioRequested(): Bool {
    if (environmentValue("CANGHUI_KMODE_TRANSPORT") == "stdio") {
        return true
    }
    for (arg in getCommandLine()) {
        if (arg == "--kmode-stdio") {
            return true
        }
    }
    false
}

func environmentValue(name: String): String {
    match (getVariable(name)) {
        case Some(value) => value.trimAscii()
        case None => ""
    }
}

public class KModePolicy {
    public let enabled: Bool
    public let capabilities: Array<KModeCapability>

    public init(
        enabled!: Bool = kModeEnabled(),
        capabilities!: Array<KModeCapability> = [
            KModeCapability.Inspect,
            KModeCapability.Invoke,
            KModeCapability.Mutate,
            KModeCapability.Admin
        ]
    ) {
        this.enabled = enabled
        this.capabilities = capabilities
    }

    public func allows(capability: KModeCapability): Bool {
        if (!enabled) {
            return false
        }
        for (candidate in capabilities) {
            if (candidate == capability || candidate == KModeCapability.Admin) {
                return true
            }
        }
        false
    }
}
