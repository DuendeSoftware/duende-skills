# Configuring JWT Secured Authorization Requests (JAR)

JAR (JWT Secured Authorization Requests) wraps authorization request parameters into a signed JWT, making them tamperproof. Instead of sending parameters as plain query strings in the authorize URL, the client signs them as a JWT.

## Client Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "secure_app",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RedirectUris = { "https://secure-app.example.com/callback" },
            AllowedScopes = { "openid", "profile", "api1" },

            // Require signed request objects
            RequireRequestObject = true,

            ClientSecrets =
            {
                new Secret
                {
                    // The client's public RSA key in JWK format
                    Type = IdentityServerConstants.SecretTypes.JsonWebKey,
                    Value = "{'e':'AQAB','kid':'secure_app_key','kty':'RSA','n':'...'}"
                }
            }
        }
    ];
}
```

## How It Works

1. The client creates a JWT containing all authorization parameters (`response_type`, `client_id`, `redirect_uri`, `scope`, `state`, `nonce`, etc.).
2. The JWT is signed with the client's private RSA key.
3. The client sends the signed JWT via the `request` query parameter on the authorization endpoint.
4. IdentityServer validates the signature using the registered public key and extracts the parameters.

The key benefit is that authorization parameters cannot be modified in transit — any tampering would invalidate the signature.

## Registering the Signing Key

The client registers its public key as a `ClientSecret` on the server:

- Use `IdentityServerConstants.SecretTypes.JsonWebKey` for JWK format (most common)
- Use `IdentityServerConstants.SecretTypes.X509CertificateBase64` for X.509 certificate format

The server uses this public key to verify the signature on incoming request objects. The client keeps the private key and uses it to sign the JWTs.
