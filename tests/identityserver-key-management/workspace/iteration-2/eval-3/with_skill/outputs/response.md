# Configure EF Operational Store and Data Protection for Multi-Instance Deployment

For a load-balanced deployment, you need two things:
1. **Shared signing key storage** — Use the Entity Framework operational store backed by SQL Server so all instances share the same signing keys.
2. **Shared data protection** — Configure ASP.NET Core Data Protection with database persistence so keys encrypted by one instance can be decrypted by another.

Update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Configure ASP.NET Core Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<Duende.IdentityServer.EntityFramework.DbContexts.PersistedGrantDbContext>()
    .SetApplicationName("MyIdentityServer");

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
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

## What This Configures

### EF Operational Store
- `AddOperationalStore` configures IdentityServer to use the Entity Framework operational store for signing key storage (as well as persisted grants, device codes, etc.).
- `UseSqlServer(connectionString)` connects to your SQL Server database using the connection string from `appsettings.json`.
- Automatic key management remains enabled (the default), so IdentityServer handles key creation, rotation, and retirement automatically — all stored in the shared database.

### Data Protection
- `AddDataProtection()` configures ASP.NET Core Data Protection which IdentityServer uses to encrypt signing keys at rest (`DataProtectKeys = true` by default).
- `PersistKeysToDbContext<PersistedGrantDbContext>()` stores data protection keys in the database so all instances share the same encryption keys.
- `SetApplicationName("MyIdentityServer")` ensures a consistent application name across all instances. Without this, each instance may use a different application name, causing data protection key isolation.

### Why Both Are Needed
- Without shared **signing key storage**, each instance would create its own signing keys in its local file system — tokens signed by one instance couldn't be validated by another.
- Without shared **data protection**, even if signing keys are in a shared database, each instance encrypts keys with its own data protection key. Instance B can't decrypt a key that was encrypted by Instance A.

## Database Migration

Make sure to run EF migrations to create the necessary tables:

```bash
dotnet ef migrations add InitialIdentityServer -c PersistedGrantDbContext
dotnet ef database update -c PersistedGrantDbContext
```
