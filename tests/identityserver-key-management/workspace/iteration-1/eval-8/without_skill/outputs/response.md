# Custom Key Storage and Settings

Here's the updated `Program.cs` with custom key path, cache duration, and RSA key size:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Store keys on shared filesystem
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

    // Refresh key cache every hour
    options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

    // Use stronger 4096-bit RSA keys
    options.KeyManagement.RsaKeySize = 4096;
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

This changes the key storage to `/mnt/shared/identity-keys` (useful for sharing keys across load-balanced instances), sets the cache to refresh every hour, and increases the RSA key size to 4096 bits for stronger signatures.

Make sure all instances have read/write access to the shared path. You may also want to configure data protection for shared access if running multiple instances.
