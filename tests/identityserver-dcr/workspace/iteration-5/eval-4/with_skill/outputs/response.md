# Validating software statements in DCR

Software statements are signed JWTs carrying pre-approved client metadata. To validate them, override `ValidateSoftwareStatementAsync` in a `DynamicClientRegistrationValidator` subclass. The rules you asked for:

- Reject the request if **no** software statement is present.
- Validate the JWT against the trusted issuer `https://trusted-issuer.example.com`.
- Copy the `software_name` claim onto the client.
- Call the base implementation at the end of successful validation.

```csharp
using System.Text.Json;
using Duende.IdentityServer.Configuration.Validation.DynamicClientRegistration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;

        // 1. Reject requests without a software statement
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("A software statement is required");
            return;
        }

        // 2. Validate the signed JWT against the trusted issuer
        var handler = new JsonWebTokenHandler();
        var validationResult = await handler.ValidateTokenAsync(
            softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                ValidateIssuer = true,
                IssuerSigningKeys = await GetTrustedSigningKeysAsync(),
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true,
                // Software statements have no specific audience requirement here
                ValidateAudience = false
            });

        if (!validationResult.IsValid)
        {
            context.SetError("Invalid software statement");
            return;
        }

        // 3. Map claims from the statement onto the client
        var claims = validationResult.ClaimsIdentity;
        var softwareName = claims.FindFirst("software_name")?.Value;
        if (!string.IsNullOrEmpty(softwareName))
        {
            context.Client.ClientName = softwareName;
        }

        // 4. Defer to the base implementation on success
        await base.ValidateSoftwareStatementAsync(context);
    }

    private async Task<IEnumerable<SecurityKey>> GetTrustedSigningKeysAsync()
    {
        // Load the trusted issuer's public signing keys, e.g. from its JWKS endpoint:
        // var configManager = new ConfigurationManager<OpenIdConnectConfiguration>(
        //     "https://trusted-issuer.example.com/.well-known/openid-configuration",
        //     new OpenIdConnectConfigurationRetriever());
        // var config = await configManager.GetConfigurationAsync();
        // return config.SigningKeys;
        return await LoadKeysFromTrustedIssuerAsync();
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementDcrValidator>();
```

## Key points

- **Missing statement** → `context.SetError(...)` and early `return`, which rejects the registration.
- **Signature/issuer validation** — `JsonWebTokenHandler.ValidateTokenAsync` with `ValidIssuer = "https://trusted-issuer.example.com"` and `IssuerSigningKeys` from that issuer. Never accept a statement signed by an unknown issuer — resolve keys from the trusted issuer's JWKS, not from the token itself.
- **Claim mapping** — the `software_name` claim is copied to `context.Client.ClientName`. You can map additional claims (redirect URIs, logo URI, etc.) the same way.
- **`base.ValidateSoftwareStatementAsync(context)`** is awaited at the end so IdentityServer's default handling still runs after your checks succeed.
