# Using Reference Access Tokens

To use reference tokens instead of JWTs, you need to change the access token type on the client and ensure the API resource has a secret for token introspection.

## Changes

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
    AccessTokenType = AccessTokenType.Reference,
    AccessTokenLifetime = 900 // 15 minutes
}
```

And add a secret to the API resource:

```csharp
new ApiResource("api1_resource")
{
    Scopes = { "api1" },
    ApiSecrets = { new Secret("introspection_secret".Sha256()) }
}
```

Reference tokens are opaque handles. The API must call the introspection endpoint to validate them. The API resource secret authenticates that introspection call.
