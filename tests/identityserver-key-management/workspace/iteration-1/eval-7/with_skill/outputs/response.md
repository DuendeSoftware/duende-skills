# Fixing CryptographicException in Load-Balanced IdentityServer

## Problem

The `CryptographicException: The key was not found in the key ring` error occurs because **ASP.NET Core Data Protection keys are not shared across your load-balanced instances**. 

Here's what's happening:
1. Automatic key management creates a signing key on Instance A
2. The signing key data is encrypted using Instance A's Data Protection key
3. Instance B tries to load the signing key but has different Data Protection keys
4. Instance B cannot decrypt the signing key data → `CryptographicException`

The default Data Protection configuration uses machine-specific keys stored in a local directory. In a load-balanced environment, each instance has its own keys.

## Solution

You need to:
1. Share Data Protection keys across all instances
2. Switch from file-based to database-backed key storage for signing keys

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// Fix: Share Data Protection keys across all instances
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>()
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
    })
    // Fix: Use EF operational store for shared key storage
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Additional Recommendations

- Switch from the default file-based key storage (`{ContentRootPath}/keys`) to the EF Core operational store, which stores signing keys in the database (shared across all instances)
- Consider using `PersistKeysToAzureBlobStorage` or `PersistKeysToStackExchangeRedis` for Data Protection keys in cloud environments
- The `SetApplicationName()` call ensures all instances use the same application discriminator
