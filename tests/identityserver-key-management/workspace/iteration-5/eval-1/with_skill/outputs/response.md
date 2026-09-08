# Configuring Automatic Key Management Rotation

Automatic Key Management is enabled by default in Duende IdentityServer, so you only need to override the lifecycle durations. Your requirements map directly onto three `KeyManagementOptions` timings plus the delete flag:

| Requirement | Option | Value |
| --- | --- | --- |
| Rotate every 30 days | `RotationInterval` | `TimeSpan.FromDays(30)` |
| Announce 5 days before active | `PropagationTime` | `TimeSpan.FromDays(5)` |
| Keep retired keys 7 days | `RetentionDuration` | `TimeSpan.FromDays(7)` |
| Don't delete retired keys | `DeleteRetiredKeys` | `false` |

A key spends `PropagationTime` in the **Announced** phase (published in discovery but not yet signing), then signs for `RotationInterval - PropagationTime` days, then stays **Retired** for `RetentionDuration` (in discovery for validation only). With `DeleteRetiredKeys = false` the retired key material is kept rather than removed after retention.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Key rotates every 30 days
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);

        // Announce new key 5 days in advance in discovery (JWKS)
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);

        // Keep retired key for 7 days in discovery for validation
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);

        // Do not delete keys after their retention period ends
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

## Notes

- **Propagation vs. cache duration:** Make sure `PropagationTime` (5 days) is longer than the longest key cache duration used by your clients/APIs so newly announced keys are already cached before signing begins. With defaults this is fine, but verify if you shortened `KeyCacheDuration`.
- **Signing window:** With these values the active signing period is 30 − 5 = 25 days.
- **Retention:** `RetentionDuration` (7 days) should comfortably exceed your longest token lifetime so tokens signed with a retired key can still be validated. `DeleteRetiredKeys = false` means the key stays in the store even after it drops out of discovery — useful for audit/rollback but you'll accumulate keys over time.
