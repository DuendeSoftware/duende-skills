# Running Multiple IdentityServer Replicas in Aspire

You can scale IdentityServer with `WithReplicas`:

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

## Considerations

When running multiple instances, you need to ensure:

1. **Database**: All instances should connect to the same database for client and resource configuration.

2. **Session State**: If using server-side sessions, ensure they're stored in a shared location (like a database or Redis).

3. **Load Balancing**: Aspire handles load balancing across replicas automatically.

4. **Sticky Sessions**: Consider using sticky sessions if you rely on in-memory state.

The main thing to be aware of is that all replicas should share the same configuration and persistent state through the database.
