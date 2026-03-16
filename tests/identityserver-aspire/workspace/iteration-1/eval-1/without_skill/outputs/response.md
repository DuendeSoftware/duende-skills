# Aspire AppHost Setup

Here's how to set up the dependency graph in your Aspire AppHost:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add SQL Server
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Add IdentityServer project
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Add Weather API
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Add Web App
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

This sets up the dependency chain: SQL Server starts first, then IdentityServer, then the API and web app. Using `WaitFor` ensures each service is healthy before dependents start. `WithReference` makes the connection strings and service URLs available to each project.
