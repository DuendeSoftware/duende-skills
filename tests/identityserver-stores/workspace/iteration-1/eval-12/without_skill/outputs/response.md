# Fixing the Missing Database Provider Error

The error `No database provider has been configured for this DbContext` means EF Core doesn't know which database to connect to. This happens when `MigrationsAssembly` is not specified — EF Core defaults to looking for migrations in the assembly where the DbContext is defined (the Duende NuGet package), which doesn't have your migrations.

## Fixed Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## EF Core Migration Commands

Create the initial migrations for both contexts:

```shell
# Configuration store
dotnet ef migrations add InitialConfigDb --context ConfigurationDbContext --output-dir Migrations/ConfigurationDb

# Operational store
dotnet ef migrations add InitialOpsDb --context PersistedGrantDbContext --output-dir Migrations/OperationalDb
```

Then apply them:

```shell
dotnet ef database update --context ConfigurationDbContext
dotnet ef database update --context PersistedGrantDbContext
```

The `--context` flag tells EF Core which DbContext to target, since the project has multiple contexts registered.
