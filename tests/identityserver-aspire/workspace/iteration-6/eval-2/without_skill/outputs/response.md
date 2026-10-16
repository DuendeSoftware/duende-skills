```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql");
var db = sql.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identityserver")
    .WithReference(db)
    .WaitFor(db);

var weatherApi = builder.AddProject<Projects.WeatherApi>("weatherapi")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.AddProject<Projects.WebApp>("webapp")
    .WithReference(weatherApi)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "webapp")
    .WithEnvironment("Authentication__Scopes", "openid profile weather.read");

builder.Build().Run();
```

`GetEndpoint("https")` returns an `EndpointReference`, which Aspire resolves lazily to the real URL at startup. The double underscore maps to `:` in .NET configuration, so `Authentication__Authority` binds to `Authentication:Authority`. The API only gets the authority; the web app also gets client ID and scopes.
