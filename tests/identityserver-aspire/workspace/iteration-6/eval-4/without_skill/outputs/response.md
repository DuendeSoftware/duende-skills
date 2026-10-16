```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql").WithDataVolume();
var db = sql.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identityserver")
    .WithReference(db)
    .WaitFor(db)
    .WithReplicas(3);

builder.AddProject<Projects.WeatherApi>("weatherapi")
    .WithReference(identityServer).WaitFor(identityServer);

builder.AddProject<Projects.WebApp>("webapp")
    .WithReference(identityServer).WaitFor(identityServer);

builder.Build().Run();
```

Shared state requirements for multiple instances:

- **Data Protection keys**: persist to a shared store (SQL Server/Redis/blob) with `AddDataProtection().PersistKeysToDbContext<>()` and a common application name, so cookies and protected data work on any replica.
- **Signing keys**: use the same keys across instances (automatic key management with the shared operational store, or a shared certificate).
- **Operational store**: persisted grants, device codes, and keys must live in the shared database (EF stores), not in memory.
- **Configuration store**: clients/resources in the shared DB.
- **Caching**: use a distributed cache (Redis) rather than in-memory for things like state/replay and server-side sessions.
- **Issuer URI**: set a fixed `IssuerUri` / public origin so that tokens have the same issuer regardless of replica.
- **Sessions**: use server-side sessions or shared data protection so authentication cookies are valid across replicas.
- Run migrations once (not in each replica).
