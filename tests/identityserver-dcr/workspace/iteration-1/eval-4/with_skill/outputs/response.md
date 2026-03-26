# Software Statement Validation

Here's a validator that requires and validates software statements from a trusted issuer:

```csharp
public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;

        // Require a software statement
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("A software statement is required for client registration");
            return;
        }

        // Validate the JWT
        var handler = new JsonWebTokenHandler();
        var validationResult = await handler.ValidateTokenAsync(
            softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                IssuerSigningKeys = await GetTrustedSigningKeysAsync(),
                ValidateLifetime = true,
                ValidateAudience = false
            });

        if (!validationResult.IsValid)
        {
            context.SetError($"Invalid software statement: {validationResult.Exception?.Message}");
            return;
        }

        // Map claims from the software statement to client properties
        var claims = validationResult.ClaimsIdentity;
        var softwareName = claims.FindFirst("software_name")?.Value;
        if (!string.IsNullOrEmpty(softwareName))
        {
            context.Client.ClientName = softwareName;
        }

        await base.ValidateSoftwareStatementAsync(context);
    }

    private async Task<IEnumerable<SecurityKey>> GetTrustedSigningKeysAsync()
    {
        // Fetch JWKS from the trusted issuer's discovery document
        var handler = new HttpClient();
        var disco = await handler.GetDiscoveryDocumentAsync(
            "https://trusted-issuer.example.com");
        return disco.KeySet.Keys
            .Select(k => (SecurityKey)k)
            .ToList();
    }
}
```

Register:

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementDcrValidator>();
```

## Validation Flow

1. **Check presence**: Reject the request if no software statement is provided.
2. **Validate JWT**: Use `JsonWebTokenHandler` to validate the signature, issuer, and expiration.
3. **Map claims**: Extract claims like `software_name` and apply them to the client being registered.
4. **Call base**: Let the base class continue its validation pipeline.
