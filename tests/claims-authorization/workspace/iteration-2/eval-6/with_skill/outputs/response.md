# Token Exchange Extension Grant with Custom Claims

Here's how to implement a token exchange extension grant (`urn:ietf:params:oauth:grant-type:token-exchange`) in Duende IdentityServer that emits custom claims like the original client ID.

## IExtensionGrantValidator Implementation

```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;
using Duende.IdentityModel;
using System.Security.Claims;

public sealed class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;
    private readonly IUserRepository _users;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public TokenExchangeGrantValidator(
        ITokenValidator tokenValidator,
        IUserRepository users)
    {
        _tokenValidator = tokenValidator;
        _users = users;
    }

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Extract and validate the subject_token
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrWhiteSpace(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest,
                "subject_token is required");
            return;
        }

        var validationResult = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "subject_token validation failed");
            return;
        }

        var subjectId = validationResult.Claims
            .FirstOrDefault(c => c.Type == JwtClaimTypes.Subject)?.Value;

        if (subjectId is null)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "no subject claim in token");
            return;
        }

        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user is null || !user.IsEnabled)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "user not found or inactive");
            return;
        }

        // Build custom claims — including the original client ID
        var customClaims = new[]
        {
            new Claim("exchange_source", "token-exchange"),
            new Claim("original_client", validationResult.Client?.ClientId ?? "unknown"),
        };

        // Return a successful result with subject and custom claims
        // IProfileService.GetProfileDataAsync is called after this and can augment claims further
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
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

## How Claims Flow

1. `IExtensionGrantValidator.ValidateAsync` sets `context.Result` with a subject and custom claims
2. These claims become the subject principal
3. `IProfileService.GetProfileDataAsync` is then called — it can augment claims further based on the requested scopes
4. The final token contains claims from both the grant validator and the profile service

The `customClaims` passed to `GrantValidationResult` are available in `context.Subject.Claims` during the profile service call, so the profile service can see them and make decisions based on them.
