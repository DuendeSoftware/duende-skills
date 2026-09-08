# Validating DCR software statements

A software statement is a signed JWT supplied in the `software_statement` field of a registration request. To honor it you need to: verify its signature against the trusted issuer, reject requests that don't include one, and project selected claims (like `software_name`) onto the client being registered.

Hook into Duende's DCR validation by subclassing the registration validator and adding the software-statement logic:

```csharp
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

public class SoftwareStatementValidator : DynamicClientRegistrationValidator
{
    private const string TrustedIssuer = "https://trusted-issuer.example.com";

    public override async Task<DynamicClientRegistrationValidationResult> ValidateAsync(
        DynamicClientRegistrationContext context)
    {
        var statement = context.Request.SoftwareStatement;

        // Reject when no software statement is provided
        if (string.IsNullOrWhiteSpace(statement))
        {
            return new DynamicClientRegistrationValidationError(
                "invalid_software_statement",
                "A software statement is required for registration");
        }

        // Resolve the trusted issuer's signing keys from its metadata
        var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
            $"{TrustedIssuer}/.well-known/openid-configuration",
            new OpenIdConnectConfigurationRetriever());
        var config = await configManager.GetConfigurationAsync();

        var handler = new JsonWebTokenHandler();
        var result = await handler.ValidateTokenAsync(statement, new TokenValidationParameters
        {
            ValidIssuer = TrustedIssuer,
            ValidateIssuer = true,
            IssuerSigningKeys = config.SigningKeys,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidateAudience = false
        });

        if (!result.IsValid)
        {
            return new DynamicClientRegistrationValidationError(
                "invalid_software_statement",
                "The software statement could not be validated");
        }

        // Run the standard validation, then apply claims from the statement
        var baseResult = await base.ValidateAsync(context);

        if (baseResult is DynamicClientRegistrationValidatedRequest validated)
        {
            var softwareName = result.ClaimsIdentity.FindFirst("software_name")?.Value;
            if (!string.IsNullOrEmpty(softwareName))
            {
                validated.Client.ClientName = softwareName;
            }
        }

        return baseResult;
    }
}
```

Register it:

```csharp
builder.Services.AddDynamicClientRegistrationValidator<SoftwareStatementValidator>();
```

## Notes

- **Trust anchor**: keys come from the trusted issuer's published JWKS (`/.well-known/openid-configuration`), and `ValidIssuer` is pinned to `https://trusted-issuer.example.com`. Do not trust keys embedded in the token itself.
- **Reject-by-default**: an empty statement returns a validation error, so registration fails.
- **Claim mapping**: `software_name` from the validated token is written to the client's `ClientName`. Map any other approved metadata (redirect URIs, scopes) the same way.
- Adjust the result/error types to your installed Duende version — the exact validator method and return types vary between releases.
