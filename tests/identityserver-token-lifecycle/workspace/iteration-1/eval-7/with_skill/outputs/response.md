# Internal Token Endpoint with IIdentityServerTools

Here's how to create an endpoint that issues internal JWT tokens using `IIdentityServerTools`:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients ...
    })
    // ... other configuration ...
    ;

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

// Internal token endpoint
app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,  // 10 minutes
        audiences: new[] { "backend.api" });

    return Results.Ok(new { access_token = token });
}).RequireAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

- **`IIdentityServerTools`** is injected from DI. It provides methods to issue tokens programmatically without going through the protocol endpoints.
- **`IssueClientJwtAsync`** creates a client-level JWT (no user context). Parameters:
  - `clientId`: The client identifier to put in the token
  - `lifetime`: Token lifetime in seconds (600 = 10 minutes)
  - `audiences`: The intended audience(s) for the token
- **`RequireAuthorization()`** ensures only authenticated callers can request internal tokens. This prevents unauthorized token issuance.
- This pattern is useful when extensibility code within IdentityServer needs to call downstream APIs with a proper access token.
