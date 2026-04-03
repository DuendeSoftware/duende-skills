Here's how to validate software statements in your DCR flow by overriding `ValidateSoftwareStatementAsync` in a custom `DynamicClientRegistrationValidator`.

### SoftwareStatementDcrValidator.cs

```csharp
using System.IdentityModel.Tokens.Jwt;
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Configuration.Models;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    private readonly HttpClient _httpClient;

    public SoftwareStatementDcrValidator(IHttpClientFactory httpClientFactory)
    {
        _httpClient = httpClientFactory.CreateClient();
    }

    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;

        // Reject requests without a software statement
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("A software statement is required for client registration");
            return;
        }

        // Validate the software statement JWT against the trusted issuer
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
            context.SetError("Invalid software statement: " + validationResult.Exception?.Message);
            return;
        }

        // Map claims from the software statement to client properties
        var claims = validationResult.ClaimsIdentity;
        var softwareName = claims.FindFirst("software_name")?.Value;
        if (!string.IsNullOrEmpty(softwareName))
        {
            context.Client.ClientName = softwareName;
        }

        // Continue with base validation
        await base.ValidateSoftwareStatementAsync(context);
    }

    private async Task<IEnumerable<SecurityKey>> GetTrustedSigningKeysAsync()
    {
        // Fetch the JWKS from the trusted issuer's discovery document
        var disco = await _httpClient.GetStringAsync(
            "https://trusted-issuer.example.com/.well-known/openid-configuration");
        
        // In production, cache the keys and use proper discovery client
        var configManager = new Microsoft.IdentityModel.Protocols.OpenIdConnect
            .OpenIdConnectConfigurationRetriever();
        
        // Simplified — in production use ConfigurationManager<OpenIdConnectConfiguration>
        var jwksUri = "https://trusted-issuer.example.com/.well-known/jwks";
        var jwksJson = await _httpClient.GetStringAsync(jwksUri);
        var jwks = new JsonWebKeySet(jwksJson);
        return jwks.GetSigningKeys();
    }
}
```

### Register the validator

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementDcrValidator>();
```

### Key points

1. **`ValidateSoftwareStatementAsync`** is overridden to intercept software statement processing.
2. If no software statement is provided, `context.SetError()` rejects the request.
3. The JWT is validated using `JsonWebTokenHandler` with `ValidIssuer` set to `"https://trusted-issuer.example.com"`.
4. After validation, claims are mapped from the software statement to the client: `software_name` is applied to `context.Client.ClientName`.
5. `base.ValidateSoftwareStatementAsync(context)` is called at the end to run any remaining built-in validation logic.
