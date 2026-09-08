# Confidential Client Using `private_key_jwt` with an X.509 Certificate

For `private_key_jwt`, the client authenticates by signing a JWT assertion with its private key, and you register the corresponding X.509 certificate on the server instead of a shared secret.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static IEnumerable<Client> Clients =>
    new Client[]
    {
        new Client
        {
            ClientId = "webapp",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // X.509 certificate credential (no shared secret)
            ClientSecrets =
            {
                new Secret
                {
                    Type  = IdentityServerConstants.SecretTypes.X509CertificateBase64,
                    Value = "MIID...xBXQ=" // base64-encoded certificate
                }
            },

            RedirectUris           = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            AllowedScopes =
            {
                "openid",
                "profile"
            }
        }
    };
```

Register the client:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Clients)
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });
```

## Notes

- The client uses `GrantTypes.Code` for the interactive web app at `https://webapp.example.com`.
- Authentication uses an X.509 certificate registered as the client secret via `SecretTypes.X509CertificateBase64` — there is no shared secret string.
- The client signs a JWT assertion (`client_assertion`) with the certificate's private key when calling the token endpoint; IdentityServer validates it against the registered public certificate.
- Make sure the client library sends `client_assertion_type = urn:ietf:params:oauth:client-assertion-type:jwt-bearer` with the signed assertion. IdentityServer's built-in secret validators handle the JWT-based client authentication.
