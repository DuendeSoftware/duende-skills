# Configuring a client for JWT Secured Authorization Requests (JAR)

JAR (also called "request objects", RFC 9101) lets a client send its authorization request as a signed JWT instead of plain query-string parameters. In Duende IdentityServer you force this per client with `RequireRequestObject` and register the client's public signing key as a client secret.

## Server-side client configuration

```csharp
new Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure-app.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    // Require a signed request object on every authorize request
    RequireRequestObject = true,

    ClientSecrets =
    {
        // Register the client's PUBLIC RSA key so IdentityServer can verify the signature
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{\"kty\":\"RSA\",\"kid\":\"secure_app\",\"n\":\"...\",\"e\":\"AQAB\"}"
        }
    }
}
```

## How the signing key is registered

JAR relies on asymmetric cryptography:

- The client keeps the **private** RSA key and uses it to sign the request object JWT.
- IdentityServer stores the corresponding **public** key. You register it as a `ClientSecret` with `Type = SecretTypes.JsonWebKey`, pasting the public RSA JWK (`kty`, `n`, `e`, `kid`) as the value. (You could also register the key as a certificate using `X509CertificateBase64`.)

At runtime, when `secure_app` sends an authorize request, it includes a `request` parameter containing the signed JWT. IdentityServer finds the client's registered public key and verifies the signature before honoring the request.

## What JAR protects against

Normally the authorization parameters (`scope`, `redirect_uri`, `state`, `nonce`, etc.) travel as plain query-string values that can be inspected and modified in the browser. JAR packages all of those parameters into a single JWT and signs it with the client's private key. Because any change to the payload breaks the signature, the parameters become **tamperproof** — the server rejects a request whose contents were altered in transit. It also authenticates the request as genuinely coming from the client.

If you prefer to pass the JWT indirectly, JAR also supports `request_uri`, where the client hosts the signed request object at a URL and IdentityServer fetches it.
