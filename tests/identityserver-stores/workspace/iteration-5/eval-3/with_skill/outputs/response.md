Here is the store configuration that isolates the configuration and operational tables into separate schemas (`idscfg` and `idsop`), each with its own migration history table living in that same schema. Isolating schemas per store avoids table-name collisions and simplifies backup/restore strategies.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

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

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### How this works

- **`options.DefaultSchema`** on each store options object controls the schema that the store's tables are created in. Configuration tables (`Clients`, `ApiResources`, `IdentityResources`, …) go into `idscfg`; operational tables (`PersistedGrants`, `DeviceCodes`, `Keys`, …) go into `idsop`.
- **`sql.MigrationsHistoryTable("__...MigrationsHistory", "<schema>")`** places the EF `__EFMigrationsHistory` bookkeeping table into the matching schema, so each context's migration state is tracked independently within its own schema rather than defaulting to `dbo`.
- **`sql.MigrationsAssembly(migrationsAssembly)`** keeps EF pointed at the host project where the migrations are scaffolded — required because the migrations do not live in the Duende EF package.

### Scaffolding the migrations

When you run the migration commands, EF will place the history tables in the schemas configured above:

```shell
dotnet ef migrations add InitialConfig -c ConfigurationDbContext -o Data/Migrations/Config
dotnet ef migrations add InitialOperational -c PersistedGrantDbContext -o Data/Migrations/Operational

dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```
