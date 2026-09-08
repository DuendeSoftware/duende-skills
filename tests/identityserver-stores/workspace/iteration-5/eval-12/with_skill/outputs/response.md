The fix is to tell EF where the migrations live by setting `MigrationsAssembly` to the current (host) project in **both** store registrations. When migrations are scaffolded into the host project but `MigrationsAssembly` isn't set, EF looks inside `Duende.IdentityServer.EntityFramework.dll` instead, and both design-time commands and runtime startup fail.

## Program.cs (fixed)

```csharp
var builder = WebApplication.CreateBuilder(args);

// Point EF at THIS assembly, where the migrations are generated.
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly)); // <-- was missing
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly)); // <-- was missing
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Create the initial migrations

Scaffold one migration per `DbContext` into the host project, giving each its own output folder:

```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  -c ConfigurationDbContext \
  -o Data/Migrations/IdentityServer/ConfigurationDb

dotnet ef migrations add InitialIdentityServerPersistedGrantDb \
  -c PersistedGrantDbContext \
  -o Data/Migrations/IdentityServer/OperationalDb
```

## Apply the migrations

Run `database update` once per context:

```shell
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

### Why the `-c` flag matters

Because your project has **two** `DbContext` types (`ConfigurationDbContext` and `PersistedGrantDbContext`), every `dotnet ef` command is ambiguous unless you disambiguate with `-c` / `--context`. Omitting it produces a "More than one DbContext was found" error. If you haven't already, also add the design-time tooling package:

```shell
dotnet add package Microsoft.EntityFrameworkCore.Design
```
