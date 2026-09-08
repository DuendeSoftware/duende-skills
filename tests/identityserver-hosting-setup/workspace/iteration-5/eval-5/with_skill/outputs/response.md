# Configuring IdentityServerOptions + Data Protection for Multi-Instance

This sets the issuer, loads the license key from configuration, emits scopes as a space-delimited string in JWTs, and configures shared data protection with EF Core.

## Program.cs

```csharp
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// DbContext used both for data protection keys (and typically your config/operational stores)
builder.Services.AddDbContext<KeysDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentityServer(options =>
{
    // Fixed issuer name for tokens & discovery
    options.IssuerUri = "https://identity.mycompany.com";

    // License key from configuration (secret manager / env var / key vault),
    // NOT hardcoded in source control
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];

    // Emit the "scope" claim as a single space-delimited string in JWT access
    // tokens (RFC 9068 style) instead of an array
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
})
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Data protection for a multi-instance deployment: persist keys to a shared
// store (EF Core) and pin the application name so every instance uses the
// same key ring.
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<KeysDbContext>()
    .SetApplicationName("MyCompany.IdentityServer");

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Why each piece matters

| Setting | Purpose |
| ------- | ------- |
| `options.IssuerUri = "https://identity.mycompany.com"` | Forces a fixed issuer in discovery and tokens. Only set this when the server is reached on a different address than the expected issuer — otherwise prefer inferring it from the request. |
| `options.LicenseKey = builder.Configuration[...]` | Loads the Duende license from configuration. Keep it out of source-controlled `appsettings.json`; use a secret manager, environment variable, or key vault. |
| `options.EmitScopesAsSpaceDelimitedStringInJwt = true` | Emits the `scope` claim as one space-delimited string (`"scope": "api1 api2"`) instead of a JSON array. |

## Data protection notes (multi-instance)

Data protection protects signing keys at rest, persisted grants, server-side sessions, and auth cookies. For a load-balanced/multi-instance deployment you must:

- **`PersistKeysToDbContext<KeysDbContext>()`** — persist the key ring to durable, shared storage so keys survive restarts and every instance reads the same keys. (Azure Blob, Redis, or the file system on a shared volume are equally valid alternatives.)
- **`SetApplicationName("MyCompany.IdentityServer")`** — pin an explicit application name. Without it, ASP.NET Core isolates keys per application/deployment, so instances (or a redeploy) would fail to decrypt each other's cookies and grants.

> Note: data protection keys are **separate** from IdentityServer's token signing keys. Data protection keys are symmetric and never published; signing keys are asymmetric and their public part is exposed in discovery.
