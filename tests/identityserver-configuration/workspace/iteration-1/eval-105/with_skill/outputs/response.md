# Private Key JWT Client Authentication

Here's how to configure a client that authenticates using `private_key_jwt` with an X.509 certificate, and enable JWT bearer client authentication on the server:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    // Enable JWT bearer client authentication
    .AddJwtBearerClientAuthentication()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "webapp-private-key",
            ClientName = "Web Application with Private Key JWT",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // X.509 certificate for private_key_jwt authentication
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
                    Value = Convert.ToBase64String(certificate.RawData)
                }
            },

            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            AllowOfflineAccess = true,

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile
            }
        }
    });
```

## How Private Key JWT Works

Instead of sending a shared secret to the token endpoint, the client creates a signed JWT assertion using its private key. IdentityServer validates the signature against the registered public key (from the X.509 certificate).

### Security Advantages

- **No shared secret transmission**: The private key never leaves the client.
- **Asymmetric**: Compromise of the public key (registered in IdentityServer) doesn't compromise the client.
- **Non-repudiation**: The JWT assertion proves the client has the private key.

### Secret Types

| Type | Use Case |
|------|----------|
| `SecretTypes.X509CertificateBase64` | Base64-encoded X.509 certificate |
| `SecretTypes.JsonWebKey` | JWK format public key |
| `SecretTypes.X509CertificateThumbprint` | Certificate thumbprint (for mTLS) |

### Client-Side Token Request

The client sends a `client_assertion` with `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`:

```http
POST /connect/token
grant_type=authorization_code&
code=...&
client_id=webapp-private-key&
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&
client_assertion=eyJhbGciOiJSUzI1NiIs...
```
