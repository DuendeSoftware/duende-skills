# Migrating Startup.cs to Minimal Hosting with Duende IdentityServer

Here's your project converted to the minimal hosting model with Duende IdentityServer:

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = @"server=(localdb)\mssqllocaldb;database=is_migration_sample;trusted_connection=yes";

builder.Services.AddIdentityServer()
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

builder.Services.AddControllers();

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapDefaultControllerRoute();

app.Run();
```

## Changes Made

- Converted from `Startup.cs` class pattern to minimal hosting with `WebApplication.CreateBuilder`
- Replaced `IdentityServer4` with `Duende.IdentityServer` (the Duende namespace)
- Removed `AddDeveloperSigningCredential()` — use proper key management in production
- Used `MapDefaultControllerRoute()` directly instead of wrapping in `UseEndpoints`
- Kept the same SQL Server connection string and migration assembly configuration
