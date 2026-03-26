# Custom Key Path, Cache Duration, and RSA Key Size

Here's how to configure key storage on a shared file system, set the key cache duration to 1 hour, and increase RSA key size to 4096 bits.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Store keys on shared file system
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

    // Cache keys for 1 hour (default is 24 hours)
    options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

    // Increase RSA key size to 4096 bits (default is 2048)
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

## Configuration Notes

- **KeyPath**: The shared file system path must be read/write accessible by all load-balanced instances. The default is `{ContentRootPath}/keys`.
- **KeyCacheDuration**: Reducing from 24h to 1h means instances will re-read keys from storage more frequently. This provides faster key propagation at the cost of more I/O.
- **RsaKeySize**: 4096-bit RSA keys provide stronger security but are slower for signing and verification. Only use if required by your security policy.
- Automatic key management remains **enabled** (default) — these settings customize its behavior.
