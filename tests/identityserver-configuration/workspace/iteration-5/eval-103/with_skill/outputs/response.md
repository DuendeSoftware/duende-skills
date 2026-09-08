# API Resources and Scopes for Invoice & Customer APIs

Define the service-specific scopes and the shared scopes as `ApiScope`s, then group them under two `ApiResource`s (`invoice` and `customer`). The `aud` (audience) claim is derived from the **API Resource name**, which is what lets each API confirm a token was intended for it.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    // API Scopes — permission model (service-specific + shared)
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            // Invoice-specific
            new ApiScope("invoice.read", "Read invoices"),
            new ApiScope("invoice.pay",  "Pay invoices"),

            // Customer-specific
            new ApiScope("customer.read",    "Read customers"),
            new ApiScope("customer.contact", "Contact customers"),

            // Shared across both APIs
            new ApiScope("manage",    "Administrative access"),
            new ApiScope("enumerate", "Enumerate data")
        };

    // API Resources — logical APIs that set the aud claim
    public static IEnumerable<ApiResource> ApiResources =>
        new ApiResource[]
        {
            new ApiResource("invoice", "Invoice API")
            {
                Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" }
            },
            new ApiResource("customer", "Customer API")
            {
                Scopes = { "customer.read", "customer.contact", "manage", "enumerate" }
            }
        };
}
```

Register all resources and scopes:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

## How the `aud` Claim Works

- **The `aud` claim comes from the `ApiResource.Name`**, not from the scope. So when a token includes a scope that belongs to the `invoice` resource, the token gets `"aud": "invoice"`.
- Requesting `invoice.read` + `invoice.pay` → `"aud": "invoice"`.
- Requesting `invoice.read` + `customer.read` → `"aud": ["invoice", "customer"]` (both audiences).
- Requesting a **shared** scope like `manage` → `"aud": ["invoice", "customer"]`, because `manage` is listed under both resources.

Each API validates its own audience:

```csharp
// Invoice API
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(o =>
    {
        o.Authority = "https://identity.example.com";
        o.Audience  = "invoice"; // must match the ApiResource name
    });
```

That way, `invoice` and `customer` each accept only tokens carrying their own resource name in `aud`, while still being able to share the `manage` and `enumerate` scopes.
