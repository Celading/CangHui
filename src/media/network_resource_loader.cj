package chui.media

import std.collection.ArrayList
import std.fs.{Directory, File, OpenMode, canonicalize, removeIfExists}
import std.sync.Mutex
import std.time.MonoTime

/** Per-session download bounds, separate from decoded image/renderer budgets. */
public struct NetworkResourceOptions {
    public let maxResponseBytes: Int64
    public let maxRetainedBytes: Int64
    public let maxFiles: Int64
    public let maxConcurrent: Int64
    public let allowHttp: Bool
    public init(maxResponseBytes!: Int64 = 16777216, maxRetainedBytes!: Int64 = 67108864,
        maxFiles!: Int64 = 16, maxConcurrent!: Int64 = 4, allowHttp!: Bool = false) {
        if (maxResponseBytes < 1 || maxRetainedBytes < maxResponseBytes || maxFiles < 1 ||
            maxFiles > 4096 || maxConcurrent < 1 || maxConcurrent > 64 || maxConcurrent > maxFiles) {
            throw NetworkResourceException("invalid-options")
        }
        this.maxResponseBytes = maxResponseBytes; this.maxRetainedBytes = maxRetainedBytes
        this.maxFiles = maxFiles; this.maxConcurrent = maxConcurrent; this.allowHttp = allowHttp
    }
}

/**
 * Session-owned downloaded file. Keep it alive while its ImageView is in use.
 * Explicit close deletes only this file and its private directory, never the supplied cache root.
 */
public class NetworkResourceFile <: Resource {
    public let kind: NetworkResourceKind
    private let directory: String
    private let localPath: String
    private let control: NetworkResourceControl
    private let mutex = Mutex()
    private var busy = true
    private var ready = false
    private var released = false
    private var closing = false
    private var bytes: Int64 = 0

    internal init(directory: String, kind: NetworkResourceKind, control: NetworkResourceControl) {
        this.directory = directory; this.kind = kind; this.control = control
        this.localPath = directory + "/payload" + networkResourceSuffix(kind)
    }
    /** Available only after successful EOF and before close/cancellation. */
    public func path(): String {
        synchronized(mutex) {
            if (!ready || closing || control.isCancelled()) { throw NetworkResourceException("file-unavailable") }
            localPath
        }
    }
    public func sizeBytes(): Int64 { synchronized(mutex) { bytes } }
    public func isClosed(): Bool { synchronized(mutex) { closing || control.isCancelled() } }
    public func close(): Unit {
        synchronized(mutex) {
            closing = true; control.cancel()
            if (!busy) { cleanupLocked() }
        }
    }
    internal func writePath(): String { localPath }
    internal func accounting(reservation: Int64): (Bool, Bool, Int64) {
        synchronized(mutex) { (released, busy, if (ready) { bytes } else { reservation }) }
    }
    internal func complete(size: Int64): Unit {
        synchronized(mutex) {
            busy = false; bytes = size
            if (closing || control.isCancelled()) {
                closing = true; cleanupLocked(); throw NetworkResourceException("cancelled")
            }
            ready = true
        }
    }
    internal func abort(): Unit {
        synchronized(mutex) { busy = false; closing = true; control.cancel(); cleanupLocked() }
    }
    private func cleanupLocked(): Unit {
        if (released) { return }
        let _ = removeIfExists(localPath)
        let _ = removeIfExists(directory) // not recursive; never remove foreign files
        released = true; ready = false
    }
}

/**
 * Bounded, explicit download session. fetch is blocking: use UiTaskScope.prepare, not draw/build.
 * Successful files stay charged until closed; abandoned/cancelled UI results cannot grow storage
 * beyond this session's budget. close also cancels in-flight work cooperatively.
 */
public class NetworkResourceLoader <: Resource {
    private let transport: NetworkResourceTransport
    private let cacheRoot: String
    private let origins: Array<String>
    private let options: NetworkResourceOptions
    private let mutex = Mutex()
    private let files = ArrayList<NetworkResourceFile>()
    private var closed = false

    public init(transport: NetworkResourceTransport, cacheRoot: String, allowedOrigins: Array<String>,
        options!: NetworkResourceOptions = NetworkResourceOptions()) {
        if (allowedOrigins.isEmpty() || allowedOrigins.size > 64) { throw NetworkResourceException("invalid-origins") }
        for (origin in allowedOrigins) {
            if (networkResourceOrigin(origin) != origin || (origin.startsWith("http://") && !options.allowHttp)) {
                throw NetworkResourceException("invalid-origin")
            }
        }
        this.transport = transport; this.cacheRoot = canonicalize(cacheRoot).toString()
        this.origins = allowedOrigins.clone(); this.options = options
    }

