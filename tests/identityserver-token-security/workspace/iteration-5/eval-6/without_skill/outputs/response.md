# FAPI 2.0 compliant IdentityServer + client

FAPI 2.0 is a security profile intended for high-value APIs such as open banking. It layers a number of hard requirements on top of ordinary OAuth 2.0: confidential clients only, strong asymmetric signing, sender-constrained tokens, PAR, PKCE, and tight validation windows. Here's how to approach it in Duende IdentityServer.

## Server configuration

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(opt =>
{
    // FAPI 2.0 requires strong asymmetric signatures such as PS256.
    opt.KeyManagement.SigningAlgorithms.Add(
        new Duende.IdentityServer.Configuration.SigningAlgorithmOptions(
            SecurityAlgorithms.RsaSsaPssSha256)); // PS256

    // Require PAR for all clients
    opt.PushedAuthorization.Required = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

A few additional FAPI 2.0 expectations to keep in mind on the server:

- Use only asymmetric algorithms (PS256 / ES256) — avoid HS256 / RS256 where the profile forbids it.
- Reduce the allowed clock skew for token/JWT validation to a small window so replay windows are minimized.
- Authenticate clients with `private_key_jwt` or mTLS, never plain shared secrets.
- Issue only sender-constrained (DPoP or mTLS-bound) tokens.

## FAPI 2.0 compliant client

```csharp
new Client
{
    ClientId = "openbanking_app",

    // Authorization code flow with PKCE (required)
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // Confidential client authenticating with private_key_jwt (a JWK, not a shared secret)
    RequireClientSecret = true,
    ClientSecrets =
    {
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.JsonWebKey,
            Value = "{\"kty\":\"RSA\",\"kid\":\"openbanking\",\"n\":\"...\",\"e\":\"AQAB\"}"
        }
    },

    RedirectUris = { "https://openbanking.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },
    AllowOfflineAccess = true,

    // Sender-constrained tokens via DPoP
    RequireDPoP = true,

    // PAR required
    RequirePushedAuthorization = true
}
```

## Why these choices

| FAPI 2.0 requirement | How it's met |
| --- | --- |
| Confidential client, strong client auth | `RequireClientSecret = true` + `JsonWebKey` secret (private_key_jwt) |
| Sender-constrained tokens | `RequireDPoP = true` |
| PAR | `PushedAuthorization.Required = true` and `RequirePushedAuthorization = true` |
| PKCE | `RequirePkce = true` |
| Strong signing | PS256 added to the key management signing algorithms |

## API side

Your resource servers should validate the access token as an `at+jwt` and additionally validate the DPoP proof, so that a token can only be used by the client that holds the bound key.

Note that FAPI 2.0 conformance is a licensed capability in Duende IdentityServer, so confirm your edition supports it before certifying.
