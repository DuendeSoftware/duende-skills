---
name: identityserver-data-storage
description: "Guide for configuring Duende IdentityServer data persistence using Entity Framework Core, including configuration stores, operational stores, caching, token cleanup, custom stores, and database migrations."
invocable: false
---

# IdentityServer Data Storage with Entity Framework Core

## When to Use This Skill

- Setting up the EF Core configuration store for clients, resources, and identity providers
- Setting up the EF Core operational store for grants, tokens, sessions, and signing keys
- Enabling caching for configuration data to reduce database load
- Configuring token cleanup for expired and consumed grants
- Implementing custom store interfaces for non-EF persistence
- Managing database migrations for IdentityServer schema changes
- Understanding the separation between configuration data and operational data
- Protecting grant data at rest using ASP.NET Core Data Protection

## Data Architecture Overview

Duende IdentityServer is backed by two kinds of data, accessed through store interfaces registered in the ASP.NET Core service provider:

```
┌─────────────────────────────────────────────────────────────┐
│                    IdentityServer Runtime                    │
├──────────────────────────┬──────────────────────────────────┤
│    Configuration Data    │       Operational Data           │
│                          │                                  │
│  • Clients               │  • Authorization codes           │
│  • API Resources         │  • Reference tokens              │
│  • API Scopes            │  • Refresh tokens                │
│  • Identity Resources    │  • User consent                  │
│  • Identity Providers    │  • Device codes                  │
│  • CORS policies         │  • Signing keys                  │
│                          │  • Server-side sessions           │
├──────────────────────────┼──────────────────────────────────┤
│  ConfigurationDbContext   │  PersistedGrantDbContext          │
│  (IClientStore,          │  (IPersistedGrantStore,           │
│   IResourceStore,        │   IDeviceFlowStore,               │
│   IIdentityProviderStore,│   IServerSideSessionStore,        │
│   ICorsPolicyService)    │   ISigningKeyStore)               │
└──────────────────────────┴──────────────────────────────────┘
```

## NuGet Package

```bash
dotnet add package Duende.IdentityServer.EntityFramework
```

This package provides both the configuration store and operational store implementations.

## Configuration Store

The configuration store persists client definitions, resources, identity providers, and CORS policies.

### Setting Up the Configuration Store

```csharp
// Program.cs
const string connectionString =
    @"Data Source=(LocalDb)\MSSQLLocalDB;database=YourIdentityServerDatabase;trusted_connection=yes;";
var migrationsAssembly = typeof(Program).GetTypeInfo().Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = builder =>
            builder.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    });
```

### ConfigurationStoreOptions

| Option               | Type                              | Description                                                                                |
| -------------------- | --------------------------------- | ------------------------------------------------------------------------------------------ |
| `ConfigureDbContext` | `Action<DbContextOptionsBuilder>` | Callback to configure the `ConfigurationDbContext`. Any EF-supported database can be used. |
| `DefaultSchema`      | `string`                          | Sets the default database schema for all configuration tables                              |

### Custom Schema

```csharp
options.DefaultSchema = "myConfigurationSchema";
```

### Custom Migration History Table

```csharp
options.ConfigureDbContext = b =>
    b.UseSqlServer(connectionString,
        sql => sql.MigrationsAssembly(migrationsAssembly)
            .MigrationsHistoryTable("MyConfigurationMigrationTable", "myConfigurationSchema"));
```

### Store Interfaces Implemented

| Interface                | Purpose                                                          |
| ------------------------ | ---------------------------------------------------------------- |
| `IClientStore`           | Retrieves `Client` data                                          |
| `IResourceStore`         | Retrieves `IdentityResource`, `ApiResource`, and `ApiScope` data |
| `IIdentityProviderStore` | Retrieves `IdentityProvider` data for dynamic providers          |
| `ICorsPolicyService`     | Provides CORS policy decisions based on client configuration     |

## Caching Configuration Data

Configuration data is loaded frequently during request processing. Caching reduces database load significantly in production.

### Enabling Cache for EF Stores

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddConfigurationStore(options => { /* ... */ })
    .AddConfigurationStoreCache();
```

### Enabling Cache for Custom Stores

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddClientStore<YourCustomClientStore>()
    .AddResourceStore<YourCustomResourceStore>()
    .AddInMemoryCaching()
    .AddClientStoreCache<YourCustomClientStore>()
    .AddCorsPolicyCache<YourCustomCorsPolicyService>()
    .AddResourceStoreCache<YourCustomResourceStore>()
    .AddIdentityProviderStoreCache<YourCustomAddIdentityProviderStore>();
```

### Configuring Cache Duration

```csharp
// Program.cs
builder.Services.AddIdentityServer(options => {
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
    options.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(5);
});
```

### Cache Architecture

The caching implementation uses `ICache<T>`, which relies on `IMemoryCache` from .NET by default. You can replace either layer:

- Replace `ICache<T>` for custom caching behavior per configuration type
- Replace `IMemoryCache` for a different in-memory caching implementation

## Operational Store

The operational store persists dynamic runtime state: grants (authorization codes, tokens, consent), signing keys, and server-side sessions.

### Setting Up the Operational Store

