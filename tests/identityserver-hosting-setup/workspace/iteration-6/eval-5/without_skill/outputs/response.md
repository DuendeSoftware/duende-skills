# IdentityServer options + EF data protection

```csharp
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToDbContext<AppDbContext>();

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

var app = builder.Build();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

`AppDbContext` must implement `IDataProtectionKeyContext`:
```csharp
public class AppDbContext : DbContext, IDataProtectionKeyContext
{
    public AppDbContext(DbContextOptions<AppDbContext> o) : base(o) { }
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = default!;
}
```
Needs package `Microsoft.AspNetCore.DataProtection.EntityFrameworkCore`; add a migration. Same application name on all instances. Keep the license key in user-secrets/env/key vault, e.g. `IdentityServer__LicenseKey`. Consider also protecting keys at rest (`ProtectKeysWith...`).
