# Migrated Program.cs — Duende IdentityServer with Minimal Hosting

Here's your `Startup.cs` + `Program.cs` converted to a single `Program.cs` using the minimal hosting model with Duende IdentityServer:

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
        // Configure license key from configuration/secrets — required for production
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
// Note: AddDeveloperSigningCredential() is removed.
// Duende IdentityServer (Business/Enterprise) includes automatic key management.
// No explicit call is needed — keys are created and rotated automatically.

builder.Services.AddControllersWithViews();

var app = builder.Build();

// Run database migrations on startup (same as before, adapted for minimal hosting)
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

## Key Changes

1. **Minimal hosting**: Uses `WebApplication.CreateBuilder` instead of the `Startup` class pattern. All service registration and middleware configuration is in a single `Program.cs`.

2. **Duende namespaces**: All `using IdentityServer4.*` statements are replaced with `using Duende.IdentityServer.*`.

3. **`AddDeveloperSigningCredential()` removed**: Duende IdentityServer includes built-in automatic key management (Business/Enterprise editions). No explicit signing credential call is needed.

4. **`AddConfigurationStore` and `AddOperationalStore`**: Kept with the same `UseSqlServer` and `MigrationsAssembly` configuration — just now under Duende's `builder.Services.AddIdentityServer()`.

5. **Middleware pipeline**: `UseIdentityServer()` is placed after `UseRouting()` and before `UseAuthorization()`, same ordering as before. `UseEndpoints` with `MapDefaultControllerRoute` is replaced by the top-level `app.MapDefaultControllerRoute()`.
