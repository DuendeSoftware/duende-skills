Here's how to set up a basic Duende IdentityServer host with in-memory stores, a `weatherapi` API scope, the standard `openid` and `profile` identity resources, and full event diagnostics:

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
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("weatherapi", "Weather API")
    })
    .AddInMemoryClients(Array.Empty<Client>());

var app = builder.Build();

app.UseIdentityServer(); // Includes UseAuthentication() — do NOT call UseAuthentication() separately
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

Key points:

1. **`AddIdentityServer`** registers all IdentityServer services. The options lambda configures `IdentityServerOptions`.
2. **Event raising** — all four event types are enabled (`RaiseErrorEvents`, `RaiseInformationEvents`, `RaiseFailureEvents`, `RaiseSuccessEvents`) for full diagnostics.
3. **`AddInMemoryIdentityResources`** registers the standard `openid` (maps to the `sub` claim) and `profile` (maps to `name`, `family_name`, etc.) identity resources.
4. **`AddInMemoryApiScopes`** registers the `weatherapi` scope that clients can request.
5. **`UseIdentityServer()`** replaces `UseAuthentication()` — it registers both the IdentityServer middleware and the authentication middleware internally. Calling `UseAuthentication()` separately is unnecessary and should be avoided.
6. **No clients** — we pass an empty client array since client definitions will be added later.
