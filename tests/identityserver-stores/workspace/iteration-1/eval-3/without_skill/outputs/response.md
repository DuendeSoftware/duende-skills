# Separate Schemas for EF Stores

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "idscfg";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name);
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "idscfg");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name);
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "idsop");
            });
    });
```