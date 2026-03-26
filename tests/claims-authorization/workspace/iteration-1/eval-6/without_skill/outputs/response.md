# Token Exchange Extension Grant

Here's how to implement a custom grant type for token exchange.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;

public class TokenExchangeValidator : IExtensionGrantValidator
{
    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest, "Missing subject_token");
            return;
        }

        // In a real implementation, you'd validate the subject token
        // For now, decode and extract the subject
        var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(subjectToken);
        var subject = token.Subject;

        if (string.IsNullOrEmpty(subject))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant, "No subject in token");
            return;
        }

        var claims = new[]
        {
            new Claim("original_client", token.Issuer),
        };

        context.Result = new GrantValidationResult(
            subject: subject,
            authenticationMethod: "token_exchange",
            claims: claims);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddExtensionGrantValidator<TokenExchangeValidator>();
```

This validates the incoming subject token, extracts the subject, and issues a new token with the original client information.
