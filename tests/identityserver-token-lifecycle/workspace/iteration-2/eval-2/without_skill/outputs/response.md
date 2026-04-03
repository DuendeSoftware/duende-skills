# Configuring Reference Access Tokens

To use reference tokens instead of JWTs for the web_app client, you'll need to change the token type and set up the API for token introspection.

```csharp
new Client
{
    ClientId = "web_app",
    ClientName = "Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    ClientSecrets = { new Secret("secret".Sha256()) },
    RedirectUris = { "https://localhost:5002/signin-oidc" },
    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "api1" },
    
    // Use reference tokens instead of JWT
    AccessTokenType = AccessTokenType.Reference,
    AccessTokenLifetime = 900 // 15 minutes
}
```

For the API to validate reference tokens, it needs to be able to call the introspection endpoint. You should configure a secret on your API resource:

```csharp
new ApiResource("api1_resource")
{
    Scopes = { "api1" },
    ApiSecrets = { new Secret("api_secret".Sha256()) }
}
```

## Key Points

- **`AccessTokenType.Reference`** switches from self-contained JWTs to opaque reference tokens stored server-side
- **`AccessTokenLifetime = 900`** sets the lifetime to 15 minutes (900 seconds)
- The API resource needs an `ApiSecrets` entry so it can authenticate to the introspection endpoint to validate tokens
- The secret uses `Sha256()` for hashing
