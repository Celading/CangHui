package cuic

/**
 * Build-time gate for privileged developer channels.
 *
 * Release builds retain explicit refusal functions so command compatibility is
 * stable, but cannot enter kMode/probe, debug, or device-capture execution.
 */
@When[debug]
public func debugChannelBuildEnabled(): Bool {
    true
}

@When[!debug]
public func debugChannelBuildEnabled(): Bool {
    false
}

/** This positive marker must never occur in a release executable. */
@When[debug]
public func debugChannelBuildMarker(): String {
    "CANGHUI_PRIVILEGED_DEBUG_BUILD=1"
}

@When[!debug]
public func debugChannelBuildMarker(): String {
    ""
}

func debugChannelRecoveryHint(channel: String): String {
    if (channel == "source-sdk") {
        return "use bin/cuic-debug shipped in the same source SDK; do not rebuild or modify the immutable SDK"
    }
    "use a matching cuic-debug; for a source checkout, build it with cuic build <platform> <framework>/tools/cuic --mode debug"
}

func requireDebugChannelBuild(operation: String): Unit {
    if (!debugChannelBuildEnabled()) {
        throw CuicError(
            "${operation} is unavailable in release cuic; " + debugChannelRecoveryHint(CUIC_BUILD_CHANNEL)
        )
    }
    if (debugChannelBuildMarker().isEmpty()) {
        throw CuicError("privileged debug build marker is unavailable")
    }
}
