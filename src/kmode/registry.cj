package cui.kmode

import std.collection.ArrayList
import std.sync.Mutex

let kModeRegistryMutex = Mutex()
let kModeEndpoints = ArrayList<KModeEndpoint>()

/** Macro-generated package initialization installs one endpoint here. */
public class KModeRegistration {
    public let endpoint: KModeEndpoint

    public init(
        name: String,
        description: String,
        capability: KModeCapability,
        handler: KModeHandler
    ) {
        this.endpoint = registerKModeEndpoint(
            KModeEndpoint(name, description, capability, handler)
        )
    }
}

public func registerKModeEndpoint(endpoint: KModeEndpoint): KModeEndpoint {
    synchronized(kModeRegistryMutex) {
        for (existing in kModeEndpoints) {
            if (existing.name == endpoint.name) {
                throw IllegalStateException(
                    "duplicate kMode endpoint registration: " + endpoint.name
                )
            }
        }
        kModeEndpoints.add(endpoint)
    }
    endpoint
}

public func listKModeEndpoints(): Array<KModeEndpoint> {
    let copy = ArrayList<KModeEndpoint>()
    synchronized(kModeRegistryMutex) {
        for (endpoint in kModeEndpoints) {
            copy.add(endpoint)
        }
    }
    sortKModeEndpoints(copy.toArray())
}

public func findKModeEndpoint(name: String): ?KModeEndpoint {
    var found: ?KModeEndpoint = None
    synchronized(kModeRegistryMutex) {
        for (endpoint in kModeEndpoints) {
            if (endpoint.name == name) {
                found = Some(endpoint)
                break
            }
        }
    }
    found
}

public func dispatchKModeRequest(
    request: KModeRequest,
    policy!: KModePolicy = KModePolicy()
): KModeResponse {
    if (!policy.enabled) {
        return KModeResponse(
            request.id,
            false,
            "disabled",
            errorCode: -32000,
            errorMessage: "kMode is disabled"
        )
    }
    match (request.operation) {
        case KModeOperation.Health =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                KModeResponse(request.id, true, "ready", payload: KMODE_PROTOCOL)
            }
        case KModeOperation.List =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                KModeResponse(request.id, true, "ok", payload: renderKModeEndpointList())
            }
        case KModeOperation.Describe =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                describeKModeEndpoint(request)
            }
        case KModeOperation.Invoke =>
            invokeKModeEndpoint(request, policy)
        case KModeOperation.Shutdown =>
            if (!policy.allows(KModeCapability.Admin)) {
                capabilityDenied(request, KModeCapability.Admin)
            } else {
                KModeResponse(request.id, true, "stopping")
            }
    }
}

func renderKModeEndpointList(): String {
    var out = ""
    var first = true
    for (endpoint in listKModeEndpoints()) {
        if (!first) {
            out += "\n"
        }
        first = false
        out += endpoint.name
    }
    out
}

func describeKModeEndpoint(request: KModeRequest): KModeResponse {
    match (findKModeEndpoint(request.endpoint)) {
        case Some(endpoint) =>
            KModeResponse(
                request.id,
                true,
                "ok",
                payload: endpoint.name + "|" +
                    kModeCapabilityName(endpoint.capability) + "|" +
                    endpoint.description
            )
        case None => missingKModeEndpoint(request)
    }
}

func invokeKModeEndpoint(request: KModeRequest, policy: KModePolicy): KModeResponse {
    match (findKModeEndpoint(request.endpoint)) {
        case Some(endpoint) =>
            if (!policy.allows(endpoint.capability)) {
                return KModeResponse(
                    request.id,
                    false,
                    "forbidden",
                    errorCode: -32003,
                    errorMessage: "kMode capability denied: " +
                        kModeCapabilityName(endpoint.capability)
                )
            }
            try {
                KModeResponse(request.id, true, "ok", payload: endpoint.invoke(request.payload))
            } catch (error: Exception) {
                KModeResponse(
                    request.id,
                    false,
                    "handler-error",
                    errorCode: -32010,
                    errorMessage: error.message
                )
            }
        case None => missingKModeEndpoint(request)
    }
}

func missingKModeEndpoint(request: KModeRequest): KModeResponse {
    KModeResponse(
        request.id,
        false,
        "not-found",
        errorCode: -32601,
        errorMessage: "unknown kMode endpoint: " + request.endpoint
    )
}

func capabilityDenied(
    request: KModeRequest,
    capability: KModeCapability
): KModeResponse {
    KModeResponse(
        request.id,
        false,
        "forbidden",
        errorCode: -32003,
        errorMessage: "kMode operation " + kModeOperationName(request.operation) +
            " requires " + kModeCapabilityName(capability)
    )
}

func sortKModeEndpoints(values: Array<KModeEndpoint>): Array<KModeEndpoint> {
    var i: Int64 = 0
    while (i < values.size) {
        var j: Int64 = i + 1
        while (j < values.size) {
            if (values[j].name < values[i].name) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}
