# Running Multiple IdentityServer Replicas

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

## Considerations for Multiple Instances

When running multiple instances of IdentityServer, you need to ensure state is shared:

1. **Database-backed stores** — Use a shared database for configuration and operational data so all instances can access the same clients, resources, and grants.

2. **Data Protection keys** — ASP.NET Core Data Protection keys must be shared across instances. Store them in a database or Redis so cookies encrypted by one instance can be decrypted by another.

3. **Session state** — If using server-side sessions, ensure they're stored in a shared location.

4. **Load balancer** — You'll need a load balancer in front of the replicas to distribute traffic.
