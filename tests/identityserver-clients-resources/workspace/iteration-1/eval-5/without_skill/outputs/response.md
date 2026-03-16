# Using Private Key JWT for Client Authentication

To use `private_key_jwt` authentication, you'll need to register the client's public certificate and configure the server to accept JWT bearer client assertions.

## Client Configuration

```csharp
new Client
{
    ClientId = "webapp-pkjwt",
    ClientName = "Web Application",

    AllowedGrantTypes = GrantTypes.Code,

    ClientSecrets =
    {
        new Secret
        {
            Type = "X509CertificateBase64",
            Value = Convert.ToBase64String(certificate.GetRawCertData())
        }
    },

    RedirectUris = { "https://webapp.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

    AllowedScopes = { "openid", "profile", "api1" }
}
```

## Server Configuration

You need to register a service to handle JWT bearer client authentication. In IdentityServer, this typically involves enabling JWT-based client authentication:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);
```

## How It Works

- Instead of sending a secret, the client signs a JWT with its private key and sends it as a `client_assertion` to the token endpoint.
- The server validates the JWT signature using the registered public key (X.509 certificate).
- This is more secure than shared secrets since the private key never leaves the client.
