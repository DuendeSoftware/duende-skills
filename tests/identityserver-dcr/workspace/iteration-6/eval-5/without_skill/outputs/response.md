# EF-backed client store for DCR

```bash
dotnet add package Duende.IdentityServer.EntityFramework
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
```

```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var asm = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(o =>
        o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm)))
    .AddOperationalStore(o =>
        o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm)));

builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();   // EF-based IClientConfigurationStore
```
Replace `AddInMemoryClients` with the DB (seed `web.app` and `dcr.manager`), or keep in-memory scopes/resources and use EF only for clients.

Migrations:
```bash
dotnet ef migrations add Config -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
```
IdentityServer's `IClientStore` and the DCR store read the same `Clients` tables, so registered clients work immediately. Keep the connection string in a secret store.
