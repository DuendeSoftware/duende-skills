# API Resources and Scopes for Invoice and Customer APIs

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("invoice.read"),
        new ApiScope("invoice.pay"),
        new ApiScope("customer.read"),
        new ApiScope("customer.contact"),
        new ApiScope("manage"),
        new ApiScope("enumerate")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("invoice")
        {
            Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" }
        },
        new ApiResource("customer")
        {
            Scopes = { "customer.read", "customer.contact", "manage", "enumerate" }
        }
    });
```

The API Resources group scopes under logical APIs. The `aud` claim will reflect which API the token is for. Each API can then validate the audience to ensure the token is intended for it.
