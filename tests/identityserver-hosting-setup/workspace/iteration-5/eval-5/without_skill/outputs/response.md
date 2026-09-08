# Configuring IdentityServerOptions and Data Protection

Here's how to set the issuer, load the license from configuration, change the JWT scope format, and share data protection keys across instances using EF Core.

## Program.cs

```csharp
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<DataProtectionKeysContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";

    // Read the license key from configuration rather than hardcoding it
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];

    // Emit scopes as a single space-delimited string in JWTs
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
})
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Shared data protection for multiple instances
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeysContext>()
    .SetApplicationName("MyCompany.IdentityServer");

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Explanation

- **`IssuerUri`** — sets a fixed `iss` value in tokens and the discovery document. Useful when you want a stable public issuer regardless of the internal request host.
- **`LicenseKey` from configuration** — Duende IdentityServer needs a license for production. Pull it from configuration (`appsettings`, environment variable, or a secret store) so it isn't hardcoded. Store the actual value in a secret manager, not in a committed file.
- **`EmitScopesAsSpaceDelimitedStringInJwt = true`** — changes the `scope` claim in JWT access tokens from a JSON array to a single space-delimited string.
- **Data protection** — in a multi-instance/load-balanced deployment every instance must share the same key ring:
  - `PersistKeysToDbContext<DataProtectionKeysContext>()` stores the keys in a shared database (EF Core), so they survive restarts and are visible to all instances. You'll need the `Microsoft.AspNetCore.DataProtection.EntityFrameworkCore` package and a context implementing `IDataProtectionKeyContext`.
  - `SetApplicationName("MyCompany.IdentityServer")` gives all instances the same application name so their keys aren't isolated from each other.

Without shared keys, cookies and other protected payloads issued by one instance can't be read by another, causing intermittent login failures behind a load balancer.
