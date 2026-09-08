# EF-backed client configuration store for DCR (production)

For production, dynamically registered clients must be persisted in a real database — **never** in-memory. In-memory stores lose every dynamically registered client on restart and don't work across multiple instances. Duende ships an Entity Framework implementation of `IClientConfigurationStore` you should use instead of writing your own.

## 1. Add the EF configuration package

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

`IdentityServer.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration" Version="8.0.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration.EntityFramework" Version="8.0.0" />
  <PackageReference Include="Serilog.AspNetCore" Version="8.0.3" />
</ItemGroup>
```

## 2. Register the EF client configuration store

Call `AddClientConfigurationStore()` on the configuration builder returned by `AddIdentityServerConfiguration()`:

```csharp
var connectionString = builder.Configuration.GetConnectionString("ConfigurationDb");

builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();

// Register the EF DbContext used by the configuration store
builder.Services.AddDbContext<ConfigurationDbContext>(options =>
    options.UseSqlServer(connectionString));
```

The `AddClientConfigurationStore()` call wires the EF-backed `IClientConfigurationStore` into DI so DCR writes newly registered clients to the database that IdentityServer reads from.

## 3. Apply the schema

Run EF Core migrations so the configuration tables exist before going live:

```bash
dotnet ef migrations add InitialConfiguration -c ConfigurationDbContext
dotnet ef database update -c ConfigurationDbContext
```

## Why this matters

- **Do not use in-memory stores in production.** Dynamically registered clients written to an in-memory store are lost on restart and are not shared across instances/load-balanced nodes — a persistent (database-backed) store is required.
- Prefer the shipped EF store over hand-rolling `IClientConfigurationStore`. Only implement the interface yourself when you need a backing store the EF package doesn't cover (e.g. a non-relational database).
- Ensure the configuration store writes to the **same database** IdentityServer reads its clients from, so registered clients are usable immediately.

That's the whole change: add `Duende.IdentityServer.Configuration.EntityFramework`, call `AddClientConfigurationStore()`, point the DbContext at your database, and migrate.
