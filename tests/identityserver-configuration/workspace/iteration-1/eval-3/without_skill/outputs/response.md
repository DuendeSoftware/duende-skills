To isolate tokens between your two microservices, you should define API scopes and API resources. Here's how:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("read", "Read Access"),
        new ApiScope("write", "Write Access")
    })
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
    .AddInMemoryClients(new List<Client>());

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

The `ApiResource` entries define the logical API boundaries. The `catalog-api` can accept tokens with `read` and `write` scopes, while `orders-api` only accepts `read`. The API resource name is used as the audience (`aud`) claim in the access token, so tokens issued for `catalog-api` won't be valid at `orders-api`.
