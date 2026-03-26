# Audience Isolation with API Resources and Scopes

To ensure tokens issued for `catalog-api` can't be used at `orders-api`, you need **API Resources** in addition to API Scopes. The API Resource controls the `aud` (audience) claim in access tokens.

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("read", "Read data"),
        new ApiScope("write", "Write data")
    })
    .AddInMemoryApiResources(new ApiResource[]
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
    .AddInMemoryClients(Config.Clients);
```

## How Audience Isolation Works

The `aud` claim is derived from the API Resource name. When a client requests scopes, IdentityServer determines which API Resources contain those scopes and adds their names as audience values.

### Example Token for catalog-api

When a client requests `read` and `write` scopes targeting the catalog-api:

```json
{
  "aud": ["catalog-api", "orders-api"],
  "scope": "read write"
}
```

Note: Because `read` is shared between both resources, requesting `read` results in both audiences. The `write` scope is only in `catalog-api`.

### Achieving Strict Isolation

For strict token isolation, use resource-specific scope names:

```csharp
.AddInMemoryApiScopes(new ApiScope[]
{
    new ApiScope("catalog.read", "Read catalog data"),
    new ApiScope("catalog.write", "Write catalog data"),
    new ApiScope("orders.read", "Read order data")
})
.AddInMemoryApiResources(new ApiResource[]
{
    new ApiResource("catalog-api", "Product Catalog API")
    {
        Scopes = { "catalog.read", "catalog.write" }
    },
    new ApiResource("orders-api", "Order Management API")
    {
        Scopes = { "orders.read" }
    }
})
```

Now a token with `catalog.read` will only have `aud: "catalog-api"`, and the orders-api will reject it because the audience doesn't match.

For even stricter isolation, use the `resource` parameter (RFC 8707) to explicitly target a specific API Resource in the token request.
