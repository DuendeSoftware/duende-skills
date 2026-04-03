# Setting Up API Resources and Scopes for Two Microservices

To set up your Invoice API and Customer API with separate scopes and proper token isolation, you'll want to define API scopes for each service and register them with IdentityServer.

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
        // Invoice API scopes
        new ApiScope("invoice.manage", "Manage invoices"),
        new ApiScope("invoice.enumerate", "List invoices"),

        // Customer API scopes
        new ApiScope("customer.manage", "Manage customers"),
        new ApiScope("customer.enumerate", "List customers")
    })
    .AddInMemoryClients(Array.Empty<Client>());

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## How Token Validation Works

Each API should validate that the token contains the appropriate scope. In your Invoice API:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://your-identity-server";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = false // Scopes handle access control
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("InvoiceRead", policy =>
        policy.RequireClaim("scope", "invoice.manage", "invoice.enumerate"));
});
```

By using separate scope prefixes (`invoice.*` and `customer.*`), you can control which service accepts which tokens at the authorization policy level. Each API checks for its own scopes before granting access.

The shared scopes (`manage` and `enumerate`) are prefixed per service so they don't overlap. This way a token for Invoice API operations won't grant access to Customer API operations.
