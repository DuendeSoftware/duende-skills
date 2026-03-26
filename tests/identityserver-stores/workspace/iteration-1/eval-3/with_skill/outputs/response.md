# Configuring Separate Database Schemas

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

Each schema gets its own migration history table so EF Core tracks migrations independently.