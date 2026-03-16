# Configuring Reference Access Tokens for the web_app Client

To use reference access tokens instead of JWTs and enable immediate revocation, you need to update the `web_app` client and the `ApiResource`. Here's the modified `Program.cs`:

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
            ApiSecrets = { new Secret("api1_introspection_secret".Sha256()) }
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

### 1. Reference Token Type
```csharp
AccessTokenType = AccessTokenType.Reference
```

Reference tokens are **pointers** to token data stored in the IdentityServer persisted grant store. Unlike JWTs which are self-contained, reference tokens are opaque handles. This means:

- **Immediate revocation**: You can revoke a reference token at any time by deleting it from the store. With JWTs, you must wait for the `exp` to pass.
- **Smaller token size**: Reference tokens are just opaque handles rather than full JWTs with claims.
- **Trade-off**: The API must call the introspection endpoint on every request to validate the token, which adds latency and a dependency on IdentityServer availability.

### 2. Access Token Lifetime
```csharp
AccessTokenLifetime = 900 // 15 minutes in seconds
```

Even though reference tokens can be revoked, keeping lifetimes short is still a best practice. 15 minutes (900 seconds) means the API only caches introspection results for a short period.

### 3. API Resource Secret for Introspection
```csharp
ApiSecrets = { new Secret("api1_introspection_secret".Sha256()) }
```

The `ApiResource` must have an `ApiSecrets` collection with at least one secret. The API uses this secret to authenticate when calling the introspection endpoint (`/connect/introspect`). Without a configured `ApiSecret`, the introspection endpoint will return `401 Unauthorized`.

The secret uses `Sha256()` hashing, consistent with how client secrets are hashed in Duende IdentityServer.

### API-Side Configuration

On the API side, you would configure introspection-based token validation:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddOAuth2Introspection("Bearer", options =>
    {
        options.Authority = "https://localhost:5001";
        options.ClientId = "api1_resource";
        options.ClientSecret = "api1_introspection_secret";
    });
```
