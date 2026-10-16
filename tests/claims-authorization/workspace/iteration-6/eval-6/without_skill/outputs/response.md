# Token exchange extension grant

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class TokenExchangeGrantValidator(ITokenValidator tokenValidator) : IExtensionGrantValidator
{
    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        var subjectTokenType = context.Request.Raw.Get("subject_token_type");

        if (string.IsNullOrWhiteSpace(subjectToken) ||
            subjectTokenType != "urn:ietf:params:oauth:token-type:access_token")
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);
            return;
        }

        var result = await tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
        var originalClient = result.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;
        if (sub is null)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: new[] { new Claim("original_client_id", originalClient ?? "") });
    }
}
```

## Register
```csharp
builder.Services.AddIdentityServer()
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

## Client
```csharp
new Client
{
    ClientId = "exchange.client",
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" }
}
```

## Claims in the token
Claims passed to `GrantValidationResult` are included in the access token, but only if accepted by the client's `Claims`... Actually these custom claims are added directly. To be safe, also make your profile service pass `context.Subject.Claims` through to `IssuedClaims`, and declare `original_client_id` in `ApiScope.UserClaims`. Note: client-level `Client.Claims` get `client_` prefix, so a separate claim name is cleaner. For a delegation pattern, you may also emit the RFC 8693 `act` claim as JSON.

Security: validate that the calling client is permitted to exchange, restrict audiences/scopes, and don't allow privilege escalation.
