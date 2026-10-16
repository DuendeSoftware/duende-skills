```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("catalog.read"), new ApiScope("catalog.write"), new ApiScope("orders.read")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("catalog-api") { Scopes = { "catalog.read", "catalog.write" }, RequireResourceIndicator = true },
        new ApiResource("orders-api")  { Scopes = { "orders.read" }, RequireResourceIndicator = true }
    });
```
Since scope names must be unique, a shared name like `read` can't map separately; use `catalog.read` and `orders.read`. (If you really want `read` on both, one scope is shared by both resources and tokens get both audiences.) Each API resource yields its own `aud`; with `RequireResourceIndicator`, the audience is only included when the client passes `resource=catalog-api`, giving isolation. Each API validates its own audience.
