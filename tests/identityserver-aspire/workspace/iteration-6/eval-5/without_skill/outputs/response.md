IDX20803 means the API's JWT bearer middleware couldn't fetch the discovery document, typically because the API started before IdentityServer was ready, or the authority URL is wrong.

**Fix in the AppHost:**

```csharp
var sql = builder.AddSqlServer("sql");
var db = sql.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identityserver")
    .WithReference(db)
    .WaitFor(db);

builder.AddProject<Projects.WeatherApi>("weatherapi")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));
```

Also:
- Add a health check on IdentityServer (`/health`) and `.WithHttpHealthCheck("/health")` so `WaitFor` waits until it is really up.
- Make sure the authority uses the right scheme/port (https endpoint) and that the dev certificate is trusted (`dotnet dev-certs https --trust`).
- Confirm the issuer in tokens matches the authority.
