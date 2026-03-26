# Basic IdentityServer Host Setup

Here's the complete `Program.cs` with in-memory stores, an API scope, identity resources, and event diagnostics:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Enable all event types for diagnostics
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
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("weatherapi", "Weather API")
    });

var app = builder.Build();

app.UseIdentityServer(); // Includes UseAuthentication() internally
app.UseAuthorization();

app.Run();
```

## What Each Part Does

### AddIdentityServer Options

The `options` lambda configures `IdentityServerOptions`. Enabling all four event types gives full visibility into protocol flows, errors, and token issuance in production.

### Identity Resources

- `IdentityResources.OpenId()` — Required by the OpenID Connect specification. Maps to the `sub` (subject ID) claim.
- `IdentityResources.Profile()` — Maps to `name`, `family_name`, `given_name`, and other profile claims.

### API Scopes

The `weatherapi` scope represents a permission to access the Weather API. Clients will request this scope when obtaining access tokens.

### Middleware

`UseIdentityServer()` registers both the IdentityServer middleware and the ASP.NET Core authentication middleware. Do not call `UseAuthentication()` separately — it's already included.
