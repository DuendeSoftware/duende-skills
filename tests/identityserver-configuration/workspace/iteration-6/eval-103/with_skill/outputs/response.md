```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes => new[]
    {
        new ApiScope("invoice.read",    "Reads your invoices."),
        new ApiScope("invoice.pay",     "Pays your invoices."),
        new ApiScope("customer.read",   "Reads customer information."),
        new ApiScope("customer.contact","Allows contacting customers."),
        new ApiScope("manage",          "Provides administrative access."),
        new ApiScope("enumerate",       "Allows enumerating data.")
    };

    public static IEnumerable<ApiResource> ApiResources => new[]
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

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
// ...
app.UseIdentityServer();
```
Resulting `aud` claims:

| Requested scopes | Token |
|---|---|
| `invoice.read invoice.pay` | `"aud": "invoice"` |
| `invoice.read customer.read` | `"aud": ["invoice","customer"]` |
| `manage` (shared) | `"aud": ["invoice","customer"]` |

Scopes are permissions; API resources group them and generate the `aud`. Shared scopes (`manage`, `enumerate`) belong to both resources, so requesting only a shared scope yields both audiences. If you need a token for one API only, use resource isolation (RFC 8707): the client sends `resource=invoice`, and you can set `RequireResourceIndicator = true` on the resource so its audience is only included when explicitly requested. Each API then validates that its own name (`invoice` / `customer`) is in `aud`. (Resource isolation is an Enterprise Edition feature.)

Alternative: `EmitStaticAudienceClaim` gives a single generic `{issuer}/resources` audience, but it can't distinguish between your APIs.
