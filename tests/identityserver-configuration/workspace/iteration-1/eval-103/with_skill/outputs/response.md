# API Resources and Scopes with Audience Isolation

Here's how to configure API Resources and Scopes for your Invoice and Customer APIs with proper audience isolation:

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
        // Service-specific scopes
        new ApiScope("invoice.read", "Read invoices"),
        new ApiScope("invoice.pay", "Process invoice payments"),
        new ApiScope("customer.read", "Read customer information"),
        new ApiScope("customer.contact", "Contact customers"),

        // Shared scopes used by both APIs
        new ApiScope("manage", "Administrative access"),
        new ApiScope("enumerate", "Enumerate data")
    })
    .AddInMemoryApiResources(new ApiResource[]
    {
        new ApiResource("invoice", "Invoice API")
        {
            Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" }
        },
        new ApiResource("customer", "Customer API")
        {
            Scopes = { "customer.read", "customer.contact", "manage", "enumerate" }
        }
    });
```

## How Audience Isolation Works

The `aud` (audience) claim in the access token is derived from the **API Resource Name** property. When a client requests scopes, IdentityServer determines which API Resources contain those scopes and adds their names to the `aud` claim.

### Token Examples

**Requesting `invoice.read` and `invoice.pay`:**
```json
{
  "aud": "invoice",
  "scope": "invoice.read invoice.pay"
}
```
Only the Invoice API is the audience, so the Customer API would reject this token.

**Requesting `invoice.read` and `customer.read`:**
```json
{
  "aud": ["invoice", "customer"],
  "scope": "invoice.read customer.read"
}
```
Both APIs are audiences because scopes from both resources were requested.

**Requesting `manage` (shared scope):**
```json
{
  "aud": ["invoice", "customer"],
  "scope": "manage"
}
```
Both APIs are audiences because `manage` belongs to both resources.

### API-Side Validation

Each API validates the `aud` claim to ensure the token is intended for it:

```csharp
// In Invoice API
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "invoice"; // Validates aud claim
    });
```
