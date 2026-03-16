# Setting Up API Resources and Scopes for Two Microservices

To get the correct `aud` claim so each API can validate tokens are intended for it, you'll need to define both API Scopes and API Resources.

## Define API Scopes

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("invoice.read", "Read invoices"),
    new ApiScope("invoice.write", "Write invoices"),
    new ApiScope("customer.read", "Read customers"),
    new ApiScope("customer.write", "Write customers"),
    new ApiScope("manage", "Administrative access"),
    new ApiScope("enumerate", "List data")
];
```

## Define API Resources

```csharp
public static IEnumerable<ApiResource> ApiResources =>
[
    new ApiResource("invoice")
    {
        Scopes = { "invoice.read", "invoice.write", "manage", "enumerate" }
    },
    new ApiResource("customer")
    {
        Scopes = { "customer.read", "customer.write", "manage", "enumerate" }
    }
];
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## How Audience Claims Work

When a client requests scopes, IdentityServer looks at which API Resources contain those scopes and adds the corresponding resource names as audience claims. For example, if a client requests `invoice.read`, the token will contain `"aud": "invoice"`.

Each API should then validate that the token's audience includes its own resource name.
