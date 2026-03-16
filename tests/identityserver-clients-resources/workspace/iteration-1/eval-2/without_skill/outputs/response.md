# Configuring a React SPA Client for IdentityServer

Here's how to configure an IdentityServer client for a React SPA that needs user authentication and API access.

## Client Configuration

```csharp
new Client
{
    ClientId = "react-spa",
    ClientName = "React SPA",

    AllowedGrantTypes = GrantTypes.Code,
    RequireClientSecret = false,  // SPAs can't securely store secrets
    RequirePkce = true,

    RedirectUris = { "https://spa.myapp.com/callback" },
    PostLogoutRedirectUris = { "https://spa.myapp.com" },

    AllowedCorsOrigins = { "https://spa.myapp.com" },

    AllowOfflineAccess = true,

    AllowedScopes =
    {
        "openid",
        "profile",
        "orders.read"
    }
}
```

## Notes

- Use the authorization code flow with PKCE — it's the recommended approach for SPAs.
- Since the SPA is a public client, we set `RequireClientSecret = false`.
- CORS origins are needed so the SPA can make cross-origin requests to the IdentityServer endpoints.
- `AllowOfflineAccess = true` enables the SPA to request refresh tokens.
- Make sure the `openid` and `profile` scopes are registered as identity resources on the server.
