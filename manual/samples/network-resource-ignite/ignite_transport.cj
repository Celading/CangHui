package chui_network_sample

import chui.{NetworkResourceTransport, NetworkResourceRequest, NetworkResourceControl,
    NetworkResourceResponse, NetworkResourceException}
import ignite.client.{RequestBuilder, ClientResponse, ClientRetryConfig, ClientRequestHook,
    ClientResponseHook, ClientErrorHook, ClientObserveHook, ClientTransportTouchpointHook}
import std.collection.{HashMap, ArrayList}
import std.convert.Parsable
import stdx.net.http.ClientBuilder

/** Opt-in adapter recipe for Ignite 0.8.x. Core chui remains transport-free. */
public class IgniteResourceTransport <: NetworkResourceTransport {
    public func open(request: NetworkResourceRequest, control: NetworkResourceControl): NetworkResourceResponse {
        control.check()
        let timeout = Duration.millisecond * request.timeoutMs
        // RestClient's convenience constructor does not expose autoRedirect. Configure the
        // underlying client explicitly, then use Ignite's request/response pipeline.
        // stdx requires a positive pool size. This client is private to one request
        // and closed with its response; it is never shared across sessions.
        let client = ClientBuilder().autoRedirect(false).noProxy().poolSize(1)
            .maxHeaderListSize(UInt32(32768)).readTimeout(timeout).writeTimeout(timeout).build()
        var response: ?ClientResponse = None
        try {
            let builder = RequestBuilder(client, "", HashMap<String, String>(), None, None, None,
                ClientRetryConfig(enabled: false), "", false,
                ArrayList<ClientRequestHook>(), ArrayList<ClientResponseHook>(), ArrayList<ClientErrorHook>(),
                ArrayList<ClientObserveHook>(), ArrayList<ClientTransportTouchpointHook>(),
                readTimeout: timeout, writeTimeout: timeout)
            for ((name, value) in request.headers()) { let _ = builder.header(name, value) }
            let result = builder.method("GET").url(request.url).header("Accept-Encoding", "identity").send()
            response = Some(result)
            control.check()
            let lengths = result.headerValues("content-length")
            let encodings = result.headerValues("content-encoding")
            let types = result.headerValues("content-type")
            if (lengths.size > 1 || encodings.size > 1 || types.size > 1) {
                throw NetworkResourceException("ambiguous-response-headers")
            }
            let length: ?Int64 = if (lengths.isEmpty()) { None } else { Some(Int64.parse(lengths[0])) }
            return NetworkResourceResponse(Int64(result.status), result.bodyStream(), {=>
                try { result.close() } finally { client.close() }
            }, contentLength: length,
                mediaType: if (types.isEmpty()) { "" } else { types[0] },
                contentEncoding: if (encodings.isEmpty()) { "" } else { encodings[0] })
        } catch (error: Exception) {
            try { match (response) { case Some(value) => value.close() case None => () } }
            finally { client.close() }
            throw error
        }
    }
}
