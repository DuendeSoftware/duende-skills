# Audience Isolation with API Resources and API Scopes

To make tokens issued for `catalog-api` unusable at `orders-api` (and vice versa), you need **both** `ApiScope` and `ApiResource`. Scopes model the permissions (`read`, `write`); API resources define the logical API boundary and, critically, control the `aud` (audience) claim. Each API validates that its own name appears in the token's `aud`.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    // API Scopes — the permission model (shared vocabulary)
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("read",  "Read access"),
            new ApiScope("write", "Write access")
        };

    // API Resources — logical API boundaries that set the "aud" claim
    public static IEnumerable<ApiResource> ApiResources =>
        new ApiResource[]
        {
            new ApiResource("catalog-api", "Catalog API")
            {
                Scopes = { "read", "write" }
            },
            new ApiResource("orders-api", "Orders API")
            {
                Scopes = { "read" }
            }
        };
}
```

Register all three collections with IdentityServer:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## How Audience Isolation Works

- The `aud` claim in the access token is derived from the **`ApiResource.Name`**, not from the scope.
- When a client requests the `read` scope targeting the catalog API, the token gets `"aud": "catalog-api"`. The orders API validates `aud == "orders-api"`, so it rejects that token — and vice versa.
- Each API's JWT bearer validation should be configured with its own audience:

```csharp
// In catalog-api's Program.cs
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api"; // rejects tokens minted for orders-api
    });
```

- Because both APIs share the `read` scope name, this is exactly the scenario where an `ApiResource` is **required** — API scopes alone produce no `aud` claim, so tokens would be accepted anywhere.
- `catalog-api` lists both `read` and `write`; `orders-api` lists only `read`, so a `write` scope is never associated with the orders audience.

> For true per-request single-audience tokens (RFC 8707 resource isolation), a client can additionally send the `resource` parameter to request a token scoped to just one API resource.
