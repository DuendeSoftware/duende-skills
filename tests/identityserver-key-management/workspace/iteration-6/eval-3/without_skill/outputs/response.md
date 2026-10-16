```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var cs = builder.Configuration.GetConnectionString("DefaultConnection");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(o => o.ConfigureDbContext = b =>
        b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddOperationalStore(o => o.ConfigureDbContext = b =>
        b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly)));
    // (keep or replace in-memory clients/scopes as needed)
// Signing keys from automatic key management are persisted in the operational store's SigningKeys table.

builder.Services.AddDbContext<DataProtectionKeyContext>(o => o.UseSqlServer(cs));
builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")      // same on all instances
    .PersistKeysToDbContext<DataProtectionKeyContext>();
```

```csharp
public class DataProtectionKeyContext : DbContext, IDataProtectionKeyContext
{
    public DataProtectionKeyContext(DbContextOptions<DataProtectionKeyContext> o) : base(o) { }
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = null!;
}
```

Package: `Microsoft.AspNetCore.DataProtection.EntityFrameworkCore`. Add migrations for the operational store and the DP context and apply them.

Notes: Duende encrypts signing keys at rest using ASP.NET Data Protection, so all instances must share DP keys and application name, otherwise you get "key not found in key ring" errors. Consider also protecting DP keys with `ProtectKeysWithAzureKeyVault`/certificate since keys in the DB would otherwise be unencrypted at rest.
