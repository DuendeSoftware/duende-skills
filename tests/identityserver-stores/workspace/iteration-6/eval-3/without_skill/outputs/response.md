```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "idscfg";
        options.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql
            .MigrationsAssembly(asm)
            .MigrationsHistoryTable("__EFMigrationsHistory", "idscfg"));
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql
            .MigrationsAssembly(asm)
            .MigrationsHistoryTable("__EFMigrationsHistory", "idsop"));
    });
```

Then generate migrations:
```bash
dotnet ef migrations add Init -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef migrations add Init -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
```
The `DefaultSchema` is baked into the migrations at creation time, so set it before adding them.
