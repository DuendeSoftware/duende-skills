# Token Exchange Extension Grant Validator

Here's how to implement `IExtensionGrantValidator` for the token exchange grant type (`urn:ietf:params:oauth:grant-type:token-exchange`) and emit custom claims like the original client ID.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public sealed class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly IUserRepository _users;
    private readonly ITokenValidator _tokenValidator;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public TokenExchangeGrantValidator(
        IUserRepository users,
        ITokenValidator tokenValidator)
    {
        _users = users;
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

        // Validate the incoming token
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
                TokenRequestErrors.InvalidGrant, "no subject claim");
            return;
        }

        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user is null || !user.IsEnabled)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant, "user not found or inactive");
            return;
        }

        // Build the validated identity with custom claims.
        // IProfileService.GetProfileDataAsync will be called subsequently
        // and can augment these claims further.
        var customClaims = new[]
        {
            new Claim("exchange_source", "token-exchange"),
            new Claim("original_client", validationResult.Client?.ClientId ?? "unknown"),
        };

        context.Result = new GrantValidationResult(
            subject: subjectId,
            authenticationMethod: GrantType,
            claims: customClaims);
    }
}
```

## Registration

Register the validator with `AddExtensionGrantValidator<T>()` on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

## How Claims Flow

The claims passed to `GrantValidationResult` become the subject principal. After the grant validator returns, **`IProfileService` is called** and can add further claims based on the requested scopes. The `customClaims` here augment the subject's base identity — they are available in `context.Subject.Claims` during the profile service call.

## Client Configuration

The client requesting this grant type must have it in `AllowedGrantTypes`:

```csharp
new Client
{
    ClientId = "token-exchange-client",
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" }
}
```
