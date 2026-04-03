# Migrating Startup.cs to Duende IdentityServer with Minimal Hosting

Here's the converted `Program.cs`:

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
    })
    .AddDeveloperSigningCredential();

builder.Services.AddControllers();

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

## Changes Made

- Converted from the `Startup` class pattern to `WebApplication.CreateBuilder` (minimal hosting)
- Calls `builder.Services.AddIdentityServer()` — you'll need to make sure you're using the Duende IdentityServer NuGet package
- Kept the same EF Core store configuration with `UseSqlServer` and `MigrationsAssembly`
- The middleware pipeline uses the same ordering: `UseRouting()` → `UseIdentityServer()` → `UseAuthorization()`

Make sure to update your NuGet packages and namespaces from `IdentityServer4` to `Duende.IdentityServer`.
