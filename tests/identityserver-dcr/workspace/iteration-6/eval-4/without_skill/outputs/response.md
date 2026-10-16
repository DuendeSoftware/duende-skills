# Software statement validation in DCR

Override the validator's software-statement step: reject if absent, verify signature/issuer/lifetime, apply `software_name`.

```csharp
public class SoftwareStatementValidator : DynamicClientRegistrationValidator
{
    private readonly IConfigurationManager<OpenIdConnectConfiguration> _config;

    public SoftwareStatementValidator(/* base deps */) : base(/* ... */)
    {
        _config = new ConfigurationManager<OpenIdConnectConfiguration>(
            "https://trusted-issuer.example.com/.well-known/openid-configuration",
            new OpenIdConnectConfigurationRetriever());
    }

    protected override async Task<(Client, DynamicClientRegistrationError?)> ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var statement = context.Request.SoftwareStatement;
        if (string.IsNullOrEmpty(statement))
            return (context.Client, new DynamicClientRegistrationError(
                "invalid_software_statement", "A software statement is required"));

        var cfg = await _config.GetConfigurationAsync();
        var result = await new JsonWebTokenHandler().ValidateTokenAsync(statement, new TokenValidationParameters
        {
            ValidIssuer = "https://trusted-issuer.example.com",
            ValidateAudience = false,
            IssuerSigningKeys = cfg.SigningKeys,
            ValidateLifetime = true,
            RequireSignedTokens = true,
            ValidAlgorithms = new[] { "RS256", "ES256" }
        });
        if (!result.IsValid)
            return (context.Client, new DynamicClientRegistrationError(
                "invalid_software_statement", "Software statement validation failed"));

        var jwt = (JsonWebToken)result.SecurityToken;
        if (jwt.TryGetPayloadValue<string>("software_name", out var name))
            context.Client.ClientName = name;

        return (context.Client, null);
    }
}
```
```csharp
builder.Services.AddTransient<IDynamicClientRegistrationValidator, SoftwareStatementValidator>();
```
Never trust claims from an unverified statement, pin algorithms, and fetch issuer keys from a trusted metadata endpoint. Method names may differ slightly by version.
