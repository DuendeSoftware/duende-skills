To keep the configuration and operational tables in separate database schemas with their own migration history tables, set `DefaultSchema` on each store and pass the schema to `MigrationsHistoryTable`.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

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
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "idscfg");
            });
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "idsop");
            });
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Notes

- **`DefaultSchema`** determines the schema for all of that context's tables: `idscfg` for the configuration store, `idsop` for the operational store.
- **`MigrationsHistoryTable(name, schema)`** — the second argument is the schema, so each context's `__EFMigrationsHistory` table lives in its own schema. This keeps the two contexts' migration bookkeeping isolated and prevents them from sharing a single history table in `dbo`.
- **`MigrationsAssembly`** points EF at the host project where you scaffold the migrations.

When you generate migrations for each context, the schemas above are baked into the migration and applied on `database update`.
