# Configure Multiple Signing Algorithms with Per-Client Override

To support both RS256 (with X.509 wrapping) and ES256, and configure a specific client to use ES256, update your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
    {
        // Configure multiple signing algorithms
        // The first algorithm is the default for signing tokens
        options.KeyManagement.SigningAlgorithms = new[]
        {
            // RS256 with X.509 certificate wrapping (default)
            new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
            {
                UseX509Certificate = true
            },
            // ES256 as secondary algorithm
            new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256)
        };
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "mobile-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "com.myapp://callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Override: use ES256 for identity tokens issued to this client
            AllowedIdentityTokenSigningAlgorithms = { SecurityAlgorithms.EcdsaSha256 }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How This Works

### Multiple Signing Algorithms
- `SigningAlgorithms` is set to an array of `SigningAlgorithmOptions`. Automatic key management will create and rotate keys for each configured algorithm.
- The **first** entry (`RsaSha256`) is the default — tokens are signed with RS256 unless overridden.
- `UseX509Certificate = true` on the RS256 entry wraps the RSA key in an X.509 certificate. This improves compatibility with older clients and libraries that expect X.509 formatted keys in the JWKS.
- The second entry (`EcdsaSha256`) configures ES256 as an additional available algorithm.

### Per-Client Algorithm Override
- The `mobile-app` client sets `AllowedIdentityTokenSigningAlgorithms` to `{ SecurityAlgorithms.EcdsaSha256 }`. This means identity tokens issued to this client will be signed with ES256 instead of the default RS256.
- You can also set `AllowedAccessTokenSigningAlgorithms` on `ApiResource` to override the algorithm for access tokens targeting a specific API.

### Discovery Document
Both algorithms' public keys will appear in the JWKS endpoint (`/.well-known/openid-configuration/jwks`), allowing clients and APIs to validate tokens signed with either algorithm.
