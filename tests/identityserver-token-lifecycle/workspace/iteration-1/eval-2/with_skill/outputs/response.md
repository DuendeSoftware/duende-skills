# Configuring Reference Access Tokens with Introspection

Reference access tokens are **pointers** to token data stored server-side, rather than self-contained JWTs. This enables immediate revocation — you simply delete the stored data and the token becomes invalid.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

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

            // Use reference tokens instead of JWTs
            AccessTokenType = AccessTokenType.Reference,

            // 15-minute access token lifetime
            AccessTokenLifetime = 900
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
            Scopes = { "api1" },

            // Secret required for introspection endpoint validation
            ApiSecrets = { new Secret("api1_secret".Sha256()) }
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

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Configuration Details

### Client: Reference Tokens
- **`AccessTokenType = AccessTokenType.Reference`** — Tokens are stored server-side; only an opaque handle is returned to the client
- **`AccessTokenLifetime = 900`** — 15 minutes (15 × 60 = 900 seconds)

### API Resource: Introspection Secret
- **`ApiSecrets = { new Secret("api1_secret".Sha256()) }`** — The API must authenticate itself to the introspection endpoint. Without this secret, introspection calls return `401 Unauthorized`.

### How Reference Token Validation Works

1. Client receives an opaque token handle (not a JWT)
2. Client sends the handle to the API in the `Authorization: Bearer` header
3. API calls IdentityServer's introspection endpoint (`/connect/introspect`) with the token handle
4. IdentityServer looks up the stored token data and returns the claims
5. API uses the claims for authorization decisions

### API-Side Configuration (Consuming API)

The API needs to be configured to use introspection:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
    {
        options.Authority = "https://localhost:5001";
        options.ClientId = "api1_resource";
        options.ClientSecret = "api1_secret";
    });
```

### Why Reference Tokens?
- **Immediate revocation**: Delete the persisted grant and the token is instantly invalid
- **Smaller token size**: Only a handle is transmitted, reducing bandwidth
- **Trade-off**: Each API call requires an introspection call to IdentityServer, adding latency and requiring IdentityServer availability
