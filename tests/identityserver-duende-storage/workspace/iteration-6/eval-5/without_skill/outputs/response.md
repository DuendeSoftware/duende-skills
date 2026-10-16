I can't confirm the "Duende Storage" API, so here is the standard EF Core approach, which supports exactly this split: two DbContexts, two connection strings.

```csharp
var cfg = builder.Configuration.GetConnectionString("Config");
var ops = builder.Configuration.GetConnectionString("Operational");
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(o => o.ConfigureDbContext = b =>
        b.UseSqlServer(cfg, s => s.MigrationsAssembly(asm)))
    .AddOperationalStore(o =>
    {
        o.ConfigureDbContext = b => b.UseSqlServer(ops, s => s.MigrationsAssembly(asm));
        o.EnableTokenCleanup = true;
    });
```
**Migrations** (separate output folders):
```
dotnet ef migrations add Init -c ConfigurationDbContext -o Migrations/Configuration
dotnet ef migrations add Init -c PersistedGrantDbContext -o Migrations/Operational
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```
Or call `Database.Migrate()` on each context at startup (fine for dev; in production run migrations from your pipeline). Signing keys are in the operational store only when automatic key management is enabled with the EF operational store.
