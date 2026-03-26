# Migrated Program.cs — Duende IdentityServer with Minimal Hosting

Here is your `Startup.cs` and `Program.cs` converted to a single `Program.cs` using the minimal hosting model with Duende IdentityServer:

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";
var migrationsAssembly = typeof(Program).Assembly.FullName;

builder.Services.AddIdentityServer(options =>
    {
        // Configure license key from configuration
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

builder.Services.AddControllers();

var app = builder.Build();

// Apply pending migrations on startup (development only)
using (var scope = app.Services.CreateScope())
{
    var grants = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();
    grants.Database.Migrate();

    var config = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
    config.Database.Migrate();
}

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapDefaultControllerRoute();

app.Run();
```

## Key Changes from the Original

1. **Minimal hosting model**: Replaced the `Startup` class and `Program.Main` with `WebApplication.CreateBuilder` pattern. The `Startup.ConfigureServices` logic goes before `builder.Build()`, and the `Startup.Configure` pipeline goes after.

2. **Duende namespaces**: All `IdentityServer4.*` namespaces are replaced with `Duende.IdentityServer.*`:
   - `IdentityServer4.EntityFramework.DbContexts` → `Duende.IdentityServer.EntityFramework.DbContexts`
   - `IdentityServer4.EntityFramework.Mappers` → `Duende.IdentityServer.EntityFramework.Mappers`
   - `IdentityServer4.Models` → `Duende.IdentityServer.Models`

3. **`AddDeveloperSigningCredential()` removed**: Duende IdentityServer includes automatic key management (Business/Enterprise editions) that handles signing key creation and rotation without explicit configuration. No replacement call is needed.

4. **`AddConfigurationStore` and `AddOperationalStore` preserved**: The EF Core store configuration is identical — `UseSqlServer` with `MigrationsAssembly` pointing to the current assembly. The only change is the migration assembly reference uses `typeof(Program)` instead of `typeof(Startup)`.

5. **Middleware pipeline**: `UseIdentityServer()` is called after `UseRouting()` and before `UseAuthorization()`, matching the original order. `MapDefaultControllerRoute()` replaces `endpoints.MapDefaultControllerRoute()` inside `UseEndpoints`.

6. **License key configuration**: Added `options.LicenseKey` configuration — required for production use with Duende IdentityServer.
