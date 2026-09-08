# Configuring a client for JWT Secured Authorization Requests (JAR)

To force `secure_app` to always send a signed request object, set `RequireRequestObject = true` on the client and register the client's **public** signing key as a client secret of type `JsonWebKey` (for an RSA JWK) — or `X509CertificateBase64` if you hold the key as a certificate.

## Server-side client configuration (`Program.cs`)

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "secure_app",
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
    RequirePkce = true,
    RedirectUris = { "https://secure-app.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    // Force every authorize request to be a signed request object (JAR)
    RequireRequestObject = true,

    ClientSecrets =
    {
        // The client's PUBLIC RSA key, registered as a JWK.
        // IdentityServer uses it to verify the signature on the request object.
        new Duende.IdentityServer.Models.Secret
        {
            Type = Duende.IdentityServer.IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{'e':'AQAB','kid':'secure_app-sign','kty':'RSA','n':'...'}"
        }

        // Alternatively, register the key as a base64-encoded X.509 certificate:
        // new Duende.IdentityServer.Models.Secret
        // {
        //     Type = Duende.IdentityServer.IdentityServerConstants.SecretTypes.X509CertificateBase64,
        //     Value = Convert.ToBase64String(cert.Export(X509ContentType.Cert))
        // }
    }
}
```

## How the signing key is registered

JAR uses **asymmetric** signing:

- The client holds the **private** RSA key and uses it to sign the request object (a JWT) it sends to the authorize endpoint.
- IdentityServer holds the matching **public** key, registered as a `ClientSecret`. You register it either:
  - as a **JWK** (`SecretTypes.JsonWebKey`) — paste the public RSA JWK (`kty`, `n`, `e`, `kid`) as the secret `Value`, or
  - as a **base64-encoded X.509 certificate** (`SecretTypes.X509CertificateBase64`) — export the cert's public part with `Convert.ToBase64String(cert.Export(X509ContentType.Cert))`.

When an authorize request arrives, IdentityServer looks up the client's registered key and verifies the request object's signature against it, rejecting anything that isn't correctly signed.

> **Key reuse:** the *same* key can serve double duty — for `private_key_jwt` client authentication at the token endpoint **and** for signing JAR request objects. You don't need a separate key pair for each.

## What JAR gives you

JAR wraps all authorization request parameters (`scope`, `redirect_uri`, `state`, `nonce`, etc.) inside a single **signed JWT** — the *request object*. Because the JWT is signed with the client's private key:

- the parameters are **tamperproof** — an attacker cannot modify the scope, redirect URI, or any other parameter in transit without invalidating the signature, and
- it provides **front-channel client authentication**, since only the real client can produce a valid signature.

This is stronger than plain query-string parameters, which can be altered in the browser. If you use `request_uri` (passing the JWT by reference), IdentityServer can fetch the request object from that URL instead of receiving it inline.
