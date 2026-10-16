```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    })
    .AddInMemoryClients(/* unchanged */)
    .AddInMemoryApiScopes(/* unchanged */)
    .AddInMemoryIdentityResources(/* unchanged */);

builder.Services.AddDbContext<DataProtectionKeyContext>(o => o.UseSqlServer(connectionString));
builder.Services.AddDataProtection()
    .SetApplicationName("My.IdentityServer")                  // identical on every instance
    .PersistKeysToDbContext<DataProtectionKeyContext>()       // Microsoft.AspNetCore.DataProtection.EntityFrameworkCore
    .ProtectKeysWithCertificate(dataProtectionCertificate);   // or ProtectKeysWithAzureKeyVault
```

```csharp
public class DataProtectionKeyContext(DbContextOptions<DataProtectionKeyContext> options)
    : DbContext(options), IDataProtectionKeyContext
{
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = null!;
}
```

Why:
- With the EF operational store, automatic signing keys live in the database, shared by all instances. Create/apply migrations for the operational store and the DP context.
- Signing keys are encrypted at rest (`DataProtectKeys = true`) using ASP.NET Core Data Protection. Default DP keys are machine-specific, so without shared persistence you'd get `CryptographicException: The key {ID} was not found in the key ring`. A fixed `SetApplicationName` avoids breakage after redeployment.
- `ProtectKeysWithCertificate`/Key Vault encrypts the DP ring at rest.
- `PropagationTime` and `InitializationDuration` (5 min) handle cache refresh and the first-start race between instances. Keep `DataProtectKeys` on.
- Don't mix up DP keys (symmetric, data-at-rest) and signing keys (asymmetric); both must be set up.
