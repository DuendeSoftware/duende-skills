```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var secret = builder.Configuration["Clients:BillingService:Secret"]
    ?? throw new InvalidOperationException("Clients:BillingService:Secret is not configured");

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("invoices.read", "Read invoices"),
        new ApiScope("invoices.pay", "Pay invoices")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "billing-service",
            ClientName = "Billing Service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret(secret.Sha256()) },
            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```
Supply the secret via user-secrets, environment variable (`Clients__BillingService__Secret`) or a vault — not appsettings.json. Client-side the plain secret is sent; the server stores only the SHA-256 hash (ideally keep the hash itself in config).
