```csharp
using Duende.IdentityServer.Models;
using System.Security.Cryptography.X509Certificates;

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[] { new IdentityResources.OpenId(), new IdentityResources.Profile() })
    .AddJwtBearerClientAuthentication()
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp",
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile" },
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
```
`cert` is loaded from the client's public .cer (`new X509Certificate2("client.cer")`). `AddJwtBearerClientAuthentication()` enables `private_key_jwt` assertions (`client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`). The client signs a JWT with its private key; `iss`/`sub` = client id, `aud` = the IdentityServer issuer/token endpoint. The web app's OIDC handler sets `ClientAssertion` on token requests.
