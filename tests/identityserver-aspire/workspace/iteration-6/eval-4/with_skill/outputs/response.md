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

builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

Configure shared state **before** using `WithReplicas`; otherwise you get token validation failures, lost sessions and cookie errors:

- **Shared signing key store**: all replicas use the same keys via a shared `ISigningKeyStore` (EF operational store or custom), not file-based keys.
- **Shared Data Protection keys**: persist to Redis, a database or blob storage so a cookie encrypted by one instance is readable by another.
- **Shared operational store**: persisted grants, device codes and server-side sessions in the shared database (not in-memory).
- **Distributed cache**: required for the OIDC state data formatter, JWT replay cache and PAR.

Also have health checks (`/health`) so `WaitFor` works, and see `identityserver-deployment` and `identityserver-data-storage` for the store setup.
