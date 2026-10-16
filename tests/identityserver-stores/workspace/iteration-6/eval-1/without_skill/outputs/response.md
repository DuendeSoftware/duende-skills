## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var cs = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(cs,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(cs,
            sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // seconds = 30 minutes
    });

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

`MigrationsAssembly` is set to the host project, so migrations are generated in this project rather than in the Duende assembly:

```bash
dotnet ef migrations add InitialConfig -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef migrations add InitialGrants -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

`TokenCleanupInterval` is in seconds (default 3600), so 1800 gives 30 minutes.
