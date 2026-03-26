# Fixing the Database Provider Error

Add MigrationsAssembly to both stores and create migrations.

## Fix

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var assembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(assembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(assembly));
    });
```

## Create Migrations

```bash
dotnet ef migrations add InitConfig -c ConfigurationDbContext -o Migrations/Configuration
dotnet ef migrations add InitOps -c PersistedGrantDbContext -o Migrations/Operational
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```