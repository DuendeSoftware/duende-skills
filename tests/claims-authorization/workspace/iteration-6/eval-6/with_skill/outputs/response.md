# Token exchange extension grant

```csharp
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public sealed class TokenExchangeGrantValidator(
    IUserRepository users,
    ITokenValidator tokenValidator) : IExtensionGrantValidator
{
    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        if (string.IsNullOrWhiteSpace(subjectToken))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest, "subject_token is required");
            return;
        }

        var validation = await tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (validation.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant, "subject_token validation failed");
            return;
        }

        var subjectId = validation.Claims.FirstOrDefault(c => c.Type == JwtClaimTypes.Subject)?.Value;
        if (subjectId is null)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant, "no subject claim");
            return;
        }

        var user = await users.FindBySubjectIdAsync(subjectId);
        if (user is null || !user.IsEnabled)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant, "user not found or inactive");
            return;
        }

        // The original client id is the client_id claim of the subject token
        var originalClientId = validation.Claims
            .FirstOrDefault(c => c.Type == JwtClaimTypes.ClientId)?.Value ?? "unknown";

        var customClaims = new[]
        {
            new Claim("exchange_source", "token-exchange"),
            new Claim("original_client_id", originalClientId),
        };

        context.Result = new GrantValidationResult(
            subject: subjectId,
            authenticationMethod: GrantType,
            claims: customClaims);
    }
}
```

## Register
```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddProfileService<ApplicationProfileService>()
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

## Client
```csharp
new Client
{
    ClientId = "exchange.client",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    AllowedScopes = { "api1" }
}
```

## How the claims reach the token
- Claims passed to `GrantValidationResult` become part of the subject principal and are available as `context.Subject.Claims` when `IProfileService` runs afterwards.
- `IProfileService` is then called and can add more claims. Note the filtering: `AddRequestedClaims` keeps only declared claim types. To make the custom claims appear in the access token, either declare them on the scope (`new ApiScope("api1") { UserClaims = { "original_client_id", "exchange_source" } }`) and pass them through in the profile service:

```csharp
public override Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    // Pass through claims from the extension grant
    context.AddRequestedClaims(context.Subject.Claims.Where(c =>
        c.Type is "original_client_id" or "exchange_source"));
    return Task.CompletedTask;
}
```
or add them straight to `context.IssuedClaims` if they must always be emitted.

## Security notes
Verify the exchanging client is allowed to do the exchange, constrain the scopes/audience requested, reject disabled users, and always validate the subject token (signature, expiry, audience).
