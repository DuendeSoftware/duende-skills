# Implementing Token Exchange (RFC 8693) with Delegation

You need three things: a `TokenExchangeGrantValidator` implementing `IExtensionGrantValidator`, an `api_gateway` client configured for token exchange, and registration in the DI container.

## Token Exchange Grant Validator

```csharp
using System.Security.Claims;
using System.Text.Json;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Validation;
using Duende.IdentityModel;

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
        // Default to invalid request
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var customResponse = new Dictionary<string, object>
        {
            { OidcConstants.TokenResponse.IssuedTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken }
        };

        // Extract subject token from the request
        var subjectToken = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectToken);
        var subjectTokenType = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectTokenType);

        if (string.IsNullOrWhiteSpace(subjectToken)) return;
        if (!string.Equals(subjectTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken)) return;

        // Validate the incoming access token
        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError) return;

        // Extract claims from the original token
        var sub = validationResult.Claims.First(c => c.Type == JwtClaimTypes.Subject).Value;
        var clientId = validationResult.Claims.First(c => c.Type == JwtClaimTypes.ClientId).Value;

        // Delegation: set client_id to original and add act claim with requesting client
        context.Request.ClientId = clientId;

        var actor = new { client_id = context.Request.Client.ClientId };
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

## Updated Program.cs

Register the validator and add the `api_gateway` client:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityModel;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
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
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "mobile_app",
            ClientName = "Mobile Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RedirectUris = { "myapp://callback" },
            PostLogoutRedirectUris = { "myapp://signout" },
            AllowedScopes = { "openid", "profile", "api1" },
            RequirePkce = true
        },
        // New client for token exchange (delegation)
        new Client
        {
            ClientId = "api_gateway",
            ClientName = "API Gateway",
            AllowedGrantTypes = { OidcConstants.GrantTypes.TokenExchange },
            ClientSecrets = { new Secret("gateway_secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
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
    })
    .AddExtensionGrantValidator<TokenExchangeGrantValidator>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How It Works

1. **`IExtensionGrantValidator`** — The `TokenExchangeGrantValidator` implements this interface, which is Duende IdentityServer's mechanism for custom grant types.

2. **`GrantType => OidcConstants.GrantTypes.TokenExchange`** — Returns `"urn:ietf:params:oauth:grant-type:token-exchange"`, the standard RFC 8693 grant type.

3. **`ValidateAccessTokenAsync`** — Validates the incoming subject token using IdentityServer's built-in token validator.

4. **Delegation with `act` claim** — The `JwtClaimTypes.Actor` claim contains a JSON object with the requesting client's `client_id`. This preserves the full call chain so downstream APIs can see who made the original request and who is acting on their behalf.

5. **`api_gateway` client** — Configured with `OidcConstants.GrantTypes.TokenExchange` in `AllowedGrantTypes` to allow token exchange requests.
