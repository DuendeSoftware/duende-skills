# Enabling DPoP for a Client

DPoP (Demonstrating Proof-of-Possession) is a mechanism that binds access tokens to a cryptographic key held by the client. When DPoP is enabled, the access token contains a `cnf` claim with a `jkt` (JSON Web Key Thumbprint) value — the thumbprint of the client's public key. The client must prove possession of the corresponding private key on every request by sending a signed DPoP proof in the `DPoP` HTTP header.

This means even if an access token is stolen, an attacker cannot use it without the private key.

## Client Configuration

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Enable DPoP for this client
    RequireDPoP = true,

    // Set clock skew tolerance to 2 minutes
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

## Updated Program.cs

```csharp
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
    public static IEnumerable<Duende.IdentityServer.Models.IdentityResource> IdentityResources =>
    [
        new Duende.IdentityServer.Models.IdentityResources.OpenId(),
        new Duende.IdentityServer.Models.IdentityResources.Profile()
    ];

    public static IEnumerable<Duende.IdentityServer.Models.ApiScope> ApiScopes =>
    [
        new Duende.IdentityServer.Models.ApiScope("api1", "My API")
    ];

    public static IEnumerable<Duende.IdentityServer.Models.Client> Clients =>
    [
        new Duende.IdentityServer.Models.Client
        {
            ClientId = "dpop_client",
            AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
            ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
            AllowedScopes = { "api1" },
            RequireDPoP = true,
            DPoPClockSkew = TimeSpan.FromMinutes(2)
        }
    ];
}
```

## How DPoP Works

1. The client generates an asymmetric key pair and stores it as a JWK.
2. When requesting a token, the client sends a DPoP proof (a signed JWT) in the `DPoP` header.
3. IdentityServer validates the proof and issues an access token with a `cnf` claim containing the `jkt` thumbprint.
4. On API calls, the client sends both the access token (using the `DPoP` scheme instead of `Bearer`) and a fresh DPoP proof.
5. The API verifies the proof matches the key referenced in the token.

Note that DPoP is separate from client authentication — the client still authenticates with its shared secret at the token endpoint. DPoP adds an additional layer of token binding on top of whatever authentication method the client uses.
