# API Resources and Scopes for Audience Isolation

To ensure each microservice only accepts tokens intended for it, you need to use **API Resources** alongside **API Scopes**. The key insight is that the `aud` (audience) claim in access tokens is derived from the **ApiResource Name property**, not from API Scopes.

## Understanding the Relationship

- **API Scopes** define what operations/permissions a client can request (e.g., `manage`, `enumerate`, `invoice.read`).
- **API Resources** group scopes under a logical API and control the `aud` claim. When a client requests a scope that belongs to an API Resource, the resource's name is added as the `aud` claim.

## API Scope Definitions

Define all scopes — both service-specific and shared:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    // Invoice API-specific scopes
    new ApiScope("invoice.read", "Read invoices"),
    new ApiScope("invoice.write", "Write invoices"),

    // Customer API-specific scopes
    new ApiScope("customer.read", "Read customer data"),
    new ApiScope("customer.write", "Write customer data"),

    // Shared scopes used by both APIs
    new ApiScope("manage", "Administrative management access"),
    new ApiScope("enumerate", "Enumerate/list data")
];
```

## API Resource Definitions

Each API Resource groups its relevant scopes. The `Name` property of the resource becomes the `aud` claim in the token:

```csharp
public static IEnumerable<ApiResource> ApiResources =>
[
    new ApiResource("invoice", "Invoice API")
    {
        Scopes = { "invoice.read", "invoice.write", "manage", "enumerate" }
    },
    new ApiResource("customer", "Customer API")
    {
        Scopes = { "customer.read", "customer.write", "manage", "enumerate" }
    }
];
```

## Registration in Program.cs

Both API Resources and API Scopes must be registered:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients)
    .AddTestUsers(TestUsers.Users);
```

## How the `aud` Claim Works

The **`aud` claim in the token is derived from the ApiResource Name property**. Here's how it works for different scope requests:

**Requesting `invoice.read` and `invoice.write`:**
```json
{
  "aud": "invoice",
  "scope": "invoice.read invoice.write"
}
```

**Requesting `invoice.read` and `customer.read`:**
```json
{
  "aud": ["invoice", "customer"],
  "scope": "invoice.read customer.read"
}
```

**Requesting `manage` (shared scope — both resources contain it):**
```json
{
  "aud": ["invoice", "customer"],
  "scope": "manage"
}
```

## API-Side Validation

Each API validates the `aud` claim matches its own name:

```csharp
// In the Invoice API
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidAudiences = new[] { "invoice" };
    });
```

This ensures a token issued for only the Customer API (`aud: "customer"`) will be rejected by the Invoice API.
