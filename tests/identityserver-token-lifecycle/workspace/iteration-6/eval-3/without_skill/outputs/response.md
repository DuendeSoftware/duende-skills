## Token exchange (RFC 8693) with delegation

### Validator

```csharp
using System.Security.Claims;
using System.Text.Json;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _tokenValidator;

    public TokenExchangeGrantValidator(ITokenValidator tokenValidator)
        => _tokenValidator = tokenValidator;

    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var raw = context.Request.Raw;
        var subjectToken = raw.Get("subject_token");
        var subjectTokenType = raw.Get("subject_token_type");

        if (string.IsNullOrWhiteSpace(subjectToken) ||
            subjectTokenType != "urn:ietf:params:oauth:token-type:access_token")
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest,
                "subject_token and subject_token_type (access_token) are required");
            return;
        }

        var result = await _tokenValidator.ValidateAccessTokenAsync(subjectToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant,
                "invalid subject_token");
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
        if (sub == null)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant,
                "subject_token has no subject (client tokens cannot be exchanged)");
            return;
        }

        // Delegation: act claim identifies the actor (api_gateway); nest any prior act.
        var actor = new Dictionary<string, object> { ["sub"] = context.Request.Client.ClientId };
        var existingAct = result.Claims.FirstOrDefault(c => c.Type == "act")?.Value;
        if (existingAct != null)
            actor["act"] = JsonSerializer.Deserialize<JsonElement>(existingAct);

        var claims = new List<Claim>
        {
            new("act", JsonSerializer.Serialize(actor), IdentityServerConstants.ClaimValueTypes.Json)
        };

        context.Result = new GrantValidationResult(sub, GrantType, claims);
    }
}
```

Because `sub` is kept and `act` added, this is delegation (the token is for the user, acted on by api_gateway). Impersonation would omit `act`.

### Program.cs changes

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients ...
        new Client
        {
            ClientId = "api_gateway",
            ClientName = "API Gateway",
            AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
            ClientSecrets = { new Secret("gateway_secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    })
    // ... existing config ...
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();
```

For the `act` claim to appear in the issued token, a custom `IProfileService` must pass it through, because `act` is not a requested user claim (see below):

```csharp
public class ActClaimProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var act = context.Subject.FindFirst("act");
        if (act != null) context.IssuedClaims.Add(act);
        return Task.CompletedTask;
    }
    public Task IsActiveAsync(IsActiveContext context) { context.IsActive = true; return Task.CompletedTask; }
}
// .AddProfileService<ActClaimProfileService>();
```

Request example from api_gateway: `grant_type=urn:ietf:params:oauth:grant-type:token-exchange&subject_token=<jwt>&subject_token_type=urn:ietf:params:oauth:token-type:access_token&scope=api1`.
