```csharp
using Duende.IdentityServer.Models;

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("manage"),
        new ApiScope("enumerate"),
        new ApiScope("invoice.read"),
        new ApiScope("invoice.write"),
        new ApiScope("customer.read"),
        new ApiScope("customer.write")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("invoice", "Invoice API")
        {
            Scopes = { "manage", "enumerate", "invoice.read", "invoice.write" }
        },
        new ApiResource("customer", "Customer API")
        {
            Scopes = { "manage", "enumerate", "customer.read", "customer.write" }
        }
    });
```
Scopes are the permissions; API resources group scopes and determine `aud`. A scope can belong to several resources. If a client requests `manage` alone, the token gets both audiences (`invoice` and `customer`). To get a single audience, request a resource-specific scope or use the `resource` parameter (RFC 8707), which needs `RequireResourceIndicator = true` on resources for strict isolation. Each API validates `aud` with its own name. Don't forget `app.UseIdentityServer()`.
