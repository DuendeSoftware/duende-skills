# Software Statement Validation

```csharp
public class SoftwareStatementValidator : DynamicClientRegistrationValidator
{
    protected override async Task ValidateSoftwareStatementAsync(
        DynamicClientRegistrationContext context)
    {
        var statement = context.Request.SoftwareStatement;
        if (string.IsNullOrEmpty(statement))
        {
            context.SetError("Software statement is required");
            return;
        }

        var handler = new JsonWebTokenHandler();
        var result = await handler.ValidateTokenAsync(statement,
            new TokenValidationParameters
            {
                ValidIssuer = "https://trusted-issuer.example.com",
                IssuerSigningKeys = await LoadKeysAsync(),
                ValidateLifetime = true
            });

        if (!result.IsValid)
        {
            context.SetError("Invalid software statement");
            return;
        }

        context.Client.ClientName = result.ClaimsIdentity.FindFirst("software_name")?.Value;

        await base.ValidateSoftwareStatementAsync(context);
    }
}
```

This validates the software statement JWT, rejects missing or invalid statements, and maps the software_name claim.
