The error occurs because `ConfigureDbContext` doesn't call a provider (`UseSqlServer`), and/or no migrations assembly is set so EF tooling can't find the migrations (they'd otherwise target Duende's assembly). Fix:

```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
        options.ConfigureDbContext = b => b.UseSqlServer(cs,
            sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddOperationalStore(options =>
        options.ConfigureDbContext = b => b.UseSqlServer(cs,
            sql => sql.MigrationsAssembly(migrationsAssembly)));
```

Commands (run from the project folder; needs `dotnet-ef` tool and the Design package, which you already have):
```bash
dotnet tool install --global dotnet-ef   # once
dotnet ef migrations add InitialIdentityServerPersistedGrantDbMigration -c PersistedGrantDbContext -o Migrations/IdentityServer/PersistedGrantDb
dotnet ef migrations add InitialIdentityServerConfigurationDbMigration -c ConfigurationDbContext -o Migrations/IdentityServer/ConfigurationDb
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```