    public func fetch(request: NetworkResourceRequest,
        control!: NetworkResourceControl = NetworkResourceControl()): NetworkResourceFile {
        control.check()
        let origin = networkResourceOrigin(request.url)
        var allowed = false
        for (entry in origins) { if (entry == origin) { allowed = true } }
        if (!allowed) { throw NetworkResourceException("origin-denied") }
        let file = admit(request.kind, control)
        let start = MonoTime.now()
        let check = { =>
            control.check()
            if ((MonoTime.now() - start).toMilliseconds() >= request.timeoutMs) {
                throw NetworkResourceException("timeout")
            }
        }
        try {
            check()
            let response = transport.open(request, control)
            var total: Int64 = 0
            try {
                check()
                validateNetworkResponse(response, request.kind, options.maxResponseBytes)
                let output = File(file.writePath(), OpenMode.Write)
                try {
                    let buffer = Array<UInt8>(min(Int64(65536), options.maxResponseBytes), repeat: 0)
                    while (true) {
                        check()
                        let count = response.body.read(buffer)
                        check()
                        if (count < 0 || count > buffer.size) { throw NetworkResourceException("invalid-read") }
                        if (count == 0) { break }
                        if (count > options.maxResponseBytes - total) { throw NetworkResourceException("too-large") }
                        total += count
                        match (response.contentLength) {
                            case Some(expected) => if (total > expected) { throw NetworkResourceException("length-mismatch") }
                            case None => ()
                        }
                        output.write(buffer[..count])
                    }
                    match (response.contentLength) {
                        case Some(expected) => if (total != expected) { throw NetworkResourceException("length-mismatch") }
                        case None => ()
                    }
                    if (total == 0) { throw NetworkResourceException("empty-body") }
                } finally { output.close() }
            } finally { response.close() }
            check()
            file.complete(total)
            file
        } catch (error: NetworkResourceException) {
            abortNetworkFile(file); throw error
        } catch (_: Exception) {
            abortNetworkFile(file); throw NetworkResourceException("transport-or-storage")
        }
    }

    /** Suitable for UiTaskScope.prepare: both success and failure reach the owner apply closure. */
    public func fetchResult(request: NetworkResourceRequest,
        control!: NetworkResourceControl = NetworkResourceControl()): NetworkResourceResult {
        try { NetworkResourceResult.Ready(fetch(request, control: control)) }
        catch (error: NetworkResourceException) { NetworkResourceResult.Failed(error.code) }
        catch (_: Exception) { NetworkResourceResult.Failed("transport-or-storage") }
    }

    public func isClosed(): Bool { synchronized(mutex) { closed } }
    public func close(): Unit {
        let snapshot = synchronized(mutex) { closed = true; files.toArray() }
        var failed = false
        for (file in snapshot) { try { file.close() } catch (_: Exception) { failed = true } }
        if (failed) { throw NetworkResourceException("cleanup-failed") }
    }

    private func admit(kind: NetworkResourceKind, control: NetworkResourceControl): NetworkResourceFile {
        synchronized(mutex) {
            if (closed) { throw NetworkResourceException("closed") }
            var retained: Int64 = 0
            var active: Int64 = 0
            var i = files.size - 1
            while (i >= 0) {
                let (released, busy, size) = files[i].accounting(options.maxResponseBytes)
                if (released) { files.remove(at: i) } else {
                    if (size > options.maxRetainedBytes - retained) { throw NetworkResourceException("capacity") }
                    retained += size
                    if (busy) { active += 1 }
                }
                i -= 1
            }
            if (files.size >= options.maxFiles || active >= options.maxConcurrent ||
                options.maxResponseBytes > options.maxRetainedBytes - retained) {
                throw NetworkResourceException("capacity")
            }
            let file = NetworkResourceFile(Directory.createTemp(cacheRoot).toString(), kind, control)
            files.add(file)
            file
        }
    }
}

private func abortNetworkFile(file: NetworkResourceFile): Unit {
    try { file.abort() } catch (_: Exception) { throw NetworkResourceException("cleanup-failed") }
}

private func validateNetworkResponse(response: NetworkResourceResponse, kind: NetworkResourceKind, limit: Int64): Unit {
    if (response.status != 200) { throw NetworkResourceException("http-status") }
    let encoding = response.contentEncoding.trimAscii().toAsciiLower()
    if (!encoding.isEmpty() && encoding != "identity") { throw NetworkResourceException("content-encoding") }
    match (response.contentLength) {
        case Some(length) => if (length < 0 || length > limit) { throw NetworkResourceException("too-large") }
        case None => ()
    }
    let mime = response.mediaType.trimAscii().toAsciiLower()
    match (kind) {
        case NetworkResourceKind.Png => if (mime != "image/png") { throw NetworkResourceException("content-type") }
        case NetworkResourceKind.Bmp => if (mime != "image/bmp" && mime != "image/x-ms-bmp") {
            throw NetworkResourceException("content-type")
        }
        case NetworkResourceKind.Data => ()
    }
}
