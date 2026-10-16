## Program.cs (minimal hosting)

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";
var migrationsAssembly = typeof(Program).Assembly.FullName;

builder.Services.AddControllersWithViews();

builder.Services.AddIdentityServer(options =>
    {
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

Notes:
- Delete `Startup.cs`; Program.cs absorbs it (the old Program only built the host and never ran it).
- I removed `AddDeveloperSigningCredential()`: Duende has automatic key management enabled by default. If you must keep old keys, use `AddSigningCredential` / `AddValidationKey`.
- Packages: `Duende.IdentityServer.EntityFramework`, target net8.0.
- Same connection string and migrations assembly retained. Remember to add new EF migrations.
