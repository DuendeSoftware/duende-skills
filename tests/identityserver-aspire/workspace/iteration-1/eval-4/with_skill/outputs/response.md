# Running Multiple IdentityServer Replicas in Aspire

## AppHost Configuration

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer)
    .WithReplicas(3);

builder.Build().Run();
```

## Shared State Requirements

Running 3 replicas of IdentityServer requires all instances to share state. Without this, you'll get token validation failures, lost sessions, and authentication cookie errors.

### 1. Shared Signing Key Store
All instances must access the same signing keys via a shared `ISigningKeyStore`. Use the EF Core operational store backed by the shared database, or a custom implementation. **Do NOT use file-based signing keys** — each replica would generate its own keys, causing tokens signed by one instance to fail validation on another.

### 2. Shared ASP.NET Data Protection Keys
All instances must share Data Protection keys (used for encrypting cookies, OIDC state, etc.). Store them in a shared location:
- Redis: `PersistKeysToStackExchangeRedis()`
- Database: `PersistKeysToDbContext()`
- Blob storage: `PersistKeysToAzureBlobStorage()`

Without shared Data Protection keys, authentication cookies encrypted by one instance can't be decrypted by another, causing users to lose their sessions.

### 3. Shared Operational Store
Persisted grants (refresh tokens, authorization codes), device codes, and server-side sessions must be in a shared database. All replicas need to read/write to the same operational store. **In-memory stores will not work** — each instance would have its own isolated state.

### 4. Distributed Cache
If using features like OIDC state data formatter, JWT replay cache, or Pushed Authorization Requests (PAR), a distributed cache (e.g., Redis) is required.

## Warning

Do NOT use `.WithReplicas(n)` without first configuring shared state. Multiple instances with file-based signing keys or in-memory stores will produce:
- Token validation failures (different signing keys per instance)
- Lost sessions (Data Protection key mismatch)
- Authentication cookie errors
- Missing persisted grants
