package chui.media

import std.io.InputStream
import std.sync.AtomicBool

/** Stable, redacted failure code. URLs, credentials and provider exception text are not included. */
public class NetworkResourceException <: Exception {
    public let code: String
    public init(code: String) { super("network-resource: " + code); this.code = code }
}

public enum NetworkResourceKind { | Data | Png | Bmp }

/** Return failures as UI-owner data instead of throwing out of worker preparation. */
public enum NetworkResourceResult {
    | Ready(NetworkResourceFile)
    | Failed(String)
}

/** One explicit GET. No ambient cookies, retries, redirects or URL-to-path conversion. */
public class NetworkResourceRequest {
    public let url: String
    public let kind: NetworkResourceKind
    public let timeoutMs: Int64
    private let fields: Array<(String, String)>

    public init(url: String, kind!: NetworkResourceKind = NetworkResourceKind.Data,
        headers!: Array<(String, String)> = [], timeoutMs!: Int64 = 15000) {
        if (timeoutMs < 1 || timeoutMs > 300000 || headers.size > 32) {
            throw NetworkResourceException("invalid-request")
        }
        let _ = networkResourceOrigin(url)
        var bytes: Int64 = 0
        for ((name, value) in headers) {
            bytes += name.size + value.size
            if (name.isEmpty() || name.size > 128 || value.size > 8192 || bytes > 32768) {
                throw NetworkResourceException("invalid-header")
            }
            for (b in name.toArray()) {
                if (!((b >= 65 && b <= 90) || (b >= 97 && b <= 122) ||
                    (b >= 48 && b <= 57) || b == 45)) {
                    throw NetworkResourceException("invalid-header")
                }
            }
            for (b in value.toArray()) {
                if (b < 32 || b == 127) { throw NetworkResourceException("invalid-header") }
            }
            let lower = name.toAsciiLower()
            if (lower == "host" || lower == "content-length" || lower == "transfer-encoding" ||
                lower == "connection" || lower == "accept-encoding") {
                throw NetworkResourceException("reserved-header")
            }
        }
        this.url = url; this.kind = kind; this.timeoutMs = timeoutMs; this.fields = headers.clone()
    }

    public func headers(): Array<(String, String)> { fields.clone() }
}

/** Cooperative cancellation; adapters must also bound blocking connect/read operations. */
public class NetworkResourceControl {
    private let cancelled = AtomicBool(false)
    public func cancel(): Unit { cancelled.store(true) }
    public func isCancelled(): Bool { cancelled.load() }
    public func check(): Unit {
        if (cancelled.load()) { throw NetworkResourceException("cancelled") }
    }
}

/** One-pass response. closeHandler must close the response AND any per-request client. */
public class NetworkResourceResponse <: Resource {
    public let status: Int64
    public let mediaType: String
    public let contentLength: ?Int64
    public let contentEncoding: String
    public let body: InputStream
    private let closeHandler: () -> Unit
    private var closed = false

    public init(status: Int64, body: InputStream, closeHandler: () -> Unit,
        mediaType!: String = "", contentLength!: ?Int64 = None, contentEncoding!: String = "") {
        this.status = status; this.body = body; this.closeHandler = closeHandler
        this.mediaType = mediaType; this.contentLength = contentLength; this.contentEncoding = contentEncoding
    }
    public func isClosed(): Bool { closed }
    public func close(): Unit {
        if (!closed) { closed = true; closeHandler() }
    }
}

/**
 * Trusted application adapter, called on the caller's worker. Implementations must stream bodies,
 * verify HTTPS certificates/hostnames, disable redirects and bound connect/read/header work.
 * This interface is not a sandbox for an untrusted implementation.
 */
public interface NetworkResourceTransport {
    func open(request: NetworkResourceRequest, control: NetworkResourceControl): NetworkResourceResponse
}

/** Adapts an existing HTTP client without inheritance or a framework dependency. */
public class CallbackResourceTransport <: NetworkResourceTransport {
    private let handler: (NetworkResourceRequest, NetworkResourceControl) -> NetworkResourceResponse
    public init(handler: (NetworkResourceRequest, NetworkResourceControl) -> NetworkResourceResponse) {
        this.handler = handler
    }
    public func open(request: NetworkResourceRequest, control: NetworkResourceControl): NetworkResourceResponse {
        handler(request, control)
    }
}

// Deliberately accepts only canonical ASCII HTTP(S) URLs. IDNs must be supplied as punycode.
// This is an origin gate, not DNS/IP pinning or a server-side SSRF firewall.
internal func networkResourceOrigin(url: String): String {
    if (url.size > 8192) { throw NetworkResourceException("invalid-url") }
    let start: Int64 = if (url.startsWith("https://")) { 8 } else if (url.startsWith("http://")) { 7 }
        else { throw NetworkResourceException("invalid-scheme") }
    let bytes = url.toArray()
    var end = bytes.size
    for (i in start..bytes.size) {
        let b = bytes[i]
        if (b <= 32 || b >= 127 || b == 92 || b == 35) { throw NetworkResourceException("invalid-url") }
        if (end == bytes.size && (b == 47 || b == 63)) { end = i }
    }
    if (end <= start) { throw NetworkResourceException("invalid-origin") }
    let authority = url[start..end]
    if (authority.contains("@") || authority.contains("%")) { throw NetworkResourceException("invalid-origin") }
    for (b in authority.toArray()) {
        if (!((b >= 97 && b <= 122) || (b >= 48 && b <= 57) ||
            b == 45 || b == 46 || b == 58 || b == 91 || b == 93)) {
            throw NetworkResourceException("invalid-origin")
        }
    }
    // Delegate address grammar to the trusted HTTP adapter; exact allowlist still applies.
    url[..end]
}

internal func networkResourceSuffix(kind: NetworkResourceKind): String {
    match (kind) { case NetworkResourceKind.Png => ".png" case NetworkResourceKind.Bmp => ".bmp"
        case NetworkResourceKind.Data => ".bin" }
}
