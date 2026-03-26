# Configuring Pushed Authorization Requests (PAR)

PAR allows clients to send authorization parameters via a back-channel POST instead of through the browser URL.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.PushedAuthorization.Required = true;
    options.PushedAuthorization.Lifetime = 300; // 5 minutes
})
    .AddInMemoryClients(new[]
    {
        // ... existing clients ...
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "banking_app",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Duende.IdentityServer.Models.Secret("banking_secret".Sha256()) },
            RedirectUris = { "https://banking.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            RequirePushedAuthorization = true,
            PushedAuthorizationLifetime = 900 // 15 minutes override
        }
    })
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

The global setting requires all clients to use PAR with a 5-minute lifetime. The banking_app overrides this to 15 minutes to allow more time for authentication flows.
