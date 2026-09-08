# Confidential Client Using `private_key_jwt` with an X.509 Certificate

Instead of a shared secret, this client authenticates with a signed JWT assertion proven by an X.509 certificate. The secret is registered with `Type = IdentityServerConstants.SecretTypes.X509CertificateBase64`, and JWT bearer client authentication is enabled on the server with `AddJwtBearerClientAuthentication()`.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<Client> Clients =>
        new Client[]
        {
            new Client
            {
                ClientId = "webapp.jwt",
                ClientName = "Web App (private_key_jwt)",

                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,

                // Asymmetric credential — NO shared secret
                ClientSecrets =
                {
                    new Secret
                    {
                        Type  = IdentityServerConstants.SecretTypes.X509CertificateBase64,
                        Value = "MIID...xBXQ="   // base64 of the client's X.509 certificate
                    }
                },

                RedirectUris           = { "https://webapp.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

                AllowOfflineAccess = true,

                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile
                }
            }
        };
}
```

Enable JWT bearer (private_key_jwt) client authentication on the IdentityServer builder:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

// Enables validation of client_assertion JWTs signed by the client's key
idsvrBuilder.AddJwtBearerClientAuthentication();
```

## Notes

- **`SecretTypes.X509CertificateBase64`** — registers the client's certificate (base64-encoded) as the credential. IdentityServer uses the certificate's public key to verify the `client_assertion` JWT the client sends at the token endpoint. You can also use `SecretTypes.JsonWebKey` to register a JWK directly.
- **`AddJwtBearerClientAuthentication()`** — turns on the `private_key_jwt` (RFC 7523) client authentication method. Without it, the server won't validate JWT client assertions.
- **No shared secret** — there is no `new Secret("...".Sha256())`. The client proves its identity by signing a JWT with the private key corresponding to the registered certificate, so nothing secret is transmitted to the token endpoint.
- **`GrantTypes.Code`** with PKCE for the interactive web app, with the given redirect URIs.
