# Fixing 'No Database Provider' Error and Creating Migrations

## The Problem

The error "No database provider has been configured for this DbContext" typically occurs when `MigrationsAssembly` is not set. Without it, EF Core looks for migrations in the `Duende.IdentityServer.EntityFramework` assembly instead of your host project, and fails.

## Fixed Program.cs

```csharp
using Duende.IdentityServer.Models;

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
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## EF Core Migration Commands

### Create Initial Migrations

```bash
# Configuration store migration
dotnet ef migrations add InitialConfigurationDb \
  -c ConfigurationDbContext \
  -o Data/Migrations/ConfigurationDb

# Operational store (persisted grants) migration
dotnet ef migrations add InitialPersistedGrantDb \
  -c PersistedGrantDbContext \
  -o Data/Migrations/PersistedGrantDb
```

### Apply Migrations to Database

```bash
# Apply configuration store migration
dotnet ef database update -c ConfigurationDbContext

# Apply operational store migration
dotnet ef database update -c PersistedGrantDbContext
```

## Key Points

- **`MigrationsAssembly`** must be set in both stores to point to your host project assembly
- Without this setting, EF looks for migrations in `Duende.IdentityServer.EntityFramework.dll`
- Use `-c` flag to specify the DbContext when creating migrations (since there are two)
- Use `-o` flag to organize migrations into separate folders
- Run `dotnet ef database update` for each context to apply the migrations
