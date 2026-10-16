```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // IssuerUri left unset: inferred from the request (recommended)
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),   // required, returns sub
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[] { new ApiScope("weatherapi", "Weather API") });

var app = builder.Build();

app.UseIdentityServer(); // includes UseAuthentication()
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```
- Use `UseIdentityServer()` instead of `UseAuthentication()`; it registers both.
- All four event types are enabled. No clients are registered; add `.AddInMemoryClients(...)` later.
