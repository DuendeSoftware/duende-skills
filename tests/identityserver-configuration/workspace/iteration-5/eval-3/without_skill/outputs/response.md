# Audience Isolation Between Two APIs

To stop a token minted for `catalog-api` from being accepted at `orders-api`, you need the access tokens to carry the correct `aud` (audience) claim, and each API to validate that audience. In IdentityServer this is done by defining **API Resources** (which control the `aud` claim) in addition to **API Scopes** (which model permissions).

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("read",  "Read access"),
            new ApiScope("write", "Write access")
        };

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

Register them:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

## Why this achieves isolation

- The `aud` claim is set from the API **resource name** (`catalog-api` / `orders-api`), not the scope.
- Each API only trusts tokens whose audience matches itself:

```csharp
// orders-api
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "orders-api";
    });
```

A token with `aud: catalog-api` presented to `orders-api` fails audience validation and is rejected. Since `orders-api` only maps the `read` scope, it never gets the `write` capability, and the two APIs remain isolated even though they share the `read` scope name.
