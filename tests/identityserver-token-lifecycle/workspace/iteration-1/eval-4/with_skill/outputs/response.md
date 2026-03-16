# Custom Profile Service with Scope-Based Claims and Token Exchange Support

Here's how to create a profile service that loads claims from a database, emits only scope-requested claims, and handles the `act` claim for token exchange flows.

## CustomProfileService

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CustomProfileService : DefaultProfileService
{
    public CustomProfileService(ILogger<DefaultProfileService> logger) : base(logger)
    {
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims from database (hypothetical)
        var claims = await GetClaimsFromDatabaseAsync(context.Subject.GetSubjectId());

        // Only emit claims that are requested by the client's scopes
        context.AddRequestedClaims(claims);

        // For token exchange flows, forward the 'act' claim
        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var actClaim = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (actClaim != null)
            {
                context.IssuedClaims.Add(actClaim);
            }
        }
    }

    private Task<IEnumerable<Claim>> GetClaimsFromDatabaseAsync(string subjectId)
    {
        // In a real application, this would query a database
        var claims = new List<Claim>
        {
            new Claim(JwtClaimTypes.Name, "Alice Smith"),
            new Claim(JwtClaimTypes.Email, "alice@example.com"),
            new Claim(JwtClaimTypes.Role, "admin"),
            new Claim("tenant_id", "42")
        };

        return Task.FromResult<IEnumerable<Claim>>(claims);
    }
}
```

## Registration in Program.cs

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
        // ... other clients
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

// Register the custom profile service
idsvrBuilder.AddProfileService<CustomProfileService>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Design Decisions

### Using `AddRequestedClaims` Instead of Direct Addition

The `context.AddRequestedClaims(claims)` method is the recommended approach because it:

- **Respects scopes**: Only claims that are associated with scopes the client requested will be emitted
- **Supports consent**: If the user didn't consent to certain scopes, those claims won't be emitted
- **Avoids token bloat**: Prevents all user claims from being dumped into every token

If you use `context.IssuedClaims.AddRange(claims)` instead, all claims would be emitted regardless of which scopes were requested. This can lead to bloated tokens and information disclosure.

### Extending `DefaultProfileService`

By extending `DefaultProfileService` rather than implementing `IProfileService` directly, you inherit the default behavior for claims filtering and can focus on adding custom logic. The base class handles standard claim types like `sub`, `auth_time`, etc.

### Token Exchange `act` Claim Handling

When the authentication method is `urn:ietf:params:oauth:grant-type:token-exchange` (the token exchange grant type), the profile service checks for an `act` (actor) claim on the subject and forwards it to the issued claims. This preserves the delegation chain in the new token.

The check uses `context.Subject.GetAuthenticationMethod()` which returns the `amr` claim value — for token exchange, this is the grant type string itself.
