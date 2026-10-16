# Client assertions (private_key_jwt) – `IClientAssertionService`

## The CVE: audience
CVE-2025-27370 / CVE-2025-27371 came from setting the assertion's `aud` to the **token endpoint URL**. Servers accepting both values were open to token-endpoint confusion attacks. The audience must be the authorization server's **issuer** (from discovery: `issuer`).

```csharp
// ❌ Audience = "https://identity.example.com/connect/token"
// ✅ Audience = "https://identity.example.com"
```

## Implementation

```csharp
public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;

    public JwtClientAssertionService(SigningCredentials signingCredentials)
        => _signingCredentials = signingCredentials;

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = "my_client_id",
            // ✅ issuer URL, NOT the token endpoint
            Audience = "https://identity.example.com",
            Expires = now.AddMinutes(5),
            IssuedAt = now,
            NotBefore = now,
            SigningCredentials = _signingCredentials,
            // ✅ typed assertion → opts into strict audience validation (RFC 7523bis)
            AdditionalHeaderClaims = new Dictionary<string, object>
            {
                [JwtClaimTypes.TokenType] = "client-authentication+jwt"
            },
            Claims = new Dictionary<string, object>
            {
                ["sub"] = "my_client_id",
                ["jti"] = Guid.NewGuid().ToString()   // unique per assertion
            }
        };

        var jwt = new JsonWebTokenHandler().CreateToken(descriptor);

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            Type = OidcConstants.ClientAssertionTypes.JwtBearer,
            Value = jwt
        });
    }
}

builder.Services.AddSingleton<IClientAssertionService, JwtClientAssertionService>();
```

## Hardening
- Set the `typ` header to `client-authentication+jwt` (as above) and enable `StrictClientAssertionAudienceValidation` on IdentityServer so only the issuer audience is accepted.
- Take the issuer from the discovery document rather than hand-typing it.
- Keep lifetimes short, a new `jti` per assertion, and protect the private key (Key Vault / certificate store).

## With OpenID Connect
With `AddOpenIdConnectAccessTokenManagement`, the same service authenticates refresh/revoke calls; the library also adds the assertion to the authorization code exchange and, on .NET 9+, to PAR. JAR request objects are *not* created by the library; sign them in your own event handlers. Always **wrap** the library's existing `OpenIdConnectOptions.Events` handlers instead of replacing them, and never set `EventsType`.
