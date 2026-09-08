# Migrating `Startup.cs` to Duende IdentityServer with minimal hosting

Below is your `Startup.cs` + `Program.cs` converted to the minimal hosting model on Duende IdentityServer, keeping the same connection string, EF Core SQL Server stores, and migrations-assembly configuration.

## New `Program.cs`

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;
using System.Reflection;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer(options =>
    {
        // Required for production. Load from configuration / secret manager, not source control.
        options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    })
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    });

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();   // after UseRouting, before UseAuthorization
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## What changed and why

**1. Startup class → `WebApplication.CreateBuilder`.** The generic-host `Startup` + `Program` pair is replaced by a single top-level `Program.cs`. `ConfigureServices` code moves before `builder.Build()`; `Configure` middleware moves after it.

**2. `AddIdentityServer()` now resolves to the Duende namespace.** After swapping `IdentityServer4.*` packages for `Duende.IdentityServer.*`, `builder.Services.AddIdentityServer()` binds to Duende's registration. The EF Core DbContext types come from `Duende.IdentityServer.EntityFramework.DbContexts`.

**3. `AddConfigurationStore` / `AddOperationalStore` are unchanged in shape.** The same `UseSqlServer(connectionString, sql => sql.MigrationsAssembly(...))` lambdas are preserved — only the namespace behind them changes. I switched `typeof(Startup).Assembly.FullName` to the current assembly name via `typeof(Program)`; either works as long as it resolves to the assembly that holds your migrations.

**4. Middleware order preserved.** `UseIdentityServer()` sits after `UseRouting()` and before `UseAuthorization()`, exactly as in the original pipeline. In minimal hosting, `UseEndpoints(...)` collapses into the top-level `app.MapDefaultControllerRoute()`.

**5. `AddDeveloperSigningCredential()` removed.** Duende IdentityServer includes **automatic key management** (Business/Enterprise), so no explicit signing-credential call is needed — keys are created and rotated for you. For Community/static scenarios use `.AddSigningCredential(...)` with an X509 certificate instead. Do **not** carry `AddDeveloperSigningCredential()` into production.

## Keeping the migration bootstrapper

Your old `Program.Main` also ran `Database.Migrate()` on both DbContexts at startup. If you want to keep that behavior, run it after `Build()`:

```csharp
using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>().Database.Migrate();
}
```
