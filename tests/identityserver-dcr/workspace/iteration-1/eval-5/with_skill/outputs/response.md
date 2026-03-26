# Entity Framework-Backed Client Store for DCR

## Add the NuGet Package

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

## Configure the Store

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"));
    });

// Add DCR with the EF-backed client configuration store
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

## Why Not In-Memory?

In-memory stores are **not suitable for production** with DCR:

- Dynamically registered clients are lost on application restart
- Multiple IdentityServer instances don't share the same client list
- No audit trail for client registrations
- No ability to manage registered clients after the fact

## How It Works

`AddClientConfigurationStore()` registers the EF Core implementation of `IClientConfigurationStore`. This store persists dynamically registered clients to the same database used by the IdentityServer configuration store.

When a client registers via `/connect/dcr`, the store:
1. Persists the client definition (with hashed secrets) to the database
2. Returns the registration response with the generated client_id and secret
3. The client is immediately available for authentication
