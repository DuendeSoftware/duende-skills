# Configuring Automatic Key Management with Custom Rotation Settings

Here's how to configure automatic key management on your IdentityServer with 30-day rotation, 5-day announcement, 7-day retention, and no deletion of retired keys.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Key rotates every 30 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);

    // Announce new key 5 days before it becomes active
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);

    // Keep retired keys in discovery for 7 days
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

## Key Lifecycle with These Settings

With the configuration above, keys will follow this lifecycle:

```
Announced --> Signing --> Retired (kept indefinitely)
   |             |            |
   5 days        25 days      7 days in discovery, then removed from discovery but NOT deleted
```

- **New key announced**: Published in the JWKS discovery document 5 days before it starts signing
- **Active signing**: The key signs tokens for 25 days (RotationInterval minus PropagationTime = 30 - 5 = 25 days)
- **Retired**: The key remains in discovery for 7 days after rotation for validation of tokens still in use
- **After retention**: The key is removed from discovery but NOT deleted from storage (`DeleteRetiredKeys = false`)

Setting `DeleteRetiredKeys = false` ensures you retain a historical record of all signing keys. This is useful for audit scenarios or if you need to validate very old tokens.

## Important Notes

- Automatic key management is **enabled by default** — no need to set `Enabled = true` explicitly
- Ensure `PropagationTime` is long enough for all clients and APIs to refresh their cached JWKS keys
- The default key storage is file-based at `{ContentRootPath}/keys` — for production multi-instance deployments, use EF Core operational store or a shared file system
