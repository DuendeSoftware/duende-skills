# Implementing Token Exchange (RFC 8693) for Delegation

Token exchange allows your `api_gateway` to exchange a user's access token for a new token to call downstream APIs, preserving the call chain via the `act` (actor) claim.

## Token Exchange Grant Validator

```csharp
using System.Text.Json;
using Duende.IdentityModel;
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _validator;

    public TokenExchangeGrantValidator(ITokenValidator validator)
    {
        _validator = validator;
    }

    public string GrantType => OidcConstants.GrantTypes.TokenExchange;

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        // Default to invalid
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var customResponse = new Dictionary<string, object>
        {
            { OidcConstants.TokenResponse.IssuedTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken }
        };

        // Extract the subject token from the request
        var subjectToken = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectToken);
        var subjectTokenType = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectTokenType);

        if (string.IsNullOrWhiteSpace(subjectToken))
            return;

        // Only accept access tokens as the subject token
        if (!string.Equals(subjectTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken))
            return;

        // Validate the incoming access token
        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
            return;

        // Extract claims from the validated token
        var sub = validationResult.Claims.First(c => c.Type == JwtClaimTypes.Subject).Value;
        var clientId = validationResult.Claims.First(c => c.Type == JwtClaimTypes.ClientId).Value;

        // Delegation: preserve the original client_id and add act claim
        context.Request.ClientId = clientId;

        // Build the act claim to show the call chain
        var actor = new { client_id = context.Request.Client.ClientId };
        var actClaim = new System.Security.Claims.Claim(
            JwtClaimTypes.Actor,
            JsonSerializer.Serialize(actor),
            Duende.IdentityServer.IdentityServerConstants.ClaimValueTypes.Json);

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: new[] { actClaim },
            customResponse: customResponse);
    }
}
```

## Updated Program.cs — Register Validator and Client

```csharp
using Duende.IdentityModel;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web_app",
            ClientName = "Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "api1" },
            AccessTokenLifetime = 3600
        },
        new Client
        {
            ClientId = "api_gateway",
            ClientName = "API Gateway",
            AllowedGrantTypes = { OidcConstants.GrantTypes.TokenExchange },
            ClientSecrets = { new Secret("gateway_secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        // ... other clients ...
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("api1_resource")
        {
            Scopes = { "api1" }
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
    {
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password"
        }
    });

// Register the token exchange grant validator
idsvrBuilder.AddExtensionGrantValidator<TokenExchangeGrantValidator>();

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## How Delegation Works

1. The front-end client (`web_app`) authenticates the user and gets an access token
2. `web_app` calls `api_gateway` with the access token
3. `api_gateway` exchanges the token at the token endpoint with `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
4. The validator validates the original token, extracts the `sub` and `client_id`
5. The new token has:
   - Same `sub` as the original user
   - Same `client_id` as the original front-end client
   - An `act` claim: `{"client_id": "api_gateway"}` showing who performed the exchange
6. The downstream API sees the full call chain: user → web_app → api_gateway
