# Implementing Token Exchange for the API Gateway

Token exchange (RFC 8693) allows one service to exchange an access token for another. Here's how to implement this for delegation with an `act` claim.

## Custom Grant Validator

```csharp
using System.Security.Claims;
using System.Text.Json;
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;

public class TokenExchangeGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _validator;

    public TokenExchangeGrantValidator(ITokenValidator validator)
    {
        _validator = validator;
    }

    // The grant type string for token exchange
    public string GrantType => "urn:ietf:params:oauth:grant-type:token-exchange";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        context.Result = new GrantValidationResult(TokenRequestErrors.InvalidRequest);

        var subjectToken = context.Request.Raw.Get("subject_token");
        var subjectTokenType = context.Request.Raw.Get("subject_token_type");

        if (string.IsNullOrWhiteSpace(subjectToken))
            return;

        // Validate the incoming access token
        var validationResult = await _validator.ValidateAccessTokenAsync(subjectToken);
        if (validationResult.IsError)
            return;

        var sub = validationResult.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
        var originalClientId = validationResult.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;

        if (sub == null || originalClientId == null)
            return;

        // Set client_id to original for delegation
        context.Request.ClientId = originalClientId;

        // Create act claim for delegation - shows the call chain
        var actorData = new { client_id = context.Request.Client.ClientId };
        var actClaim = new Claim("act", JsonSerializer.Serialize(actorData), "json");

        context.Result = new GrantValidationResult(
            subject: sub,
            authenticationMethod: GrantType,
            claims: new[] { actClaim });
    }
}
```

## Updated Program.cs

Add the `api_gateway` client and register the validator:

```csharp
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
        new Client
        {
            ClientId = "api_gateway",
            ClientName = "API Gateway",
            AllowedGrantTypes = { "urn:ietf:params:oauth:grant-type:token-exchange" },
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

## How Delegation Works

With delegation, the `act` (actor) claim preserves the call chain. The downstream API can see who the original user is and which service is making the call on their behalf. The token would contain:

```json
{
  "sub": "1",
  "client_id": "web_app",
  "act": {
    "client_id": "api_gateway"
  }
}
```
