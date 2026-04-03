# Configure Shared Key Storage and Custom Cache Duration

To store keys on a shared file system and customize the cache and key size settings:

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Use shared file system for keys
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

        // Refresh key cache every hour
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

        // Use stronger RSA keys
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

This sets up the key storage path to a shared mount, reduces the cache duration from the default to 1 hour, and increases RSA key size to 4096 bits for stronger security.
