```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "idscfg";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__ConfigMigrationsHistory", "idscfg");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OperationalMigrationsHistory", "idsop");
            });
    });
```

Create the migrations after setting the schemas:
```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext --output-dir Data/Migrations/IdentityServer/ConfigurationDb
dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext --output-dir Data/Migrations/IdentityServer/OperationalDb
```
`MigrationsAssembly` ensures they land in the host project; each store's history table sits in its own schema.
