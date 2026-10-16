## Validator (delegation)

```csharp
using System.Security.Claims;
using System.Text.Json;
using Duende.IdentityModel;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _validator;

    public TokenExchangeGrantValidator(ITokenValidator validator) => _validator = validator;

    public string GrantType => OidcConstants.GrantTypes.TokenExchange;

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Fail closed by default
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var customResponse = new Dictionary<string, object>
        {
            { OidcConstants.TokenResponse.IssuedTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken }
        };

        var subjectToken = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectToken);
        var subjectTokenType = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectTokenType);

        if (string.IsNullOrWhiteSpace(subjectToken)) return;
        if (!string.Equals(subjectTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken)) return;

        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError) return;

        var sub = validationResult.Claims.FirstOrDefault(c => c.Type == JwtClaimTypes.Subject)?.Value;
        var clientId = validationResult.Claims.FirstOrDefault(c => c.Type == JwtClaimTypes.ClientId)?.Value;
        if (sub == null || clientId == null) return;

        // Delegation: preserve the original client and record the actor (api_gateway)
        context.Request.ClientId = clientId;

        var actor = new { client_id = context.Request.Client.ClientId };
        var actClaim = new Claim(JwtClaimTypes.Actor,
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

Delegation vs impersonation: both keep the original `client_id`; delegation additionally carries an `act` claim (`{"client_id":"api_gateway"}`) so downstream APIs see the call chain. Impersonation omits `act`.

## Profile service so `act` is emitted

```csharp
public class ProfileService : DefaultProfileService
{
    public ProfileService(ILogger<DefaultProfileService> logger) : base(logger) { }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        await base.GetProfileDataAsync(context);

        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var act = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (act != null) context.IssuedClaims.Add(act);
        }
    }
}
```

(`GetAuthenticationMethod()` is in `Duende.IdentityServer.Extensions`.)

## Program.cs

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        // ... web_app, m2m_client, mobile_app ...
        new Client
        {
            ClientId = "api_gateway",
            ClientName = "API Gateway",
            AllowedGrantTypes = { OidcConstants.GrantTypes.TokenExchange },
            ClientSecrets = { new Secret("gateway_secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    })
    // ... existing scopes/resources/users ...
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>()
    .AddProfileService<ProfileService>();
```

The gateway must use `urn:ietf:params:oauth:grant-type:token-exchange` exactly. Request: `grant_type=urn:ietf:params:oauth:grant-type:token-exchange&subject_token=<access token>&subject_token_type=urn:ietf:params:oauth:token-type:access_token&scope=api1`.

Optionally filter sensitive params from logs: `options.Logging.TokenRequestSensitiveValuesFilter.Add("subject_token");`.
