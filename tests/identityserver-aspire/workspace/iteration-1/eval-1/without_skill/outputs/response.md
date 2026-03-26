# Aspire AppHost Dependency Graph

Here's how to set up the dependency graph in your `Program.cs`:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add SQL Server
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Add IdentityServer - depends on database
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb);

// Add Weather API
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer);

// Add Web App
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WithReference(api);

builder.Build().Run();
```

This sets up service discovery so each project can find the others. The `WithReference` calls ensure that connection strings and service URLs are passed between projects.

The IdentityServer project gets the database connection string via `WithReference(identityDb)`, and both the API and web app get the IdentityServer URL via `WithReference(identityServer)`.
