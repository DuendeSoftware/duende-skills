```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using System.Security.Cryptography.X509Certificates;

var builder = WebApplication.CreateBuilder(args);

// Public part of the client's certificate only (never the private key)
var cert = X509CertificateLoader.LoadCertificateFromFile("certs/webapp-client.cer");

var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp",
            ClientName = "Web App",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile
            },
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
                    Value = Convert.ToBase64String(cert.RawData)
                }
            }
        }
    });

// Enable private_key_jwt / JWT bearer client authentication
idsvrBuilder.AddJwtBearerClientAuthentication();

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```
- `AddJwtBearerClientAuthentication()` enables validation of `client_assertion` JWTs on the token endpoint.
- The secret type `X509CertificateBase64` holds the base64 public certificate; a `JsonWebKey` secret type is the alternative.
- The web app signs a JWT assertion with its private key (`iss`/`sub` = `webapp`) and sends it instead of a secret; no shared secret is transmitted. In ASP.NET Core, supply it through the OIDC handler's `ClientAssertion` events/Duende.AccessTokenManagement's assertion service.
- This is preferred over shared secrets in production; mTLS is the stronger option for FAPI-like needs.
