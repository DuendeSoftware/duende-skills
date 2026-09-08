# Configure Key Path, Cache Duration, and RSA Key Size

These are all properties of the `KeyManagement` options in Duende IdentityServer. Automatic key management stays enabled; you're just customizing where keys are stored, how long they're cached, and how big the RSA keys are.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Store keys on the shared file system
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";

        // Cache keys for 1 hour instead of the default 24 hours
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);

        // Use 4096-bit RSA keys instead of the default 2048
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

## Notes

- `KeyPath` must be a directory that all instances can read and write, and it should be excluded from source control.
- A 1-hour `KeyCacheDuration` makes instances re-read the key store more frequently, so they notice new keys sooner.
- `RsaKeySize = 4096` applies to newly generated keys; existing keys are not resized.
- Automatic key management remains enabled — none of these settings disable it.
