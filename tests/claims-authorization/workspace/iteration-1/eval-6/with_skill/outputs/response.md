# Token Exchange Extension Grant Validator

Here's how to implement an `IExtensionGrantValidator` for the token exchange grant type (`urn:ietf:params:oauth:grant-type:token-exchange`) that extracts the subject from the incoming token and emits custom claims like the original client ID.

## Extension Grant Validator

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Validation;
using IdentityModel;

public sealed class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public TokenExchangeGrantValidator(ITokenValidator tokenValidator)
    {
        _tokenValidator = tokenValidator;
    }

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Extract the subject_token from the request
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrWhiteSpace(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest,
                "subject_token is required");
            return;
        }

        // Validate the incoming access token
        var validationResult = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "subject_token validation failed");
            return;
        }

        // Extract the subject from the validated token
        var subjectId = validationResult.Claims
            .FirstOrDefault(c => c.Type == JwtClaimTypes.Subject)?.Value;

        if (subjectId is null)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "No subject claim in subject_token");
            return;
        }

        // Build custom claims for the exchanged token
        var customClaims = new[]
        {
            new Claim("exchange_source", "token-exchange"),
            new Claim("original_client", validationResult.Client?.ClientId ?? "unknown"),
        };

        // Return a successful result with the subject and custom claims
        // IProfileService.GetProfileDataAsync is called after this
        // and can augment claims further based on requested scopes
        context.Result = new GrantValidationResult(
            subject: subjectId,
            authenticationMethod: GrantType,
            claims: customClaims);
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

## How It Works

1. The client sends a token request with `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` and a `subject_token` parameter.
2. The validator extracts and validates the `subject_token` using `ITokenValidator`.
3. It extracts the subject and creates custom claims (like the original client ID).
4. `GrantValidationResult` is returned with the subject, grant type, and custom claims.
5. **After the validator returns**, `IProfileService.GetProfileDataAsync` is called and can add further claims based on the requested scopes. The custom claims from the validator are available in `context.Subject.Claims` during the profile service call.
