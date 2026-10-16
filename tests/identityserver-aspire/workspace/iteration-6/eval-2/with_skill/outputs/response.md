```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "weather.read");

builder.Build().Run();
```

Double underscores map to `:` in `IConfiguration` (`Authentication:Authority`, `Authentication:ClientId`, `Authentication:Scopes:0`…). Array-style `Scopes__0/1/2` binds as a list.

App-side reading:

```csharp
// WebApp
.AddOpenIdConnect(o =>
{
    o.Authority = builder.Configuration["Authentication:Authority"];
    o.ClientId = builder.Configuration["Authentication:ClientId"];
    o.Scope.Clear();
    foreach (var s in builder.Configuration.GetSection("Authentication:Scopes").Get<string[]>() ?? [])
        o.Scope.Add(s);
});

// API
.AddJwtBearer(o => o.Authority = builder.Configuration["Authentication:Authority"]);
```

Don't set `IssuerUri` unless the internal and public URLs differ; mismatched issuers break token validation.
