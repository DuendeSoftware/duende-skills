```csharp
using Microsoft.IdentityModel.Tokens;
using Duende.IdentityServer.Configuration;

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.SigningAlgorithms = new[]
        {
            // first = default
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
            AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }  // ES256 ID tokens
        },
        // existing web-app and machine-client...
    })
    // ...
```

- The first algorithm is the default signing algorithm; all configured algorithms get keys created and published in the JWKS.
- `UseX509Certificate = true` wraps the RSA key in a self-signed X.509 certificate (needed for e.g. SAML/`x5c` consumers).
- `AllowedIdentityTokenSigningAlgorithms` on the client restricts ID tokens to ES256. For access tokens use `ApiResource.AllowedAccessTokenSigningAlgorithms`.
