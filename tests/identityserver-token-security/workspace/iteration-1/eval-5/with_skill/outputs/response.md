# Configuring JWT Secured Authorization Requests (JAR)

JAR wraps authorization request parameters in a signed JWT, making them tamperproof. Instead of passing `scope`, `redirect_uri`, `state`, etc. as plain query parameters in the authorize URL, the client packages them into a JWT signed with its private key and sends only the JWT (via the `request` parameter) or a reference to it (via `request_uri`).

## Server-Side Client Configuration

```csharp
// Program.cs
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "secure_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "https://secure-app.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Require signed request objects (JAR)
            RequireRequestObject = true,

            ClientSecrets =
            {
                new Secret
                {
                    // Register the client's public key as a JWK for request object signature validation
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "{'e':'AQAB','kid':'secure_app_key','kty':'RSA','n':'...'}"
                }
            }
        }
    ];
}
```

## How the Client's Signing Key is Registered

The client registers its **public key** as a `ClientSecret` with one of these types:

- **`IdentityServerConstants.SecretTypes.JsonWebKey`** — The public key in JWK format (JSON). This is the most common approach for RSA or ECDSA keys.
- **`IdentityServerConstants.SecretTypes.X509CertificateBase64`** — The public certificate in base64 DER encoding. Use this when the client has an X.509 certificate.

```csharp
// Alternative: Using an X.509 certificate
new Secret
{
    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
    Value = Convert.ToBase64String(cert.Export(X509ContentType.Cert))
}
```

The same key can be shared between **client authentication** (`private_key_jwt`) and **JAR** (signed authorization requests). This simplifies key management — the client uses one key pair for both proving its identity at the token endpoint and signing authorize request parameters.

## How JAR Works

1. **Client builds a request JWT**: The client creates a JWT containing all authorization parameters (`response_type`, `client_id`, `redirect_uri`, `scope`, `state`, `nonce`, `code_challenge`, etc.) and signs it with its private key.
2. **Client sends the signed request**: The authorize URL includes `request=<signed_jwt>` (by value) or `request_uri=<url>` (by reference).
3. **IdentityServer validates the signature**: It verifies the JWT signature using the registered `ClientSecret` (the public key).
4. **Parameters are extracted from the JWT**: IdentityServer uses the parameters from inside the JWT, ignoring any plain query parameters that conflict.

## Accessing Request Object Data

In custom code, you can access the original request object values:

- In `ValidatedAuthorizeRequest`: use the `RequestObjectValues` dictionary
- In UI code: call `IIdentityServerInteractionService.GetAuthorizationContextAsync()`, then access `RequestObjectValues` on the returned `AuthorizationRequest`

## Why JAR Matters

- **Tamperproof**: An attacker cannot modify authorization parameters in the redirect URL — the signature would be invalid.
- **Confidentiality**: When combined with encryption (JWE), parameters can be hidden from the browser.
- **Non-repudiation**: The signed JWT proves which client initiated the request.
- **FAPI compliance**: JAR is one of the mechanisms accepted by the FAPI 2.0 Security Profile.
