**Cause:** `ConfigureDbContext` is either missing or doesn't call a provider (`UseSqlServer`) – and without `MigrationsAssembly`, EF searches `Duende.IdentityServer.EntityFramework.dll` for migrations and can't find yours in the host. Fix:

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    });
```

**Commands** (run in the host project folder):
```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext \
  --output-dir Data/Migrations/IdentityServer/ConfigurationDb

dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext \
  --output-dir Data/Migrations/IdentityServer/OperationalDb

dotnet ef database update --context ConfigurationDbContext
dotnet ef database update --context PersistedGrantDbContext
```
Duende doesn't auto-generate or apply migrations; you own them.