```csharp
// Program.cs
const string connectionString =
    @"Data Source=(LocalDb)\MSSQLLocalDB;database=YourIdentityServerDatabase;trusted_connection=yes;";
var migrationsAssembly = typeof(Program).GetTypeInfo().Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = builder =>
            builder.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));

        // Enable automatic cleanup of expired tokens
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 3600; // seconds (default: 1 hour)
    });
```

### OperationalStoreOptions

| Option                      | Type                              | Default | Description                                                                  |
| --------------------------- | --------------------------------- | ------- | ---------------------------------------------------------------------------- |
| `ConfigureDbContext`        | `Action<DbContextOptionsBuilder>` | —       | Configure the `PersistedGrantDbContext`                                      |
| `DefaultSchema`             | `string`                          | —       | Default database schema for operational tables                               |
| `EnableTokenCleanup`        | `bool`                            | `false` | Enable automatic cleanup of expired grants and pushed authorization requests |
| `RemoveConsumedTokens`      | `bool`                            | `false` | Also remove consumed grants during cleanup (added >= 5.1)                    |
| `TokenCleanupInterval`      | `int`                             | `3600`  | Cleanup interval in seconds                                                  |
| `ConsumedTokenCleanupDelay` | `int`                             | `0`     | Seconds to wait after consumption before cleaning up (added >= 6.3)          |
| `FuzzTokenCleanupStart`     | `bool`                            | `true`  | Randomize first cleanup run to avoid multi-instance conflicts (added >= 7.0) |

### Store Interfaces Implemented

| Interface                 | Purpose                                                               |
| ------------------------- | --------------------------------------------------------------------- |
| `IPersistedGrantStore`    | Stores authorization codes, reference tokens, refresh tokens, consent |
| `IDeviceFlowStore`        | Stores device authorization grants                                    |
| `IServerSideSessionStore` | Stores server-side session data                                       |
| `ISigningKeyStore`        | Stores dynamically created signing keys                               |

## Token Cleanup

The token cleanup feature runs as a background job that removes expired persisted grants and pushed authorization requests.

### Configuration

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = /* ... */;

        options.EnableTokenCleanup = true;           // disabled by default
        options.TokenCleanupInterval = 3600;          // 1 hour (default)
        options.RemoveConsumedTokens = true;          // also remove consumed tokens
        options.ConsumedTokenCleanupDelay = 300;      // wait 5 minutes after consumption
        options.FuzzTokenCleanupStart = true;         // randomize first run (default)
    });
```

### Important Behavior

- Token cleanup only removes grants that are beyond their `Expiration`.
- Consumed grants (with `ConsumedTime` set) are only removed if `RemoveConsumedTokens = true`.
- `ConsumedTokenCleanupDelay` controls how long consumed tokens are kept after consumption — useful when you have a custom `IRefreshTokenService` that accepts recently consumed tokens.
- `FuzzTokenCleanupStart` (v7.0+) randomizes the first cleanup run to reduce update conflicts when multiple instances run the cleanup simultaneously.

## Grant Data Protection

The `Data` property of persisted grants contains the authoritative copy of grant values. This data is **protected at rest** using ASP.NET Core's Data Protection API.

### Key Points

- Except for `ConsumedTime`, all other properties on the persisted grant model are read-only indices.
- Changing index properties (e.g., `Created`, `Expiration`) directly in the database will not affect behavior — the `Data` property is the source of truth.
- Data Protection keys must be properly configured and shared across all instances.

## Grants: Expiration and Consumption

| State                                                 | Meaning                           |
| ----------------------------------------------------- | --------------------------------- |
| Record exists, no `ConsumedTime`, within `Expiration` | Grant is valid                    |
| `ConsumedTime` is set                                 | Grant has been used (soft delete) |
| Past `Expiration`                                     | Grant is expired                  |
| Record deleted                                        | Grant is revoked                  |

Setting `ConsumedTime` or removing the record effectively revokes the grant. One-time-use grants (like authorization codes and optionally refresh tokens) use the consumption mechanism instead of immediate deletion to enable replay detection and grace periods.

## Persisted Grant Service

For higher-level access to grants, use `IPersistedGrantService`:

```csharp
// Inject IPersistedGrantService
// Query all grants for a user
var grants = await _persistedGrantService.GetAllGrantsAsync(subjectId);

// Revoke all grants for a user/client
await _persistedGrantService.RemoveAllGrantsAsync(subjectId, clientId);
```

This service abstracts and aggregates different grant types into a unified API.

## Signing Key Store

Automatic key management requires a store for dynamically created signing keys.

### Default: File System

By default, keys are stored on the file system in the `~/keys` directory.

### EF Core Store

Included automatically when using the operational store.

### Custom Store

```csharp
builder.Services.AddIdentityServer()
    .AddSigningKeyStore<YourCustomStore>();
