Changes: set `web_app` to reference tokens with a 15-minute lifetime, and give the API resource a secret so APIs can call the introspection endpoint.

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
    AccessTokenLifetime = 900          // 15 minutes
},
```

```csharp
.AddInMemoryApiResources(new List<ApiResource>
{
    new ApiResource("api1_resource")
    {
        Scopes = { "api1" },
        ApiSecrets = { new Secret("api1_secret".Sha256()) }   // used for introspection
    }
})
```

Notes:
- The API authenticates to `/connect/introspect` with its ApiResource name and secret (e.g. `AddOAuth2Introspection` from `IdentityModel.AspNetCore.OAuth2Introspection`, `ClientId = "api1_resource"`, `ClientSecret = "api1_secret"`). Use a real secret from configuration/secret store, not a hard-coded one.
- Reference tokens are stored in the persisted grant store. In-memory is fine for development, but in production use the EF operational store (`AddOperationalStore`) so tokens survive restarts and are shared across nodes.
- Revoking is done via the revocation endpoint or by removing grants (`IPersistedGrantService.RemoveAllGrantsAsync`).
- Trade-off: each API call needs introspection (a network call), so enable caching in the introspection handler, which slightly delays effective revocation.
