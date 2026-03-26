# Configuring API Scopes for Two Microservices

You can set up separate scopes for each API:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("catalog.read", "Read catalog"),
        new ApiScope("catalog.write", "Write catalog"),
        new ApiScope("orders.read", "Read orders")
    })
    .AddInMemoryClients(Config.Clients);
```

Then your clients can request `catalog.read` for catalog access or `orders.read` for orders access. The scopes themselves define what each API allows.

Each API validates the scope claim in the access token to ensure only authorized operations are performed:

```csharp
// In catalog-api
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CatalogRead", policy =>
        policy.RequireClaim("scope", "catalog.read"));
});
```

This way, a token with `catalog.read` won't grant access to the orders API because the orders API requires `orders.read`.
