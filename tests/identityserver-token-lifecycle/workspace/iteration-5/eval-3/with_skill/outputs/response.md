# Token Exchange (RFC 8693) with Delegation

Token exchange is implemented in IdentityServer as an **extension grant** — a class implementing `IExtensionGrantValidator` whose `GrantType` is the token-exchange URN. For **delegation** (as opposed to impersonation) the new token keeps the original subject/client but adds an `act` (actor) claim recording who is making the call, so the downstream API can see the full call chain.

## The grant validator

```csharp
using System.Text.Json;
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _validator;

    public TokenExchangeGrantValidator(ITokenValidator validator)
    {
        _validator = validator;
    }

    // urn:ietf:params:oauth:grant-type:token-exchange
    public string GrantType => OidcConstants.GrantTypes.TokenExchange;

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Fail closed by default
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var customResponse = new Dictionary<string, object>
        {
            { OidcConstants.TokenResponse.IssuedTokenType,
              OidcConstants.TokenTypeIdentifiers.AccessToken }
        };

        var subjectToken = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectToken);
        var subjectTokenType = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectTokenType);

        if (string.IsNullOrWhiteSpace(subjectToken)) return;
        if (!string.Equals(subjectTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken)) return;

        // Validate the incoming user access token
        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError) return;

        var sub = validationResult.Claims.First(c => c.Type == JwtClaimTypes.Subject).Value;
        var clientId = validationResult.Claims.First(c => c.Type == JwtClaimTypes.ClientId).Value;

        // DELEGATION: keep the original subject/client, but record the caller in an act claim
        var actor = new { client_id = context.Request.Client.ClientId }; // the api_gateway client
        var actClaim = new Claim(
            JwtClaimTypes.Actor,
            JsonSerializer.Serialize(actor),
            IdentityServerConstants.ClaimValueTypes.Json);

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: new[] { actClaim },
            customResponse: customResponse);
    }
}
```

Key points:

- `GrantType` returns `OidcConstants.GrantTypes.TokenExchange` (`urn:ietf:params:oauth:grant-type:token-exchange`).
- The subject token is validated with `ITokenValidator.ValidateAccessTokenAsync`.
- The `act` claim is built with `JwtClaimTypes.Actor`, JSON-typed, and carries the **calling client's** `client_id` (`context.Request.Client.ClientId`). This is what distinguishes delegation from impersonation — impersonation would omit `act`.

## Register the validator and create the `api_gateway` client

```csharp
// Program.cs — on the IdentityServer builder
idsvrBuilder.AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

```csharp
new Client
{
    ClientId = "api_gateway",
    ClientName = "API Gateway",
    ClientSecrets = { new Secret("gateway_secret".Sha256()) },
    AllowedGrantTypes = { OidcConstants.GrantTypes.TokenExchange },
    AllowedScopes = { "api1" }
}
```

## Emitting the `act` claim

The `act` claim is only carried through to the issued token if your profile service forwards it. For token-exchange authentication, find and add the actor claim in `GetProfileDataAsync` (see the profile-service customization guidance). Without that, the delegation chain won't appear in the final access token.
