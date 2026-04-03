To achieve audience isolation between `catalog-api` and `orders-api`, you need to use both `ApiScope` (for the permission model) and `ApiResource` (for audience boundaries). The `ApiResource` name becomes the `aud` claim in access tokens, ensuring tokens issued for one API cannot be used at another.

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    // API Scopes — define the permission model
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("read", "Read access"),
        new ApiScope("write", "Write access")
    })
    // API Resources — define the logical API boundaries and audience claim
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("catalog-api", "Product Catalog API")
        {
            Scopes = { "read", "write" }
        },
        new ApiResource("orders-api", "Order Management API")
        {
            Scopes = { "read" }
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**How audience isolation works:**

- `ApiScope` defines the permissions: `read` and `write`.
- `ApiResource` groups scopes under a logical API. Each `ApiResource` name (e.g., `"catalog-api"`, `"orders-api"`) becomes the `aud` (audience) claim in the access token.
- `catalog-api` allows both `read` and `write` scopes.
- `orders-api` only allows the `read` scope — `write` is not in its `Scopes` collection.
- When a client requests the `read` scope with a `resource` parameter targeting `catalog-api`, the token will have `aud: "catalog-api"`. The orders-api can validate the audience and reject the token.
- If a client requests `read` without a specific resource indicator and both API resources contain that scope, the token will have both audiences. For strict isolation, use the `resource` parameter (RFC 8707) or configure `RequireResourceIndicator = true` on the `ApiResource`.
