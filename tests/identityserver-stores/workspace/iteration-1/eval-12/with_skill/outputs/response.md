# Fix: Missing MigrationsAssembly and EF Core Migration Commands

## The Problem

The error `No database provider has been configured for this DbContext` typically occurs when `MigrationsAssembly` is not set on the EF store configuration. Without it, EF Core looks for migrations in the `Duende.IdentityServer.EntityFramework` assembly (where the DbContexts are defined) rather than your host project, and fails to find them.

## Fix Program.cs

The fix is to explicitly set `MigrationsAssembly` to your host project assembly in both store configurations:

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

The key addition is `sql.MigrationsAssembly(migrationsAssembly)` in both `AddConfigurationStore` and `AddOperationalStore`. This tells EF Core to look for migrations in your host project assembly instead of the Duende NuGet package assembly.

## EF Core Migration Commands

Now create the initial migrations for both contexts:

### Configuration Store Migration

```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext \
  --output-dir Data/Migrations/IdentityServer/ConfigurationDb
```

### Operational Store Migration

```shell
dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext \
  --output-dir Data/Migrations/IdentityServer/OperationalDb
```

### Apply Migrations to the Database

```shell
dotnet ef database update --context ConfigurationDbContext
dotnet ef database update --context PersistedGrantDbContext
```

**Notes:**
- The `--context` flag is required because the project has two DbContexts. Without it, EF Core won't know which one to target.
- The `--output-dir` flag organizes migrations into separate folders for clarity.
- Make sure `Microsoft.EntityFrameworkCore.Design` is installed in the project (it's already in your `.csproj`).
- After creating the migrations, review the generated code to verify it matches your expected schema.
