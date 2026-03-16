# FAPI 2.0 Compliance Configuration

FAPI 2.0 (Financial-grade API) is a security profile for OAuth 2.0 designed for high-value scenarios like open banking. Here's how to configure IdentityServer for FAPI 2.0 compliance.

## Server Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(opt =>
{
    // Require PAR globally
    opt.PushedAuthorization.Required = true;
    opt.PushedAuthorization.Lifetime = 600;
})
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
            ClientId = "fapi_banking_client",

            // Use private_key_jwt authentication (JWK secret)
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "{'e':'AQAB','kid':'fapi_key','kty':'RSA','n':'...'}"
                }
            },

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = true,

            RedirectUris = { "https://banking.example.com/callback" },
            AllowOfflineAccess = true,
            AllowedScopes = { "openid", "profile", "api1" },

            // Sender-constrained tokens
            RequireDPoP = true,

            // PAR required
            RequirePushedAuthorization = true,

            // No refresh token rotation per FAPI 2.0
            RefreshTokenUsage = TokenUsage.ReUse
        }
    ];
}
```

## FAPI 2.0 Key Requirements

| Requirement | Implementation |
|---|---|
| Confidential clients only | `RequireClientSecret = true` |
| Sender-constrained tokens | `RequireDPoP = true` or mTLS |
| Strong client authentication | `JsonWebKey` secret (private_key_jwt) or mTLS |
| PAR required | `RequirePushedAuthorization = true` |
| PKCE required | `RequirePkce = true` |
| No refresh token rotation | `RefreshTokenUsage = TokenUsage.ReUse` |

## Notes

- FAPI 2.0 requires either DPoP or mTLS for sender-constrained tokens. DPoP is generally easier to implement.
- Use `private_key_jwt` for client authentication instead of shared secrets.
- The authorization code lifetime should be short (60 seconds maximum per FAPI 2.0).
- Consider adding strict audience validation for client assertions.
