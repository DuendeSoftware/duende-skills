# Configuring Private Key JWT Client Authentication

To set up a confidential client that authenticates using `private_key_jwt` with an X.509 certificate, you need to configure the client with a certificate-based secret and enable JWT bearer client authentication on the server.

## How Private Key JWT Works

Instead of sending a shared secret to the token endpoint, the client creates a signed JWT assertion using its private key. IdentityServer validates the JWT using the corresponding public key (from the X.509 certificate or JWK registered with the client). This is more secure than shared secrets because the private key never leaves the client.

## Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("api1", "Main API")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "webapp.jwt",
            ClientName = "Web App with Private Key JWT",

            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // X.509 certificate-based secret — no shared secret
            ClientSecrets =
            {
                new Secret
                {
                    Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
                    Value = "MIID...base64-encoded-certificate...xBXQ="
                    // Replace with your actual base64-encoded X.509 certificate
                }
            },

            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            AllowOfflineAccess = true,

            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                "api1"
            }
        }
    })
    // Enable JWT bearer client authentication
    .AddJwtBearerClientAuthentication();

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Key Points

1. **Secret Type**: The client's `ClientSecrets` uses `Type = IdentityServerConstants.SecretTypes.X509CertificateBase64` with the base64-encoded public certificate. You could also use `SecretTypes.JsonWebKey` if you prefer JWK format.

2. **No Shared Secret**: There is no `.Sha256()` call on a string — the client authenticates with its private key, and IdentityServer validates using the registered public key.

3. **Enable JWT Bearer Authentication**: Call `.AddJwtBearerClientAuthentication()` on the IdentityServer builder to register the JWT bearer client authentication validator.

4. **Grant Type**: The client uses `GrantTypes.Code` for the authorization code flow with PKCE, suitable for a web application.

5. **Certificate Management**: In production, load the certificate from a secure store (Azure Key Vault, file system, certificate store) rather than embedding the base64 string directly in code.
