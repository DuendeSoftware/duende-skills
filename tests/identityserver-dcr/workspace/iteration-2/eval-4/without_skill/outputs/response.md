To validate software statements in a DCR flow, you'll need to validate the signed JWT against the trusted issuer's keys. Here's an approach:

### Software Statement Validation

```csharp
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public class SoftwareStatementValidator
{
    private readonly HttpClient _httpClient;

    public SoftwareStatementValidator(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<SoftwareStatementResult> ValidateAsync(string? softwareStatement)
    {
        if (string.IsNullOrEmpty(softwareStatement))
        {
            return SoftwareStatementResult.Failed("Software statement is required");
        }

        var handler = new JsonWebTokenHandler();
        
        // Get the trusted issuer's signing keys
        var jwksJson = await _httpClient.GetStringAsync(
            "https://trusted-issuer.example.com/.well-known/jwks.json");
        var jwks = new JsonWebKeySet(jwksJson);

        var result = await handler.ValidateTokenAsync(softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                IssuerSigningKeys = jwks.GetSigningKeys(),
                ValidateLifetime = true,
                ValidateAudience = false
            });

        if (!result.IsValid)
        {
            return SoftwareStatementResult.Failed("Invalid software statement");
        }

        return SoftwareStatementResult.Success(result.ClaimsIdentity);
    }
}

public class SoftwareStatementResult
{
    public bool IsValid { get; set; }
    public string? Error { get; set; }
    public System.Security.Claims.ClaimsIdentity? Claims { get; set; }

    public static SoftwareStatementResult Failed(string error) => new() { IsValid = false, Error = error };
    public static SoftwareStatementResult Success(System.Security.Claims.ClaimsIdentity claims) => new() { IsValid = true, Claims = claims };
}
```

### Using it in your DCR endpoint

```csharp
app.MapPost("/connect/register", async (
    SoftwareStatementValidator validator,
    HttpContext context) =>
{
    var request = await context.Request.ReadFromJsonAsync<DcrRequest>();
    
    var ssResult = await validator.ValidateAsync(request?.SoftwareStatement);
    if (!ssResult.IsValid)
    {
        return Results.BadRequest(new { error = ssResult.Error });
    }

    // Apply software_name from the statement to the client
    var softwareName = ssResult.Claims?.FindFirst("software_name")?.Value;
    
    // Create the client with the software name
    var client = new Client
    {
        ClientId = Guid.NewGuid().ToString(),
        ClientName = softwareName ?? "Unknown"
    };
    
    // Store and return...
    return Results.Ok(new { client_id = client.ClientId, client_name = client.ClientName });
}).RequireAuthorization();
```

### Key considerations

- Always validate the JWT signature against the trusted issuer's keys
- Reject requests without a software statement if it's required
- Cache the JWKS keys to avoid fetching them on every request
- Map relevant claims from the software statement to client properties
