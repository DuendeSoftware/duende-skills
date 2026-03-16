# Configuring Reference Access Tokens for web_app

To switch from JWT to reference access tokens for revocability, you need to update the client and API resource configuration:

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

            // Use reference tokens for revocability
            AccessTokenType = AccessTokenType.Reference,

            // 15 minute lifetime
            AccessTokenLifetime = 900
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
            ApiSecrets = { new Secret("introspection_secret".Sha256()) }
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

## Changes

- **`AccessTokenType = AccessTokenType.Reference`** — Switches from JWT to reference tokens. Reference tokens are opaque identifiers stored server-side and can be revoked immediately.
- **`AccessTokenLifetime = 900`** — Sets token lifetime to 15 minutes (900 seconds).
- **`ApiSecrets`** on the API resource — APIs need to authenticate to the introspection endpoint to validate reference tokens. The secret uses `Sha256()` hashing.

The API must be configured with an introspection handler to validate reference tokens against the IdentityServer's `/connect/introspect` endpoint.
