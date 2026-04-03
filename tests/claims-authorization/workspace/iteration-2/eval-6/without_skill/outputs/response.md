# Token Exchange Extension Grant

To implement a token exchange grant type in IdentityServer, you need to create a custom grant validator.

## Implementation

```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class TokenExchangeValidator : IExtensionGrantValidator
{
    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest,
                "Missing subject_token");
            return;
        }

        // Validate the incoming token
        // In a real implementation, you'd validate the JWT
        var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
        var jwt = handler.ReadJwtToken(subjectToken);

        var subject = jwt.Subject;
        if (string.IsNullOrEmpty(subject))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "No subject in token");
            return;
        }

        // Create claims for the new token
        var claims = new List<Claim>
        {
            new Claim("original_client", jwt.Issuer),
        };

        context.Result = new GrantValidationResult(
            subject: subject,
            authenticationMethod: "token_exchange",
            claims: claims);
    }
}
```

## Registration

Register the validator in your IdentityServer configuration:

```csharp
builder.Services.AddIdentityServer()
    .AddExtensionGrantValidator<TokenExchangeValidator>();
```

## Client Configuration

The client needs to be configured to use this grant type:

```csharp
new Client
{
    ClientId = "exchange-client",
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" }
}
```

## Notes

- The `subject_token` parameter contains the token to exchange
- You should properly validate the incoming token using your token validation infrastructure
- The resulting token will contain the claims you specify in the `GrantValidationResult`
- Consider adding additional validation like checking token type, audience, etc.
