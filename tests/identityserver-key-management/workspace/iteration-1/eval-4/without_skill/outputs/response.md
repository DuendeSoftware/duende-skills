# Configuring Multiple Signing Algorithms in IdentityServer

Here's the updated `Program.cs` with RS256 and ES256 support, plus a mobile-app client configured for ES256:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
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
            RedirectUris = { "com.example.mobileapp://callback" },
            AllowedScopes = { "openid", "profile", "api1" }
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

To support multiple signing algorithms, you would typically register multiple signing credentials. For RS256, load an X.509 certificate and call `AddSigningCredential`. For ES256, you'd create an ECDSA key:

```csharp
// Load RS256 certificate
var rsaCert = new X509Certificate2("rs256-cert.pfx", "password");
idsvrBuilder.AddSigningCredential(rsaCert, "RS256");

// Create ES256 key
var ecdsaKey = new ECDsaSecurityKey(ECDsa.Create(ECCurve.NamedCurves.nistP256));
idsvrBuilder.AddSigningCredential(ecdsaKey, "ES256");
```

For the mobile-app client to specifically use ES256, you may need to configure that at the token level. The exact configuration depends on your IdentityServer version and setup.
