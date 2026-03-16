# Configuring Automatic Key Management

Here's the updated `Program.cs` with custom key management settings for 30-day rotation, 5-day propagation, 7-day retention, and no deletion of retired keys:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Key rotates every 30 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);

    // Announce new key 5 days before it becomes active
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);

    // Keep retired keys in discovery for 7 days for validation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);

    // Don't delete retired keys after the retention period
    options.KeyManagement.DeleteRetiredKeys = false;
})
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Lifecycle

With these settings, keys move through the following phases:

```
Announced --> Signing --> Retired --> (kept indefinitely)
  5 days      25 days     7 days
```

- **Announced (5 days):** The new key is published in the discovery document's JWKS endpoint so clients and APIs can cache it before it starts signing.
- **Signing (25 days):** The key is the active signing credential (RotationInterval minus PropagationTime = 30 - 5 = 25 days of active signing).
- **Retired (7 days):** The key remains in the discovery document for token validation but is no longer used for signing.
- **After retention:** Because `DeleteRetiredKeys = false`, the key material is preserved in the store but removed from the discovery document.

Setting `DeleteRetiredKeys = false` is useful for audit/compliance scenarios where you need to retain all historical key material.
