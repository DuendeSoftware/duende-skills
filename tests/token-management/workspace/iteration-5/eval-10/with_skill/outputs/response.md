# Client Assertions (private_key_jwt) with the Correct Audience

Use `IClientAssertionService` to authenticate to the token endpoint with a signed JWT instead of a shared secret. The single most important detail is the **audience**.

## ⚠️ The audience CVE (CVE-2025-27370 / CVE-2025-27371)

Set the assertion JWT's `Audience` to the authorization server's **issuer URL** — **NOT** the token endpoint URL.

```csharp
// ❌ WRONG — token endpoint URL. Root cause of CVE-2025-27370 / CVE-2025-27371.
Audience = "https://identity.example.com/connect/token"

// ✅ CORRECT — the issuer URL from OIDC discovery (disco.Issuer)
Audience = "https://identity.example.com"
```

Authorization servers that accept **both** the issuer and the token endpoint as valid audiences are vulnerable to **token-endpoint confusion attacks**. Always use the issuer URL (the `issuer` value from the discovery document). To close the hole completely, also mark the JWT as a client-authentication assertion via its `typ` header (below), which opts into strict server-side audience validation (RFC 7523bis).

## Implementation

```csharp
using Duende.IdentityModel; // OidcConstants, JwtClaimTypes
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;

    public JwtClientAssertionService(SigningCredentials signingCredentials)
    {
        _signingCredentials = signingCredentials;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = "my_client_id",

            // ✅ CRITICAL: issuer URL, NOT the token endpoint — see CVE-2025-27370 / -27371
            Audience = "https://identity.example.com",

            IssuedAt = now,
            NotBefore = now,
            Expires = now.AddMinutes(5),
            SigningCredentials = _signingCredentials,

            // ✅ Sets the JWT "typ" header to client-authentication+jwt, opting into
            //    strict audience validation on the server (RFC 7523bis)
            AdditionalHeaderClaims = new Dictionary<string, object>
            {
                [JwtClaimTypes.TokenType] = "client-authentication+jwt"
            },

            Claims = new Dictionary<string, object>
            {
                ["sub"] = "my_client_id",
                ["jti"] = Guid.NewGuid().ToString()  // unique per assertion
            }
        };

        var handler = new JsonWebTokenHandler();
        var jwt = handler.CreateToken(descriptor);

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            // ✅ urn:ietf:params:oauth:client-assertion-type:jwt-bearer
            Type = OidcConstants.ClientAssertionTypes.JwtBearer,
            Value = jwt
        });
    }
}
```

## Registration

```csharp
builder.Services.AddSingleton<IClientAssertionService, JwtClientAssertionService>();
```

## Checklist

| Item | Value |
|---|---|
| Interface | `IClientAssertionService.GetClientAssertionAsync(...)` |
| **Audience** | Issuer URL (`disco.Issuer`), **never** the token endpoint URL |
| Assertion type | `OidcConstants.ClientAssertionTypes.JwtBearer` (`urn:ietf:params:oauth:client-assertion-type:jwt-bearer`) |
| `typ` header | `client-authentication+jwt` (via `AdditionalHeaderClaims`) → strict audience validation |
| `jti` | Unique per assertion (replay protection) |
| Lifetime | Short (e.g. 5 minutes) |
| DI | `AddSingleton<IClientAssertionService, JwtClientAssertionService>()` |

> Pair this with the server-side option `StrictClientAssertionAudienceValidation` on IdentityServer so the `typ` header + issuer audience are enforced, fully closing the token-endpoint confusion vector.
