# Implementing a token exchange extension grant

Duende IdentityServer lets you plug in custom grant types by implementing `IExtensionGrantValidator`. The token endpoint routes a request to your validator when the request's `grant_type` matches the validator's `GrantType`. For token exchange, that value is `urn:ietf:params:oauth:grant-type:token-exchange`.

## The extension grant validator

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using System.Security.Claims;
using System.Linq;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public TokenExchangeGrantValidator(ITokenValidator tokenValidator)
    {
        _tokenValidator = tokenValidator;
    }

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Read the incoming token from the request parameters
        var subjectToken = context.Request.Raw.Get("subject_token");
        var subjectTokenType = context.Request.Raw.Get("subject_token_type");

        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidRequest,
                "subject_token is missing");
            return;
        }

        // Validate the subject token
        var result = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "invalid subject_token");
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
        if (sub is null)
        {
            context.Result = new GrantValidationResult(
                TokenRequestErrors.InvalidGrant,
                "subject_token has no sub");
            return;
        }

        // Emit custom claims, e.g. the original client id
        var originalClientId = result.Client?.ClientId ?? "unknown";
        var claims = new[]
        {
            new Claim("original_client_id", originalClientId),
            new Claim("act_source", "token-exchange"),
        };

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: claims);
    }
}
```

## Register the validator

```csharp
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

## Allow the grant on the client

The client that performs the exchange must permit the custom grant type:

```csharp
new Client
{
    ClientId = "exchange.client",
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    AllowedScopes = { "api1" }
}
```

## Notes

- The custom `claims` you hand to `GrantValidationResult` become part of the resulting principal, so `original_client_id` will be available for the issued token.
- You should validate `subject_token_type` (and, per RFC 8693, potentially `actor_token`, `audience`, `resource`, `scope`) to fully conform to the token exchange spec — the example keeps it minimal.
- Return the appropriate `TokenRequestErrors` on failures so the client receives a proper OAuth error response.
