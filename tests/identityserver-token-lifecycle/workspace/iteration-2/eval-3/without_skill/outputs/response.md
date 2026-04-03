# Implementing Token Exchange for Delegation

To implement RFC 8693 token exchange with delegation, you'll need a custom grant type validator and a new client.

## Custom Grant Validator

```csharp
using Microsoft.AspNetCore.Authentication;
using System.Security.Claims;

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
        var originalClient = result.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;

        // For delegation, include an "act" claim with the calling client
        var actorClaim = new Claim("act", 
            $"{{\"client_id\":\"{context.Request.Client.ClientId}\"}}", 
            "json");

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: "token_exchange",
            claims: new[] { actorClaim });
    }
}
```

## Client Configuration

```csharp
new Client
{
    ClientId = "api_gateway",
    ClientName = "API Gateway",
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    ClientSecrets = { new Secret("gateway_secret".Sha256()) },
    AllowedScopes = { "api1" }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    // ... existing config
    .AddExtensionGrantValidator<TokenExchangeValidator>();
```

## How It Works

1. The API gateway receives a user's access token
2. It calls the token endpoint with the token exchange grant type, passing the user's token as the `subject_token`
3. The validator validates the original token, extracts the user info
4. It creates a new token with an `act` claim showing the delegation chain
5. The downstream API can see both the original user and the acting client
