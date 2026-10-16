```csharp
using Microsoft.IdentityModel.Tokens;

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.SigningAlgorithms = new[]
        {
            // first entry is the default
            new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true },
            new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256)
        };
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "mobile-app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,
            RedirectUris = { "com.example.mobile:/callback" },
            AllowedScopes = { "openid", "profile", "api1" },
            AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }  // ES256 identity tokens
        },
        // web-app, machine-client unchanged
    })
    // ...
```

- RS256 is first, so it's the default; keys for both algorithms are created, rotated and published in JWKS.
- `UseX509Certificate = true` wraps the RSA key in an X.509 certificate (for consumers needing certs). It isn't supported for EC keys.
- `AllowedIdentityTokenSigningAlgorithms` overrides the default per client for identity tokens; for access tokens, use `ApiResource.AllowedAccessTokenSigningAlgorithms`.
