package cui.kmode.linktest

import cui.kmode.{KModeOperation, KModePolicy, KModeRequest, dispatchKModeRequest}
import cui.kmode.macros.*

@KModeLink["tests.macro.echo"]
func linkedEcho(value: String): String {
    "linked:" + value
}

@Test
func macroLinkedEndpointIsRegisteredAndInvocable(): Unit {
    let response = dispatchKModeRequest(
        KModeRequest(11, KModeOperation.Invoke, endpoint: "tests.macro.echo", payload: "value"),
        policy: KModePolicy(enabled: true)
    )
    @Expect(response.ok)
    @Expect(response.payload, "linked:value")
}
