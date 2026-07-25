macro package cui.kmode.macros

import std.ast.*
public import cui.kmode.{KModeCapability, KModeRegistration}

/**
 * Links one top-level (String) -> String function into the kMode registry.
 * The generated symbol is derived from the endpoint name, so duplicates in
 * one package fail during compilation before runtime registration.
 */
public macro KModeLink(attr: Tokens, input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let endpointName = parseEndpointName(attr)
    validateSignature(funcDecl)
    let symbol = Token(
        TokenKind.IDENTIFIER,
        "__canghui_kmode_link_" + endpointSymbol(endpointName)
    )
    let description = "linked function " + funcDecl.identifier.value
    return quote(
        $(input)
        public let $(symbol) = KModeRegistration(
            $(attr),
            $(description),
            KModeCapability.Invoke,
            { value: String => $(funcDecl.identifier)(value) }
        )
    )
}

func parseEndpointName(attr: Tokens): String {
    let raw = attr.toString()
    if (!raw.startsWith("\"") || !raw.endsWith("\"") || raw.size < 3) {
        throw Exception("KModeLink requires one string endpoint name")
    }
    let value = raw[1..raw.size - 1]
    validateEndpointName(value)
    value
}

func validateSignature(funcDecl: FuncDecl): Unit {
    if (funcDecl.funcParams.size != 1) {
        throw Exception("KModeLink requires exactly one String parameter")
    }
    let parameterType = funcDecl.funcParams[0].paramType.toTokens().toString()
    let returnType = funcDecl.declType.toTokens().toString()
    if (parameterType != "String" || returnType != "String") {
        throw Exception("KModeLink function signature must be (String) -> String")
    }
}

func validateEndpointName(value: String): Unit {
    var segmentStart = true
    for (r in value.toRuneArray()) {
        if (r == r'.') {
            if (segmentStart) {
                throw Exception("KModeLink endpoint has an empty segment")
            }
            segmentStart = true
        } else {
            let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
            let digit = r >= r'0' && r <= r'9'
            if ((!letter && !digit) || (segmentStart && digit)) {
                throw Exception(
                    "KModeLink endpoint segments accept letters/digits and start with a letter"
                )
            }
            segmentStart = false
        }
    }
    if (segmentStart) {
        throw Exception("KModeLink endpoint must not be empty or end with a dot")
    }
}

func endpointSymbol(value: String): String {
    var out = ""
    for (r in value.toRuneArray()) {
        if (r == r'.') {
            out += "__"
        } else {
            out += r.toString()
        }
    }
    out
}
