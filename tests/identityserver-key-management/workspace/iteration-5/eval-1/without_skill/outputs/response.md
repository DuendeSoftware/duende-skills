# Automatic Key Management Configuration

Duende IdentityServer's automatic key management is configured through the `KeyManagement` options on `AddIdentityServer`. It's on by default, so you just override the timing values. Your requirements translate to:

- **Rotate every 30 days** → `RotationInterval`
- **Announce 5 days before active** → `PropagationTime`
- **Keep retired keys 7 days** → `RetentionDuration`
- **Don't delete retired keys** → `DeleteRetiredKeys = false`

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);
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

## How the lifecycle works

- The new key is created and published in the JWKS/discovery document `PropagationTime` (5 days) before it becomes the active signing key.
- It signs tokens for roughly `RotationInterval - PropagationTime` (25 days).
- After rotation, the old key remains published for `RetentionDuration` (7 days) so existing tokens can still be validated.
- With `DeleteRetiredKeys = false`, the key is retained in storage rather than being purged.

Make sure `RetentionDuration` is longer than your access-token lifetime, and `PropagationTime` longer than clients' key cache time.
