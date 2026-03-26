# Running 3 Replicas of IdentityServer in Aspire

## AppHost Configuration

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

builder.Build().Run();
```

## Shared State Requirements

Running multiple IdentityServer replicas requires that all instances share the following state. Without shared state, you will experience authentication failures, lost sessions, and token validation errors.

### 1. Shared Signing Key Store (Critical)

All instances must access the same signing keys via a shared `ISigningKeyStore`. If each instance generates its own signing keys, tokens issued by one instance will fail validation by another.

Use the EF Core operational store or a custom implementation backed by a shared database:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

**Do NOT use file-based signing keys or in-memory key stores with multiple replicas.** The default automatic key management stores keys in the operational database, which is correct for multi-instance.

### 2. Shared ASP.NET Data Protection Keys (Critical)

All instances must share Data Protection keys so that authentication cookies encrypted by one instance can be decrypted by another. Without this, users will get logged out when their request hits a different replica.

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>()
    .SetApplicationName("identity-server");
```

Or use Redis:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("identity-server");
```

### 3. Shared Operational Store (Critical)

Persisted grants, device codes, and server-side sessions must be stored in a shared database. All replicas read and write from the same store:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

### 4. Distributed Cache

Required if using the OIDC state data formatter, JWT replay cache, or Pushed Authorization Requests (PAR). Use Redis or SQL Server:

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = redisConnectionString;
});
```

## Warning

**Do NOT use `.WithReplicas(n)` without first configuring all of the above.** Multiple instances with file-based signing keys or in-memory stores will produce:
- Token validation failures (different signing keys per instance)
- Lost sessions (server-side sessions not shared)
- Authentication cookie errors (data protection keys not shared)
