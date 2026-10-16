## Program.cs (minimal hosting, Duende IdentityServer)

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";
var migrationsAssembly = typeof(Program).Assembly.FullName;

builder.Services.AddControllersWithViews();

builder.Services.AddIdentityServer(options =>
    {
        // Store in secrets / env var, never in source control
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

using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>().Database.Migrate();
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapDefaultControllerRoute();

app.Run();
```

Delete `Startup.cs` and the old Program.cs (the old version built the host and ran migrations but never called `Run()`; this one does).

### Notes
- **Hosting**: `Startup.ConfigureServices` → `builder.Services`; `Configure` → pipeline after `Build()`; `UseEndpoints(e => e.MapDefaultControllerRoute())` → `app.MapDefaultControllerRoute()`.
- **`AddDeveloperSigningCredential()` removed**: Duende has automatic key management (Business/Enterprise). On Community edition use `.AddSigningCredential(new X509Certificate2(...))`. If tokens signed with the old key are still in use, keep the old key available during transition.
- **License key** added; without it IdentityServer runs in community/trial mode and logs a warning.
- **csproj**: `net8.0` (v7) or `net10.0` (v8), `Duende.IdentityServer.EntityFramework`, matching EF Core packages.
- **Namespaces**: `IdentityServer4.EntityFramework.*` → `Duende.IdentityServer.EntityFramework.*`.
- **Also**: create EF migrations for both contexts (new tables like `Keys`, `ServerSideSessions`), set an explicit issuer if it was inferred, and configure Data Protection with `SetApplicationName` and persistent keys.
