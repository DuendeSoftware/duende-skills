# Token exchange extension grant with custom claims

Custom OAuth grant types in Duende IdentityServer are implemented via `IExtensionGrantValidator`. The token endpoint dispatches to your validator based on its `GrantType`. For RFC 8693 token exchange, that's `urn:ietf:params:oauth:grant-type:token-exchange`. In `ValidateAsync` you pull the `subject_token` off the raw request, validate it, extract the subject, and return a `GrantValidationResult` carrying your custom claims.

## The validator

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using Duende.IdentityModel; // JwtClaimTypes, TokenRequestErrors
using System.Security.Claims;

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
        // 1. Pull the subject_token from the raw token request.
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrWhiteSpace(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest, "subject_token is required");
            return;
        }

        // 2. Validate the incoming access token.
        var validationResult = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant, "subject_token validation failed");
            return;
        }

        // 3. Extract the subject from the validated token.
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

        // 4. Emit custom claims — e.g. the original client id that requested the exchange.
        var customClaims = new[]
        {
            new Claim("exchange_source", "token-exchange"),
            new Claim("original_client", validationResult.Client?.ClientId ?? "unknown"),
        };

        // 5. Success: the subject + custom claims become the validated identity.
        context.Result = new GrantValidationResult(
            subject: subjectId,
            authenticationMethod: GrantType,
            claims: customClaims);
    }
}
```

## Register it

```csharp
// Program.cs
builder.Services.AddScoped<IUserRepository, UserRepository>();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

Also make sure the client is allowed to use the grant type:

```csharp
new Client
{
    ClientId = "exchange.client",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    AllowedScopes = { "api1" }
}
```

## How claims flow afterward

The `customClaims` you pass to `GrantValidationResult` become the base identity for the issued token (they're available as `context.Subject.Claims`). Importantly, **`IProfileService.GetProfileDataAsync` is called after the grant validator**, so it can augment or filter these claims further based on the requested scopes (via `AddRequestedClaims`). That means you can keep the validator focused on the exchange logic and mandatory correlation claims like `original_client`, and let your profile service add the rest of the user's scope-driven claims on top.
