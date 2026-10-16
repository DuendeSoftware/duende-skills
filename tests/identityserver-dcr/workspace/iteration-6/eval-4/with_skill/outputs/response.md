# Software statement validation in DCR

Override `ValidateSoftwareStatementAsync` in a `DynamicClientRegistrationValidator`. Reject requests without a statement, validate the signature, issuer and lifetime against trusted keys, then apply `software_name` to the client.

```csharp
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Duende.IdentityServer.Configuration;

public class SoftwareStatementDcrValidator : DynamicClientRegistrationValidator
{
    private readonly ITrustedKeyProvider _keys;   // your own: loads trusted-issuer.example.com's signing keys

    public SoftwareStatementDcrValidator(ITrustedKeyProvider keys) => _keys = keys;

    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var softwareStatement = context.Request.SoftwareStatement;
        if (string.IsNullOrEmpty(softwareStatement))
        {
            context.SetError("Software statement required");
            return;
        }

        var handler = new JsonWebTokenHandler();
        var result = await handler.ValidateTokenAsync(
            softwareStatement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                IssuerSigningKeys = await _keys.GetKeysAsync(),
                ValidateIssuer = true,
                ValidateAudience = false,
                ValidateLifetime = true,
                RequireSignedTokens = true
            });

        if (!result.IsValid)
        {
            context.SetError("Invalid software statement");
            return;
        }

        // Apply claims from the statement to the client
        context.Client.ClientName = result.ClaimsIdentity.FindFirst("software_name")?.Value;

        await base.ValidateSoftwareStatementAsync(context);
    }
}
```

Register:
```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddDynamicClientRegistrationValidator<SoftwareStatementDcrValidator>();
builder.Services.AddSingleton<ITrustedKeyProvider, TrustedKeyProvider>();
```

Security notes:
- Software statements must be validated against a **trusted signing key**; never accept statements from unknown issuers. Load the keys from the issuer's JWKS (cached) or pin them in configuration, not from the token itself.
- Validate issuer, signature and lifetime (as above); you may also pin allowed algorithms.
- If `software_name` is missing, decide whether that is an error or just leaves the name unset.
- Still protect `/connect/dcr` with an authorization policy; the software statement supplements caller authentication.
