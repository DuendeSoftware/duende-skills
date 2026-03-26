# Implementing Token Exchange for API Gateway

To implement token exchange (RFC 8693), you need a custom grant validator and a client configured to use it.

## Custom Grant Validator

```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;

public class TokenExchangeValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public TokenExchangeValidator(ITokenValidator tokenValidator)
    {
        _tokenValidator = tokenValidator;
    }

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw["subject_token"];
        var subjectTokenType = context.Request.Raw["subject_token_type"];

        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);
            return;
        }

        // Validate the incoming token
        var result = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;

        // Issue a new token for the subject
        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: "token_exchange");
    }
}
```

## Client Configuration

```csharp
new Client
{
    ClientId = "api_gateway",
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    ClientSecrets = { new Secret("gateway_secret".Sha256()) },
    AllowedScopes = { "api1" }
}
```

Register the validator:

```csharp
idsvrBuilder.AddExtensionGrantValidator<TokenExchangeValidator>();
```

The API gateway exchanges the user's access token for a new one scoped to the downstream API.
