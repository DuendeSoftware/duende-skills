# Converting `Startup.cs` to Duende IdentityServer with minimal hosting

Here is your configuration ported to the .NET minimal hosting model on Duende IdentityServer, preserving the SQL Server connection string and the migrations-assembly setup.

## `Program.cs`

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";
var migrationsAssembly = typeof(Program).Assembly.FullName;

builder.Services.AddIdentityServer()
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
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Notes on the conversion

- **No more `Startup` class.** With minimal hosting everything lives in `Program.cs`. The service registrations from `ConfigureServices` go before `builder.Build()`, and the middleware from `Configure` goes after it.
- **`AddIdentityServer()` now comes from Duende.** Once you replace the `IdentityServer4` NuGet packages with `Duende.IdentityServer` / `Duende.IdentityServer.EntityFramework`, the same `AddIdentityServer()`, `AddConfigurationStore()`, and `AddOperationalStore()` extension methods are available under the Duende namespaces. The DbContexts come from `Duende.IdentityServer.EntityFramework.DbContexts`.
- **Same store configuration.** The `UseSqlServer` calls with `MigrationsAssembly` are kept identical, so your existing migrations continue to resolve.
- **Middleware order is unchanged.** `UseIdentityServer()` still runs after `UseRouting()` and before `UseAuthorization()`. The old `UseEndpoints(e => e.MapDefaultControllerRoute())` becomes the top-level `app.MapDefaultControllerRoute()`.
- **Dropped `AddDeveloperSigningCredential()`.** That call was only ever meant for local development. Duende manages signing keys automatically, so you can remove it; for a fixed production key use `.AddSigningCredential()` with a certificate.

If you still want the startup database migration that your original `Program.Main` performed, do it after building the app:

```csharp
using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>().Database.Migrate();
}
```
