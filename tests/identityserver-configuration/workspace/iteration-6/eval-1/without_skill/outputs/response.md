```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
.AddInMemoryIdentityResources(new IdentityResource[]
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile()
})
.AddInMemoryApiScopes(new[] { new ApiScope("weatherapi") });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```
`AddInMemoryIdentityResources` registers openid/profile, `AddInMemoryApiScopes` the `weatherapi` scope, and all four event flags are enabled. `UseIdentityServer()` adds the middleware (it includes authentication). No clients are registered yet.
