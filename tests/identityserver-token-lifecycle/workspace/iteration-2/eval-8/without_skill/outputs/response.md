# Shortening Access Token Lifetimes and Token Cleanup

Here's how to reduce access token lifetimes and configure token cleanup.

## Updated Client Configurations

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
    AccessTokenLifetime = 300 // 5 minutes
},
new Client
{
    ClientId = "m2m_client",
    ClientName = "Machine to Machine Client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("m2m_secret".Sha256()) },
    AllowedScopes = { "api1" },
    AccessTokenLifetime = 600 // 10 minutes
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
    RequirePkce = true,
    AccessTokenLifetime = 300 // 5 minutes
}
```

## Token Cleanup

For token cleanup, you'll need to configure the operational store. This typically depends on whether you're using Entity Framework or another store:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // 30 minutes in seconds
    });
```

You may also want to configure cleanup of consumed tokens. Check your IdentityServer documentation for options like removing consumed tokens with a delay period.

## Best Practices

- Keep JWT access token lifetimes short (5-15 minutes) since they can't be revoked
- Use refresh tokens for clients that need longer sessions
- Enable token cleanup to prevent the database from growing indefinitely
- Consider the trade-off between cleanup frequency and database load
