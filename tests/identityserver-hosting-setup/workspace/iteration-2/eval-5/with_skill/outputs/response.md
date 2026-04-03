# Configure IdentityServerOptions and Data Protection

## Updated Program.cs

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>()
    .SetApplicationName("My.IdentityServer");

builder.Services.AddIdentityServer(options =>
{
    // Set the issuer URI explicitly
    options.IssuerUri = "https://identity.mycompany.com";

    // Load license key from configuration (not hardcoded)
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];

    // Emit scopes as space-delimited string in JWTs
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Key Points

- `options.IssuerUri = "https://identity.mycompany.com"` — Sets the issuer name used in discovery and tokens.
- `options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"]` — Loads the license key from configuration rather than hardcoding it. Store in a secret manager, environment variable, or key vault.
- `options.EmitScopesAsSpaceDelimitedStringInJwt = true` — Changes the scope claim format from a JSON array to a space-delimited string per RFC 9068.
- `AddDataProtection().PersistKeysToDbContext<DataProtectionKeyContext>()` — Persists Data Protection keys to a database for multi-instance deployments.
- `SetApplicationName("My.IdentityServer")` — Prevents key isolation across instances by ensuring a consistent application name.
