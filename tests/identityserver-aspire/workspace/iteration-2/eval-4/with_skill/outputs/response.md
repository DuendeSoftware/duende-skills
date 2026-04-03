# Running 3 Replicas of IdentityServer in Aspire

## AppHost Code

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer)
    .WithReplicas(3);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.Build().Run();
```

## Shared State Requirements

Running multiple IdentityServer instances with `.WithReplicas(3)` means three separate processes handle requests. For this to work correctly, **all replicas must share state**. Here's what needs to be configured:

### 1. Shared Signing Key Store (`ISigningKeyStore`)

All instances must access the same signing keys. If each instance generates its own keys, tokens issued by one instance can't be validated by another. Use a shared `ISigningKeyStore` implementation backed by the EF Core operational store or a custom database-backed store.

**Do NOT use file-based signing keys** (like the default development signing credential) with multiple replicas — each instance would have its own key file, causing token validation failures.

### 2. Shared ASP.NET Data Protection Keys

ASP.NET Data Protection encrypts authentication cookies and other sensitive data. All instances must share the same key ring so that a cookie encrypted by replica 1 can be decrypted by replica 2 or 3.

Configure a shared key storage provider:
- **Redis** — `PersistKeysToStackExchangeRedis()`
- **Database** — `PersistKeysToDbContext<T>()`
- **Azure Blob Storage** — `PersistKeysToAzureBlobStorage()`

Without shared data protection keys, users will get logged out randomly as requests hit different replicas.

### 3. Shared Operational Store (Persisted Grants, Device Codes, Sessions)

Persisted grants (authorization codes, refresh tokens), device codes, and server-side sessions must be stored in a shared database accessible by all replicas. Use the EF Core operational store with a shared database (which you already have via `identityDb`).

If using in-memory stores, grants created on one replica won't be visible to another — users will experience broken authentication flows.

### 4. Distributed Cache

If you use any of the following features, a distributed cache (e.g., Redis) is required across replicas:
- OIDC state data formatter
- JWT replay cache
- Pushed Authorization Requests (PAR)

### Summary

| Component | Requirement | Risk if not shared |
|---|---|---|
| Signing keys | Shared `ISigningKeyStore` (EF operational store) | Token validation failures |
| Data Protection keys | Shared key ring (Redis, DB, blob) | Authentication cookie errors, random logouts |
| Operational store | Shared database for grants & sessions | Broken auth flows, lost sessions |
| Distributed cache | Redis or similar | PAR failures, replay cache misses |

> **Warning:** Do NOT use `.WithReplicas(n)` without first configuring all of the above. Multiple instances with file-based signing keys or in-memory stores will produce token validation failures, lost sessions, and authentication cookie errors.
