# FAPI 2.0 Configuration

For FAPI 2.0 compliance, you need strong security settings. Here's a configuration:

```csharp
builder.Services.AddIdentityServer(opt =>
{
    // Require PAR
    opt.PushedAuthorization.Required = true;

    // Tight clock skew
    opt.JwtValidationClockSkew = TimeSpan.FromSeconds(10);
})
    .AddInMemoryClients(new[]
    {
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "fapi_client",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = true,
            ClientSecrets =
            {
                new Duende.IdentityServer.Models.Secret("strong_secret".Sha256())
            },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowOfflineAccess = true,
            RequireDPoP = true,
            RequirePushedAuthorization = true,
            RefreshTokenUsage = Duende.IdentityServer.Models.TokenUsage.ReUse
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

FAPI 2.0 requires sender-constrained tokens (DPoP or mTLS), pushed authorization requests, PKCE, and confidential clients.
