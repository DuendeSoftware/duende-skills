# Wiring Up the Aspire AppHost

Here's how to set up your `Program.cs` with the service dependencies:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add the projects
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server");

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer);

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WithReference(api);

builder.Build().Run();
```

## Explanation

- The IdentityServer project is added first since other services depend on it.
- The Weather API references IdentityServer so it can validate tokens.
- The Web App references both IdentityServer (for login) and the API.

You'll want to make sure your IdentityServer project has its database connection string configured in `appsettings.json` or via environment variables. Aspire's service discovery will handle making the URLs available between services.

If you need a SQL Server database, you can add it to your AppHost's `appsettings.json` configuration and reference it from your IdentityServer project's connection strings.
