# Client-Side DPoP Configuration

To configure DPoP on the client side using token management:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = GenerateDPoPKey();
    });

static string GenerateDPoPKey()
{
    var rsa = RSA.Create(2048);
    var key = new RsaSecurityKey(rsa);
    var jwk = JsonWebKeyConverter.ConvertFromSecurityKey(key);
    jwk.Alg = "PS256";
    return JsonSerializer.Serialize(jwk);
}
```

The `DPoPJsonWebKey` contains the key used to sign DPoP proof tokens. Each API request includes a fresh proof signed with this key. Make sure to store this key securely — if lost, tokens bound to it can't be used.
