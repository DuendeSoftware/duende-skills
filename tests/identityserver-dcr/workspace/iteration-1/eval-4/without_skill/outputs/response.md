# Software Statement Validation in DCR

Software statements are signed JWTs that contain pre-approved metadata about a client application. Here's how to implement software statement validation in your DCR flow.

## Custom Validator

```csharp
using Microsoft.IdentityModel.Tokens;
using Microsoft.IdentityModel.JsonWebTokens;
using Duende.IdentityServer.Configuration;

public class SoftwareStatementValidator : DynamicClientRegistrationValidator
{
    private readonly HttpClient _httpClient;

    public SoftwareStatementValidator(IHttpClientFactory httpClientFactory)
    {
        _httpClient = httpClientFactory.CreateClient();
    }

    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;

        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("Software statement is required");
            return;
        }

        // Validate the JWT
        var handler = new JsonWebTokenHandler();
        
        // Fetch JWKS from trusted issuer
        var jwksResponse = await _httpClient.GetStringAsync(
            "https://trusted-issuer.example.com/.well-known/openid-configuration/jwks");
        var jwks = new JsonWebKeySet(jwksResponse);

        var result = await handler.ValidateTokenAsync(softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                IssuerSigningKeys = jwks.Keys,
                ValidateLifetime = true,
                ValidateAudience = false
            });

        if (!result.IsValid)
        {
            context.SetError("Invalid software statement");
            return;
        }

        // Map software_name claim to client
        var softwareName = result.ClaimsIdentity.FindFirst("software_name")?.Value;
        if (!string.IsNullOrEmpty(softwareName))
        {
            context.Client.ClientName = softwareName;
        }

        await base.ValidateSoftwareStatementAsync(context);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementValidator>();
```

## How It Works

1. The validator checks that a software statement JWT is present in the request
2. It validates the JWT against the trusted issuer's signing keys
3. If validation fails, the registration is rejected
4. On success, claims from the software statement (like `software_name`) are mapped to the client being registered
5. The base validation continues for remaining checks
