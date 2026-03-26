# Internal Token Endpoint

To create an endpoint that issues JWT tokens internally, you can use IdentityServer's tooling API.

```csharp
app.MapGet("/internal-token", async (HttpContext ctx) =>
{
    var tools = ctx.RequestServices.GetRequiredService<IIdentityServerTools>();

    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,
        audiences: new[] { "backend.api" });

    return Results.Ok(new { token });
}).RequireAuthorization();
```

This uses `IIdentityServerTools` to create a client JWT token with a 10-minute lifetime targeting the `backend.api` audience. The endpoint requires authorization to prevent unauthorized token minting.

You'll need to add `using Duende.IdentityServer;` for the `IIdentityServerTools` type.
