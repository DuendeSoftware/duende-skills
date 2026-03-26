# Multi-Instance Deployment with EF Operational Store and Data Protection

For a load-balanced deployment, you need shared key storage and shared data protection configuration.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// Configure shared Data Protection for multi-instance deployment
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

## Why This Configuration

1. **`AddOperationalStore` with SQL Server**: Stores signing keys in the database so all instances share the same key material. The EF operational store (`PersistedGrantDbContext`) backs `ISigningKeyStore` automatically.

2. **`AddDataProtection().PersistKeysToDbContext<>()`**: Signing keys are encrypted at rest using ASP.NET Core Data Protection. Without shared DP keys, instance A encrypts a signing key that instance B cannot decrypt, causing `CryptographicException`.

3. **`SetApplicationName("IdentityServer")`**: Ensures all instances use the same application discriminator for Data Protection. Without this, keys protected on one instance cannot be unprotected on another.

4. **Automatic key management remains enabled (default)**: We do NOT set `KeyManagement.Enabled = false` — the operational store handles shared key storage.
