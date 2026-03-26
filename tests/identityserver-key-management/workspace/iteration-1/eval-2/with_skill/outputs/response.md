# Using Static Signing Keys with PFX Certificate

Here's how to disable automatic key management and use a static PFX certificate for signing with RS256.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;
using System.Security.Cryptography.X509Certificates;

var builder = WebApplication.CreateBuilder(args);

var certPassword = builder.Configuration["CertificatePassword"];
var certBytes = File.ReadAllBytes("/certs/signing.pfx");
var signingCertificate = X509CertificateLoader.LoadPkcs12(certBytes, certPassword);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Disable automatic key management — we're using a static key
    options.KeyManagement.Enabled = false;
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

// Register the static signing credential with RS256
idsvrBuilder.AddSigningCredential(signingCertificate, SecurityAlgorithms.RsaSha256);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

- `KeyManagement.Enabled = false` disables automatic key management entirely
- `X509CertificateLoader.LoadPkcs12` is the modern .NET API for loading PFX certificates (replaces `new X509Certificate2(bytes, password)`)
- `AddSigningCredential` registers the certificate as the active signing key with RS256 algorithm
- The certificate password should come from a secure configuration source (environment variables, Azure Key Vault, etc.)
- When using static keys, **you** are responsible for key rotation — consider the phased rotation approach
