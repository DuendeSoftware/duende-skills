# Implementing RFC 8693 Token Exchange in IdentityServer

Duende IdentityServer doesn't ship a built-in token-exchange grant, so you implement it as an extension grant by writing a class that implements `IExtensionGrantValidator`. For delegation, we keep the original user as the subject and add an `act` claim identifying the calling service, so downstream APIs can see the call chain.

## The extension grant validator

```csharp
using System.Text.Json;
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public TokenExchangeGrantValidator(ITokenValidator tokenValidator)
    {
        _tokenValidator = tokenValidator;
    }

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var subjectToken = context.Request.Raw.Get("subject_token");
        var subjectTokenType = context.Request.Raw.Get("subject_token_type");

        if (string.IsNullOrEmpty(subjectToken))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);
            return;
        }

        // Validate the incoming access token
        var result = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var sub = result.Claims.First(c => c.Type == "sub").Value;

        // Delegation: add an act claim naming the calling client
        var actor = new { client_id = context.Request.Client.ClientId };
        var actClaim = new Claim(
            JwtClaimTypes.Actor,
            JsonSerializer.Serialize(actor),
            "json");

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: new[] { actClaim });
    }
}
```

## Register it and add the client

```csharp
builder.Services.AddIdentityServer()
    // ... existing config ...
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

```csharp
new Client
{
    ClientId = "api_gateway",
    ClientName = "API Gateway",
    ClientSecrets = { new Secret("gateway_secret".Sha256()) },
    AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
    AllowedScopes = { "api1" }
}
```

## Notes

- The `act` claim differentiates **delegation** from **impersonation** — in impersonation you'd simply reissue the token as the original client with no `act` claim, whereas here we record `api_gateway` as the actor.
- To actually surface the `act` claim in the emitted token you may need a custom `IProfileService` that passes it through for token-exchange requests.
