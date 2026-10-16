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
    AccessTokenLifetime = 900   // 15 minutes
},
```

```csharp
.AddInMemoryApiResources(new List<ApiResource>
{
    new ApiResource("api1_resource")
    {
        Scopes = { "api1" },
        ApiSecrets = { new Secret("api_secret".Sha256()) }
    }
})
```

Notes:
- Reference tokens are pointers to data in the persisted grant store; APIs must validate them via the introspection endpoint, authenticating with the ApiResource name and secret. Without an `ApiSecret`, introspection fails with 401 — hence the secret. Use a strong value from configuration in production.
- Revocation: deleting the stored grant (or calling `/connect/revocation`) invalidates the token immediately, unlike JWTs, which remain valid until `exp`.
- Trade-off: every API call needs IdentityServer to be reachable (or an introspection cache), which adds latency and a network dependency. Not suitable for offline/intermittently connected APIs.
- Reference tokens aren't tied to the user session by default; set `CoordinateLifetimeWithUserSession = true` on the client so they're revoked at logout/session expiry.
- In production use the EF operational store (with `EnableTokenCleanup`) so tokens survive restarts and are shared across nodes.
