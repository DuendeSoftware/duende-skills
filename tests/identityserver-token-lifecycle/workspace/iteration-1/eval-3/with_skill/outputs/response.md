# Implementing Token Exchange (RFC 8693) with Delegation

Here's how to implement a token exchange grant validator for delegation, including the `act` claim for call chain tracking, and the `api_gateway` client configuration.

## TokenExchangeGrantValidator

```csharp
using System.Security.Claims;
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
        // Default to error
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var customResponse = new Dictionary<string, object>
        {
            { OidcConstants.TokenResponse.IssuedTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken }
        };

        // Get the subject token from the request
        var subjectToken = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectToken);
        var subjectTokenType = context.Request.Raw.Get(OidcConstants.TokenRequest.SubjectTokenType);

        if (string.IsNullOrWhiteSpace(subjectToken))
            return;

        // Only accept access tokens as subject tokens
        if (!string.Equals(subjectTokenType, OidcConstants.TokenTypeIdentifiers.AccessToken))
            return;

        // Validate the subject token
        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
            return;

        // Extract subject and client_id from the original token
        var sub = validationResult.Claims.First(c => c.Type == JwtClaimTypes.Subject).Value;
        var clientId = validationResult.Claims.First(c => c.Type == JwtClaimTypes.ClientId).Value;

        // For delegation: set client_id to the original front-end client
        context.Request.ClientId = clientId;

        // Create the 'act' claim to show the call chain (delegation pattern)
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
        // New: API Gateway client for token exchange
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
    });

// Register the token exchange grant validator
idsvrBuilder.AddExtensionGrantValidator<TokenExchangeGrantValidator>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How It Works

### Delegation vs Impersonation

This implementation uses **delegation** (not impersonation). The difference:

- **Impersonation**: The new token looks exactly like the original — API2 cannot tell that API1 is making the call on behalf of the user. No `act` claim.
- **Delegation**: The new token contains an `act` (actor) claim that records the call chain. API2 can see that `api_gateway` is making the call on behalf of the original user/client.

### The `act` Claim

The `act` claim is a JSON object embedded in the access token:

```json
{
  "sub": "1",
  "client_id": "web_app",
  "act": {
    "client_id": "api_gateway"
  }
}
```

This tells the downstream API: "The user `1` authorized `web_app`, which delegated to `api_gateway`."

### Token Exchange Flow

1. User authenticates to `web_app` and gets an access token
2. `web_app` calls `api_gateway` with the access token
3. `api_gateway` exchanges the user's token at the token endpoint using `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
4. IdentityServer validates the original token, creates a new token with the `act` claim showing delegation
5. `api_gateway` uses the new token to call downstream APIs

### Important Notes

- The `api_gateway` client must have `AllowedGrantTypes` set to include the token exchange grant type (`urn:ietf:params:oauth:grant-type:token-exchange`), accessed via `OidcConstants.GrantTypes.TokenExchange`.
- To emit the `act` claim in the final token, you'll also need a profile service that handles token exchange flows and forwards the `act` claim.
