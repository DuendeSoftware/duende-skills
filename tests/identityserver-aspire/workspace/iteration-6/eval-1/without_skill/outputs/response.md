```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql");
var db = sql.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identityserver")
    .WithReference(db)
    .WaitFor(db);

var weatherApi = builder.AddProject<Projects.WeatherApi>("weatherapi")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.AddProject<Projects.WebApp>("webapp")
    .WithReference(identityServer)
    .WithReference(weatherApi)
    .WaitFor(identityServer)
    .WaitFor(weatherApi);

builder.Build().Run();
```

`WaitFor` delays starting a resource until the target is running/healthy. IdentityServer waits for the database, and the API and web app wait for IdentityServer. `WithReference` injects connection strings/service discovery. Add a `/health` check endpoint to IdentityServer so `WaitFor` knows when it is truly ready.
