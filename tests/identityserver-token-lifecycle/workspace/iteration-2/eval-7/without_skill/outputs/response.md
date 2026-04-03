# Creating an Internal Token Endpoint

To create an endpoint that issues JWT tokens for internal service-to-service communication, you can create a custom endpoint that generates tokens.

## Implementation

```csharp
app.MapGet("/internal-token", async (HttpContext context) =>
{
    // You would need to use the token endpoint or a token generation service
    // to create a JWT token for the internal service
    
    var tokenService = context.RequestServices.GetRequiredService<ITokenService>();
    
    var token = await tokenService.CreateAccessTokenAsync(new TokenCreationRequest
    {
        Subject = new ClaimsPrincipal(),
        ValidatedResources = new ResourceValidationResult(),
        ValidatedRequest = new ValidatedRequest
        {
            Client = new Client { ClientId = "internal_service" }
        }
    });
    
    var jwt = await tokenService.CreateSecurityTokenAsync(token);
    
    return Results.Ok(new { token = jwt });
}).RequireAuthorization();
```

## Alternative Approach

If your IdentityServer provides an internal token issuing service, you could use that instead:

```csharp
app.MapGet("/internal-token", async (HttpContext context) =>
{
    // Check if there's a built-in service for issuing tokens
    // The exact API depends on your IdentityServer version
    var tokenTools = context.RequestServices.GetService<ITokenIssuanceService>();
    
    if (tokenTools != null)
    {
        var token = await tokenTools.IssueTokenAsync(
            clientId: "internal_service",
            lifetime: 600,  // 10 minutes
            audience: "backend.api");
        
        return Results.Ok(new { token });
    }
    
    return Results.StatusCode(500);
}).RequireAuthorization();
```

## Key Points

- The endpoint is mapped to `/internal-token`
- It requires authorization via `.RequireAuthorization()`
- The token should have a 10-minute lifetime (600 seconds)
- The audience should be set to `backend.api`
- The client_id should be `internal_service`

Note: The exact API for issuing internal tokens depends on your IdentityServer version. Check the documentation for the correct service to inject and the method to call.
