Here's the updated `Program.cs` that sets up a basic Duende IdentityServer host with in-memory stores, the `weatherapi` API scope, standard identity resources, and full event diagnostics:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable all event types for diagnostics
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("weatherapi", "Weather API")
    });

var app = builder.Build();

app.UseIdentityServer(); // Includes UseAuthentication() — do NOT call UseAuthentication() separately
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key points:**

- `builder.Services.AddIdentityServer(options => { ... })` registers IdentityServer and provides the options lambda for configuration.
- All four event types (`RaiseErrorEvents`, `RaiseInformationEvents`, `RaiseFailureEvents`, `RaiseSuccessEvents`) are set to `true` for full diagnostics.
- `AddInMemoryIdentityResources` registers the standard `openid` and `profile` identity resources using `IdentityResources.OpenId()` and `IdentityResources.Profile()`.
- `AddInMemoryApiScopes` registers a single API scope named `weatherapi`.
- `app.UseIdentityServer()` is called instead of `app.UseAuthentication()` — it internally registers both the IdentityServer middleware and the authentication middleware, so calling `UseAuthentication()` separately is not needed.
