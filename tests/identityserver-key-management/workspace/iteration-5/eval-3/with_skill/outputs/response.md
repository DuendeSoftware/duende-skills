# Multi-Instance Deployment: Shared Key Storage + Data Protection

Behind a load balancer you have **two** independent stores that must be shared across all instances, and they are easy to confuse:

1. **Signing key storage** — where IdentityServer's automatically-managed signing keys live. Default is the file system (`{ContentRootPath}/keys`), which is *not* shared. Move it to the **EF operational store** on SQL Server.
2. **ASP.NET Core Data Protection keys** — the symmetric keys used to *encrypt the signing keys at rest* (`DataProtectKeys = true` by default). These are separate from signing keys and must **also** be shared and given a stable application name, or one instance can't decrypt what another wrote (`CryptographicException: The key ... was not found in the key ring`).

Keep automatic key management **enabled** (the default) — `PropagationTime` and the shared store handle cross-instance coordination.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")!;
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    // Automatic key management stays enabled (default); keys are stored in the DB.
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
    // Signing keys (and other operational data) go to SQL Server, shared by all instances.
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    });

// Data Protection: persist the DP key ring to the DB and pin a stable application name
// so every instance shares the same keys used to encrypt the signing keys at rest.
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<Duende.IdentityServer.EntityFramework.DbContexts.PersistedGrantDbContext>()
    .SetApplicationName("My.IdentityServer");

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## What to do next

- **Run the operational store migrations** (or create the schema) so the `PersistedGrants`, key-management, and Data Protection key tables exist. The DP key ring is stored via the `PersistKeysToDbContext` DbContext.
- **Same application name everywhere:** `SetApplicationName("My.IdentityServer")` must be identical on every instance and stable across redeploys — changing it makes previously protected keys unreadable.
- **Do not disable key management.** Automatic key management remains on; with a shared DB store all instances see the same signing keys, and `PropagationTime` covers cache-refresh windows.

## Why both stores matter

| Store | Purpose | Shared how |
| --- | --- | --- |
| EF operational store | Holds the managed signing keys | `AddOperationalStore` → SQL Server |
| Data Protection key ring | Encrypts signing keys at rest | `PersistKeysToDbContext` + `SetApplicationName` |

If you only shared the signing keys but left Data Protection on per-instance file/machine keys, instance B could read the row instance A wrote but fail to *decrypt* it — the classic key-ring error.
