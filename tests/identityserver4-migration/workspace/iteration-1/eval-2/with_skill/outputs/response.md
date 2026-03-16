# Migrating Startup.cs to Duende IdentityServer Minimal Hosting

Here's the converted `Program.cs` using Duende IdentityServer with minimal hosting:

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";

builder.Services.AddIdentityServer(options =>
    {
        options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    })
    // Remove AddDeveloperSigningCredential — Duende has built-in automatic key management
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(typeof(Program).Assembly.FullName));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(typeof(Program).Assembly.FullName));
    });

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapDefaultControllerRoute();

app.Run();
```

### Key Changes

1. **`WebApplication.CreateBuilder`** replaces the `Startup.cs` + `Program.cs` pattern (minimal hosting).
2. **Duende namespace** — `builder.Services.AddIdentityServer()` uses Duende.IdentityServer (update `using` directives).
3. **`AddConfigurationStore` and `AddOperationalStore`** remain with `UseSqlServer` and `MigrationsAssembly`.
4. **`UseIdentityServer()`** is placed after `UseRouting()` and before `UseAuthorization()`.
5. **`AddDeveloperSigningCredential()` is removed** — Duende IdentityServer includes automatic key management (Business/Enterprise editions). No explicit signing credential call is needed.
6. **`MapDefaultControllerRoute()`** replaces the `UseEndpoints` pattern.
