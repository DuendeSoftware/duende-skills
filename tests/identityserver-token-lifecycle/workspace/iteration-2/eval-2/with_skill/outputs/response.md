# Configuring Reference Access Tokens with Introspection

To use reference access tokens (revocable) instead of JWTs, and set a 15-minute lifetime, you need to update both the `web_app` client and the `api1_resource` API resource.

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

            // Use reference tokens for immediate revocability
            AccessTokenType = AccessTokenType.Reference,
            AccessTokenLifetime = 900 // 15 minutes in seconds
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

## Key Changes

1. **`AccessTokenType = AccessTokenType.Reference`** — Switches the `web_app` client from JWT tokens (default) to reference tokens. Reference tokens are opaque handles stored in the persisted grant store, and the API must call the introspection endpoint to validate them.

2. **`AccessTokenLifetime = 900`** — Sets the access token lifetime to 15 minutes (15 × 60 = 900 seconds).

3. **`ApiSecrets = { new Secret("api1_secret".Sha256()) }`** on the `ApiResource` — This is critical for reference tokens. The API consuming reference tokens must authenticate with the introspection endpoint using this secret. Without an `ApiSecret`, introspection will fail with a 401.

The secret uses `Sha256()` hashing, which is the standard approach for storing secrets in Duende IdentityServer.
