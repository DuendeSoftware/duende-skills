# Fixing CryptographicException in Load-Balanced Deployment

## What's Happening

The `CryptographicException: The key was not found in the key ring` error typically means that the data protection keys used to encrypt your signing keys aren't being shared properly across instances. Each instance in the load balancer is using its own set of data protection keys, so when one instance tries to read a signing key that was encrypted by another instance, it can't find the matching data protection key.

## Fix

You need to configure ASP.NET Core Data Protection to use a shared storage so all instances can encrypt and decrypt with the same keys:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Configure shared data protection
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/shared/dataprotection-keys"))
    .SetApplicationName("IdentityServer");

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

Make sure `/shared/dataprotection-keys` is a path accessible by all instances (e.g., a network share or mounted volume). You could also use `PersistKeysToDbContext` or a cloud provider like `PersistKeysToAzureBlobStorage` for more robust storage.

The `SetApplicationName` call ensures all instances use the same application name, which is important for data protection key isolation.
