# API Resources and API Scopes for Audience Isolation — Invoice API & Customer API

To ensure that access tokens contain the correct `aud` claim so each API can validate that the token is intended for it, you need to define both **API Scopes** (permissions) and **API Resources** (logical API boundaries). The `aud` claim in the token is derived from the `ApiResource` `Name` property.

## How It Works

- **API Scopes** define the permissions/operations a client can request (e.g., `invoice.read`, `customer.read`, `manage`, `enumerate`).
- **API Resources** group scopes under a logical API. When a scope belonging to an API Resource is granted, that resource's name is added as the `aud` claim in the access token.
- This means a token containing only `invoice.read` will have `"aud": "invoice"`, while a token containing both `invoice.read` and `customer.read` will have `"aud": ["invoice", "customer"]`.
- Shared scopes like `manage` and `enumerate` that appear in both resources will cause both audience values to be included when requested.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryApiScopes(new[]
    {
        // Invoice-specific scopes
        new ApiScope(name: "invoice.read",      displayName: "Read invoices"),
        new ApiScope(name: "invoice.pay",       displayName: "Pay invoices"),

        // Customer-specific scopes
        new ApiScope(name: "customer.read",     displayName: "Read customer data"),
        new ApiScope(name: "customer.contact",  displayName: "Contact customers"),

        // Shared scopes used by both APIs
        new ApiScope(name: "manage",            displayName: "Administrative access"),
        new ApiScope(name: "enumerate",         displayName: "Enumerate data")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("invoice", "Invoice API")
        {
            Scopes = { "invoice.read", "invoice.pay", "manage", "enumerate" }
        },
        new ApiResource("customer", "Customer API")
        {
            Scopes = { "customer.read", "customer.contact", "manage", "enumerate" }
        }
    })
    .AddInMemoryClients(Array.Empty<Client>());

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Token Audience Examples

When a client requests `invoice.read` and `invoice.pay`:

```json
{
  "aud": "invoice",
  "scope": "invoice.read invoice.pay"
}
```

When a client requests `invoice.read` and `customer.read`:

```json
{
  "aud": ["invoice", "customer"],
  "scope": "invoice.read customer.read"
}
```

When a client requests `manage` (shared scope):

```json
{
  "aud": ["invoice", "customer"],
  "scope": "manage"
}
```

Each API then validates that its own name appears in the `aud` claim before accepting the token. This provides audience isolation — a token issued only for the Invoice API cannot be replayed at the Customer API.
