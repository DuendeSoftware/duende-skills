# Fixing MigrationsAssembly and Creating Migrations

The error occurs because EF Core can't find migrations in the `Duende.IdentityServer.EntityFramework` assembly. You need to tell it to look in your host project.

## Fixed Program.cs

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

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
```

## Create Initial Migrations

```bash
# Configuration store migration
dotnet ef migrations add InitialConfigurationDb \
    -c ConfigurationDbContext \
    -o Data/Migrations/ConfigurationDb

# Operational store migration
dotnet ef migrations add InitialPersistedGrantDb \
    -c PersistedGrantDbContext \
    -o Data/Migrations/OperationalDb
```

## Apply Migrations

```bash
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

The `-c` flag specifies which DbContext to use. Without it, EF would find multiple contexts and fail.