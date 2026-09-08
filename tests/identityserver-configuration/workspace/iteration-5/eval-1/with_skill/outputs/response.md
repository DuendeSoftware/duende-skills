# Basic Duende IdentityServer Host with In-Memory Stores

Here's a complete `Program.cs` that registers Duende IdentityServer with in-memory stores, defines the `weatherapi` scope and the `openid`/`profile` identity resources, and enables all event types for diagnostics.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Enable all event types for diagnostics
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);
    // No clients yet — resource definitions only

var app = builder.Build();

// UseIdentityServer registers both the IdentityServer middleware
// AND the authentication middleware — do NOT also call UseAuthentication().
app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

And the `Config` class holding the resource definitions:

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),   // required — maps to the "sub" claim
            new IdentityResources.Profile(),  // name, family_name, given_name, etc.
        };

    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("weatherapi", "Weather API")
        };
}
```

## Notes

- **`AddIdentityServer` with an options lambda** — all server configuration flows from `IdentityServerOptions`. Here we only use it to enable events.
- **Events** — enabling all four (`RaiseErrorEvents`, `RaiseInformationEvents`, `RaiseFailureEvents`, `RaiseSuccessEvents`) is the recommended production/diagnostics setting.
- **`UseIdentityServer()`** already calls `UseAuthentication()` internally, so calling `UseAuthentication()` separately would double-register the middleware. Do not add it.
- No clients are registered yet — you can add `.AddInMemoryClients(...)` to the builder chain later when you define client applications.
