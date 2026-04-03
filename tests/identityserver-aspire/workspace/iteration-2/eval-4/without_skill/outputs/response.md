# Running Multiple IdentityServer Replicas in Aspire

## AppHost Code

You can use `WithReplicas` to run multiple instances:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReplicas(3);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer);

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer);

builder.Build().Run();
```

## Considerations for Multiple Instances

When running multiple replicas of any web application, you need to think about shared state:

### Session Affinity / Sticky Sessions

You may want to configure sticky sessions so that a user's requests always go to the same instance. This avoids issues with in-memory session state.

### Database

Make sure all replicas connect to the same database for consistent data.

### Distributed Cache

Consider using Redis or another distributed cache for session state if you're not using sticky sessions:

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
```

### Load Balancing

Aspire will handle load balancing between the replicas automatically when other services reference the IdentityServer resource.

These are standard considerations for any horizontally-scaled web application.
