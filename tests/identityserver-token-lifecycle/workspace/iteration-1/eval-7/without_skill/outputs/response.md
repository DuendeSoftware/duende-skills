# Internal Token Issuance Endpoint

To create an internal endpoint that issues JWT tokens for service-to-service communication, you can use the IdentityServer tools service:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    // ... existing config ...
    ;

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/internal-token", async (Duende.IdentityServer.IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,
        audiences: new[] { "backend.api" });

    return Results.Ok(new { token });
}).RequireAuthorization();

app.Run();
```

This endpoint:
- Requires authorization to prevent unauthorized access
- Uses `IIdentityServerTools.IssueClientJwtAsync` to create a JWT
- Sets a 10-minute lifetime (600 seconds)
- Targets the `backend.api` audience