```

### Key Lifecycle

1. `LoadKeysAsync` — loads all keys from the store (cached based on configuration)
2. `StoreKeyAsync` — persists newly created keys
3. `DeleteKeyAsync` — purges retired keys

The `SerializedKey` model has a `DataProtected` property indicating whether the key `Data` is encrypted. The `Id` is the unique identifier; `Data` is the authoritative payload.

## Custom Store Implementations

### Registering Custom Configuration Stores

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddClientStore<YourCustomClientStore>()
    .AddCorsPolicyService<YourCustomCorsPolicyService>()
    .AddResourceStore<YourCustomResourceStore>()
    .AddIdentityProviderStore<YourCustomIdentityProviderStore>();
```

### Registering Custom Operational Stores

```csharp
// Program.cs
builder.Services.AddIdentityServer();

builder.Services.AddTransient<IPersistedGrantStore, YourCustomPersistedGrantStore>();
builder.Services.AddTransient<IDeviceFlowStore, YourCustomDeviceFlowStore>();
```

### Registering Custom Server-Side Session Store

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<YourCustomStore>();
```

## In-Memory Stores

For development and testing, use in-memory stores:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(clients)
    .AddInMemoryApiScopes(apiScopes)
    .AddInMemoryApiResources(apiResources)
    .AddInMemoryIdentityResources(identityResources)
    .AddInMemoryIdentityProviders(identityProviders);
```

In-memory stores are created once at startup and do not dynamically reload from a database. They are appropriate for prototyping, development, testing, and production scenarios where configuration rarely changes.

## Database Migrations

### Migration Strategy

Duende does not provide built-in migration support. You are responsible for managing:

- Database creation
- Schema changes across IdentityServer versions
- Data migration

### Using EF Core Migrations

Refer to the EF quickstart for migration setup. Example migration commands:

```bash
# Create a migration for the configuration store
dotnet ef migrations add InitialConfiguration \
    -c ConfigurationDbContext \
    -o Data/Migrations/Configuration

# Create a migration for the operational store
dotnet ef migrations add InitialOperational \
    -c PersistedGrantDbContext \
    -o Data/Migrations/Operational

# Apply migrations
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

### Schema Changes Between Versions

Database schema may change between IdentityServer versions. A sample migration app is published for SQL Server at the Duende Software GitHub repository.

## Complete Setup Example

```csharp
// Program.cs
const string connectionString = "...";
var migrationsAssembly = typeof(Program).GetTypeInfo().Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    // Configuration store
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    // Cache configuration data in production
    .AddConfigurationStoreCache()
    // Operational store
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 3600;
        options.RemoveConsumedTokens = true;
    })
    // Server-side sessions (uses the operational store)
    .AddServerSideSessions();
```

## Decision Matrix: Store Implementation

| Scenario                                      | Recommendation                                     |
| --------------------------------------------- | -------------------------------------------------- |
| Prototyping / local development               | In-memory stores                                   |
| Small deployment, rare config changes         | In-memory stores loaded from config files          |
| Production with relational database           | EF Core stores with `AddConfigurationStoreCache()` |
| High-traffic production                       | EF Core stores + caching + tuned cleanup intervals |
| Non-relational database (Redis, Cosmos, etc.) | Custom store implementations                       |
| SaaS with dynamic configuration               | EF Core or custom stores with API for management   |

## Common Anti-Patterns

- ❌ Using in-memory stores in production for operational data — grants are lost on restart
- ✅ Use EF Core or a custom durable store for operational data

- ❌ Forgetting to enable token cleanup — grants accumulate indefinitely
- ✅ Always set `EnableTokenCleanup = true` in production

- ❌ Not enabling configuration store cache in production — every request hits the database
- ✅ Use `AddConfigurationStoreCache()` to reduce database load

- ❌ Running multiple instances without shared Data Protection keys — each instance has different encryption keys
- ✅ Configure shared Data Protection key storage and protection

- ❌ Directly modifying index properties on persisted grants in the database expecting behavioral changes
- ✅ The `Data` property is the authoritative source; index properties are read-only metadata

- ❌ Not configuring `ConsumedTokenCleanupDelay` when accepting consumed refresh tokens
- ✅ Set the delay to match the grace period in your custom `IRefreshTokenService`

## Common Pitfalls

1. **Missing migrations assembly**: `sql.MigrationsAssembly(migrationsAssembly)` must point to the assembly containing your migration classes. If missing, EF Core will fail to create or apply migrations.

2. **Different connection strings for configuration and operational stores**: You can use the same or different databases. Both DbContexts are independent and can point to different servers.

3. **Token cleanup does not remove consumed grants by default**: You must explicitly set `RemoveConsumedTokens = true`. Otherwise, consumed refresh tokens and authorization codes remain in the database.

4. **Signing keys stored on file system by default**: In containerized or load-balanced environments, the default file system key store may not share keys between instances. Use the EF operational store or a custom `ISigningKeyStore`.

5. **Schema changes are your responsibility**: When upgrading IdentityServer versions, check for schema changes and apply appropriate migrations. Duende does not auto-migrate.

6. **No built-in admin UI**: IdentityServer does not include an administrative interface for managing configuration data. You need third-party tools or custom implementations.

---

## Related Skills

- `identityserver-configuration` — client definitions, resources, scopes
- `identityserver-deployment` — production deployment, data protection, health checks
- `identityserver-aspire` — orchestrating IdentityServer in Aspire AppHost
