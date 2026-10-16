# IdentityServerOptions + EF data protection

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Data protection: persisted, shared, explicit app name
builder.Services.AddDataProtection()
    .SetApplicationName("My.IdentityServer")
    .PersistKeysToDbContext<AppDbContext>();
    // plus .ProtectKeysWith...(certificate / Key Vault) to encrypt keys at rest

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

var app = builder.Build();
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

```csharp
public class AppDbContext : DbContext, IDataProtectionKeyContext
{
    public AppDbContext(DbContextOptions<AppDbContext> o) : base(o) { }
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = default!;
}
```
Package: `Microsoft.AspNetCore.DataProtection.EntityFrameworkCore`; add a migration.

## Notes
- **IssuerUri:** setting it is generally *not recommended*—it's inferred from the request URL. Set it only if IdentityServer is reached at a different address than the expected issuer (e.g. internal Kubernetes address). Since you asked for it, clients must use exactly this value. Behind a proxy, fix forwarded headers first.
- **License key:** from configuration (user-secrets, env var `IdentityServer__LicenseKey`, key vault) – never in source-controlled appsettings.json.
- **`EmitScopesAsSpaceDelimitedStringInJwt = true`** emits `scope` as a space-delimited string (RFC 9068) instead of an array (default false).
- **Data protection checklist:** persist keys to durable storage, share them across instances, set the same application name everywhere, ensure the storage is durable. Data protection keys (cookies, grants, signing-key protection) are separate from IdentityServer signing keys.
