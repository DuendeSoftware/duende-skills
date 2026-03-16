# Implementing Token Exchange in IdentityServer

Here's how to implement the token exchange grant type using `IExtensionGrantValidator`.

## Implementation

```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class TokenExchangeValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public TokenExchangeValidator(ITokenValidator tokenValidator)
    {
        _tokenValidator = tokenValidator;
    }

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);
            return;
        }

        var result = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
        if (sub == null)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var claims = new[]
        {
            new Claim("original_client", result.Client?.ClientId ?? "unknown")
        };

        context.Result = new GrantValidationResult(sub, "token-exchange", claims);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddExtensionGrantValidator<TokenExchangeValidator>();
```

This will handle the token exchange flow and include the original client ID in the resulting token.
