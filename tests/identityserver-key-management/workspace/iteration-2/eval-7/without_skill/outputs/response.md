# Fix CryptographicException in Load-Balanced IdentityServer

## Problem

The `CryptographicException: The key was not found in the key ring` error happens because the data protection keys aren't shared between your server instances. Each instance creates its own encryption keys, so when one instance tries to read a signing key that was encrypted by another instance, it fails.

## Solution

You need to configure a shared data protection key store and ideally also a shared signing key store.

Updated `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Configure data protection with shared storage
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/shared/dataprotection-keys"))
    .SetApplicationName("MyIdentityServer");

builder.Services.AddIdentityServer()
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

The key fix is `AddDataProtection()` with a shared persistence location and a consistent application name. You should also consider pointing the signing key storage to a shared location or database so all instances can access the same keys.
