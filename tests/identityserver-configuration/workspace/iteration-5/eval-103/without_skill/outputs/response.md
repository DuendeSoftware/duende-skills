# API Resources and Scopes for Invoice & Customer APIs

You want each API to validate that a token is meant for it (`aud` claim). In IdentityServer, the `aud` claim comes from the API **Resource** name, so you define an `ApiResource` per API and reference both the service-specific and shared scopes.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            // Invoice API scopes
            new ApiScope("invoice.read", "Read invoices"),
            new ApiScope("invoice.write", "Write invoices"),

            // Customer API scopes
            new ApiScope("customer.read", "Read customers"),
            new ApiScope("customer.write", "Write customers"),

            // Shared scopes
            new ApiScope("manage", "Manage"),
            new ApiScope("enumerate", "Enumerate")
        };

    public static IEnumerable<ApiResource> ApiResources =>
        new ApiResource[]
        {
            new ApiResource("invoice", "Invoice API")
            {
                Scopes = { "invoice.read", "invoice.write", "manage", "enumerate" }
            },
            new ApiResource("customer", "Customer API")
            {
                Scopes = { "customer.read", "customer.write", "manage", "enumerate" }
            }
        };
}
```

Register both:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

## How the `aud` claim is set

- The audience is taken from the **ApiResource Name** (`invoice` / `customer`). When a requested scope belongs to a resource, that resource name is added to `aud`.
- Requesting only invoice scopes → `aud: "invoice"`.
- Requesting a shared scope like `manage` → `aud` includes both `invoice` and `customer`, since both resources contain `manage`.

Each API then validates its own audience:

```csharp
// Invoice API
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(o =>
    {
        o.Authority = "https://identity.example.com";
        o.Audience = "invoice";
    });
```
