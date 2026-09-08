# Load-Balanced IdentityServer: Shared Keys and Data Protection

Running multiple IdentityServer instances behind a load balancer requires two things to be shared: the signing keys and the ASP.NET Core Data Protection key ring. By default both are stored per-instance (file system / machine keys), which breaks in a scaled-out deployment.

## Step 1 — Move signing key storage to the EF operational store (SQL Server)

Duende's operational store persists automatically managed signing keys (and grants) to the database, so all instances read the same keys.

## Step 2 — Persist Data Protection keys to the database

Data Protection encrypts the signing keys at rest. Persist its key ring to the database and pin a consistent application name so every instance can decrypt the shared keys.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")!;

// DbContext to hold the Data Protection key ring
builder.Services.AddDbContext<DataProtectionKeysContext>(options =>
    options.UseSqlServer(connectionString));

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
    // Store signing keys in SQL Server so all instances share them
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });

// Share the Data Protection key ring across instances via the database
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeysContext>()
    .SetApplicationName("IdentityServer");

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

public class DataProtectionKeysContext : DbContext, IDataProtectionKeyContext
{
    public DataProtectionKeysContext(DbContextOptions<DataProtectionKeysContext> options)
        : base(options) { }

    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = null!;
}
```

## Notes

- Automatic key management is left enabled (the default) — do not disable it. The shared database store means every instance uses the same signing keys.
- `SetApplicationName` must be the same string on every instance, otherwise Data Protection uses isolated key rings.
- Run EF migrations to create the operational store tables and the `DataProtectionKeys` table.
