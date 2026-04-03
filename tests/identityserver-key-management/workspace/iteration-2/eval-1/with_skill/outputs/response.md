# Configure Automatic Key Management with Custom Rotation Settings

Update your `Program.cs` to configure the `KeyManagement` options with your desired rotation schedule:

```csharp
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

        // Don't delete retired keys after retention period
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

## What This Does

With automatic key management (enabled by default), IdentityServer handles the full key lifecycle:

1. **Announced** — New keys are published in the discovery document 5 days before they become active (`PropagationTime = 5 days`). This gives clients and APIs time to refresh their cached key sets.
2. **Signing** — After propagation, the key becomes the active signing credential for 25 days (RotationInterval minus PropagationTime).
3. **Retired** — Old keys remain in discovery for 7 days (`RetentionDuration = 7 days`) so tokens signed with them can still be validated.
4. **Retained** — With `DeleteRetiredKeys = false`, keys are never deleted from the key store after their retention period. This is useful for audit trails or if you need to validate very old tokens.

The default key store is file-based (stored in `{ContentRootPath}/keys`). For multi-instance deployments, you'll want to switch to a shared store like the EF operational store.
