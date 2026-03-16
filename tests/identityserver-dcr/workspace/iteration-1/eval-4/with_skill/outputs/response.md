# Software Statement Validation in DCR

Software statements are signed JWTs containing pre-approved client metadata. You need to override `ValidateSoftwareStatementAsync` in a `DynamicClientRegistrationValidator` subclass to validate the JWT against the trusted issuer and map claims to the client.

## Custom Validator

```csharp
using System.IdentityModel.Tokens.Jwt;
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Configuration.Models;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    private const string TrustedIssuer = "https://trusted-issuer.example.com";

    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;

        // Reject requests without a software statement
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("A software statement is required for client registration.");
            return;
        }

        // Validate the software statement JWT
        var handler = new JsonWebTokenHandler();

        // Retrieve signing keys from the trusted issuer's JWKS endpoint
        var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
            $"{TrustedIssuer}/.well-known/openid-configuration",
            new OpenIdConnectConfigurationRetriever());
        var config = await configManager.GetConfigurationAsync();

        var validationResult = await handler.ValidateTokenAsync(
            softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = TrustedIssuer,
                IssuerSigningKeys = config.SigningKeys,
                ValidateLifetime = true,
                ValidateAudience = false
            });

        if (!validationResult.IsValid)
        {
            context.SetError($"Invalid software statement: {validationResult.Exception?.Message}");
            return;
        }

        // Map claims from the software statement to the client
        var claims = validationResult.ClaimsIdentity;

        var softwareName = claims.FindFirst("software_name")?.Value;
        if (!string.IsNullOrEmpty(softwareName))
        {
            context.Client.ClientName = softwareName;
        }

        var softwareId = claims.FindFirst("software_id")?.Value;
        if (!string.IsNullOrEmpty(softwareId))
        {
            context.Client.Properties["software_id"] = softwareId;
        }

        // Continue with the base validation
        await base.ValidateSoftwareStatementAsync(context);
    }
}
```

## Registration in Program.cs

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementDcrValidator>();
```

## How It Works

1. **`ValidateSoftwareStatementAsync`** — This override is called during DCR processing when a software statement is present (or expected).

2. **Reject missing statements** — If `context.Request.SoftwareStatement` is null or empty, we call `context.SetError()` to reject the registration request.

3. **JWT validation** — We use `JsonWebTokenHandler.ValidateTokenAsync()` to validate the software statement against the trusted issuer (`https://trusted-issuer.example.com`). The `ValidIssuer` is set to the trusted issuer URL, and signing keys are fetched from the issuer's OIDC discovery endpoint.

4. **Claim mapping** — After successful validation, we extract the `software_name` claim from the software statement and map it to `context.Client.ClientName`. Additional claims like `software_id` can also be mapped.

5. **Base call** — We call `await base.ValidateSoftwareStatementAsync(context)` at the end to allow the default pipeline to continue.

> **Security Note**: Always validate software statements against known, trusted signing keys. Never accept software statements from unknown issuers.
