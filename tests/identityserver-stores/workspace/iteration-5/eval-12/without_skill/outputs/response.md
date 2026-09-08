That error means EF Core can't resolve the migrations/provider setup for the context. In an IdentityServer host where the migrations live in your own project, the missing piece is `MigrationsAssembly` — EF defaults to looking for migrations in the Duende EF assembly and fails. Set it in both store registrations.

## Program.cs (fixed)

```csharp
var builder = WebApplication.CreateBuilder(args);

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

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## EF Core migration commands

Because there are two DbContexts, you must specify which one with `-c`.

Create the initial migrations:

```bash
dotnet ef migrations add InitialConfiguration \
  -c ConfigurationDbContext \
  -o Migrations/ConfigurationDb

dotnet ef migrations add InitialPersistedGrant \
  -c PersistedGrantDbContext \
  -o Migrations/PersistedGrantDb
```

Apply them to the database:

```bash
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

### Notes

- `MigrationsAssembly(migrationsAssembly)` in both `UseSqlServer` calls points EF at the host project (`typeof(Program).Assembly.GetName().Name`), which resolves the error.
- The `-c` / `--context` flag is required on every `dotnet ef` command here because the project contains both `ConfigurationDbContext` and `PersistedGrantDbContext`.
- Ensure the `Microsoft.EntityFrameworkCore.Design` package is referenced so the `dotnet ef` tooling works.
