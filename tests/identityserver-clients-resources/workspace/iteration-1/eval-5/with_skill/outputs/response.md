# Private Key JWT Client Authentication

Here's how to configure a confidential web application client that authenticates using `private_key_jwt` instead of a shared secret, with an X.509 certificate.

## Client Definition

```csharp
new Client
{
    ClientId = "webapp-pkjwt",
    ClientName = "Web Application (Private Key JWT)",

    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // X.509 certificate for private_key_jwt authentication
    // No shared secret — the client authenticates by signing a JWT with its private key
    ClientSecrets =
    {
        new Secret
        {
            Type = IdentityServerConstants.SecretTypes.X509CertificateBase64,
            Value = Convert.ToBase64String(certificate.GetRawCertData())
        }
    },

    RedirectUris = { "https://webapp.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

    AllowedScopes =
    {
        IdentityServerConstants.StandardScopes.OpenId,
        IdentityServerConstants.StandardScopes.Profile,
        "api1"
    }
}
```

## Enable JWT Bearer Client Authentication on the Server

You must call `AddJwtBearerClientAuthentication()` on the IdentityServer builder to enable the server to validate JWT client assertions:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddJwtBearerClientAuthentication();  // Enable private_key_jwt validation
```

## Alternative: Using a JsonWebKey

Instead of an X.509 certificate, you can register a JWK:

```csharp
ClientSecrets =
{
    new Secret
    {
        Type = IdentityServerConstants.SecretTypes.JsonWebKey,
        Value = "{'e':'AQAB','kid':'...','kty':'RSA','n':'...'}"
    }
}
```

## How It Works

1. The client creates a JWT assertion signed with its **private key**.
2. The client sends the assertion to the token endpoint using `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`.
3. IdentityServer validates the JWT signature against the registered **public key** (from the X.509 certificate or JWK).

This is more secure than shared secrets because the private key never leaves the client — only the public key is registered on the server.
