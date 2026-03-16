# Security Audit of IdentityServer Setup

Looking at the provided Program.cs, here are the security issues I found and how to fix them:

## Issues Found

1. **Developer signing credential** — `AddDeveloperSigningCredential()` should not be used in production. Use proper key management.

2. **Implicit flow** — The `spa.legacy` client uses `GrantTypes.Implicit` which is deprecated. Migrate to authorization code flow.

3. **Wildcard redirect URIs** — The `web.app` client uses `https://*.example.com/signin-oidc` which allows redirection to attacker-controlled subdomains.

4. **PKCE disabled** — `web.app` has `RequirePkce = false`.

5. **Long access token lifetime** — `web.app` has 8-hour access tokens.

6. **Hardcoded secrets** — Client secrets are string literals in source code.

## Fixed Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
})
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
        AllowOfflineAccess = true,
        AccessTokenLifetime = 3600,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
    },
    new Client
    {
        ClientId = "spa.legacy",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        RequireClientSecret = false,
        RedirectUris = { "https://spa.example.com/callback" },
        AllowedScopes = { "openid", "profile", "catalog.read" },
    },
    new Client
    {
        ClientId = "background.worker",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:Worker"].Sha256()) },
        AllowedScopes = { "internal-api", "orders.manage" },
        AccessTokenLifetime = 3600
    },
    // ...
});
```

Key changes: removed implicit flow, enabled PKCE, fixed redirect URIs, moved secrets to config, removed developer signing credential.
