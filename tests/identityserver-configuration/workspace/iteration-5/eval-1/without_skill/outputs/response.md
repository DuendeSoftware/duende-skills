# Basic Duende IdentityServer Host with In-Memory Stores

Below is a `Program.cs` that sets up a minimal Duende IdentityServer host with in-memory stores, a `weatherapi` API scope, the standard `openid` and `profile` identity resources, and all events enabled for diagnostics.

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Turn on all events for diagnostics
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

Define the resources in a small config class:

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile()
        };

    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("weatherapi", "Weather API")
        };
}
```

## Explanation

- `AddIdentityServer(options => { ... })` registers the core services; the options lambda enables all four event types.
- `AddInMemoryIdentityResources` registers `OpenId` and `Profile`.
- `AddInMemoryApiScopes` registers the single `weatherapi` scope.
- `app.UseIdentityServer()` wires the IdentityServer middleware into the pipeline. It also installs the authentication middleware, so you don't need a separate `UseAuthentication()` call.

No clients are defined yet, which is fine — you can add them later with `.AddInMemoryClients(...)`.
