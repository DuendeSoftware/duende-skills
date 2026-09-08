# Persisting DCR clients with Entity Framework

In-memory client stores are fine for demos, but in production they lose all dynamically registered clients on restart and can't be shared across scaled-out instances. You need a database-backed store. Duende provides Entity Framework stores that persist clients (and other configuration) to SQL.

## 1. Add the EF integration package

```bash
dotnet add package Duende.IdentityServer.EntityFramework
```

## 2. Configure the configuration store

Replace the in-memory registrations (`AddInMemoryClients`, etc.) with the EF-backed configuration store so clients live in the database:

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServerDb");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    });

builder.Services.AddIdentityServerConfiguration();
```

The `ConfigurationStore` holds clients, identity resources, and API scopes; the `OperationalStore` holds grants and tokens. Dynamically registered clients written through the DCR endpoint are persisted into the configuration store's `Clients` tables.

## 3. Create and apply migrations

```bash
dotnet ef migrations add InitialIdentityServerConfiguration \
    -c ConfigurationDbContext -o Migrations/Configuration

dotnet ef migrations add InitialIdentityServerOperational \
    -c PersistedGrantDbContext -o Migrations/Operational

dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

## Production notes

- **Don't use in-memory stores in production** — dynamically registered clients would vanish on restart and wouldn't be visible to other nodes behind a load balancer.
- Make sure the DCR endpoint and IdentityServer read/write the **same** configuration database, so newly registered clients are immediately usable for token requests.
- Secure the database connection string (user secrets / key vault), and consider hashing any stored client secrets.

With the EF configuration store in place, clients created via `/connect/dcr` are durably stored and survive restarts.
