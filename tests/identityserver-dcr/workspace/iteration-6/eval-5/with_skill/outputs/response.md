# Production client store for DCR: Entity Framework

In-memory stores lose dynamically registered clients on restart and don't work across nodes. DCR needs a persistent `IClientConfigurationStore`; use the EF implementation.

## Packages
```bash
dotnet add package Duende.IdentityServer.Configuration
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
dotnet add package Duende.IdentityServer.EntityFramework
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
```

## Program.cs
```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(o =>
        o.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddOperationalStore(o =>
        o.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */);

builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();   // EF-backed IClientConfigurationStore

app.MapDynamicClientRegistration().RequireAuthorization("dcr");
```
Replace `AddInMemoryClients(...)` (the in-memory `web.app` / `dcr.manager` clients) with database rows, seeding them at startup, otherwise IdentityServer's client lookup won't see the same data. Use `AddConfigurationStore` so that IdentityServer reads dynamically registered clients from the same tables.

## Migrations
```bash
dotnet ef migrations add Config -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
```

## Things to watch
- Dynamically registered clients get generated secrets; the store must keep them **hashed, not plaintext** (the EF store handles this through IdentityServer's secret hashing).
- If DCR is hosted in a separate app, it must write to the same database IdentityServer reads.
- Keep the connection string in secrets/Key Vault, and back up the configuration DB.
- Secure `/connect/dcr` with an authorization policy and restrict grant types/PKCE in a custom validator.
