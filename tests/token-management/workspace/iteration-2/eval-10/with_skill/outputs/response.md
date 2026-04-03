# Implementing IClientAssertionService with Correct Audience

Here's how to implement `IClientAssertionService` for client assertions (private_key_jwt) with the correct audience setting.

## `JwtClientAssertionService.cs`

```csharp
using System.IdentityModel.Tokens.Jwt;
using Duende.AccessTokenManagement;
using IdentityModel;
using IdentityModel.Client;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;

    public JwtClientAssertionService(SigningCredentials signingCredentials)
    {
        _signingCredentials = signingCredentials;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new SecurityTokenDescriptor
        {
            Issuer = "my_client_id",

            // CRITICAL: Audience must be the authorization server's issuer URL,
            // NOT the token endpoint URL.
            //
            // ❌ WRONG: "https://identity.example.com/connect/token"
            // ✅ CORRECT: "https://identity.example.com"
            //
            // CVE-2025-27370 and CVE-2025-27371 were caused by setting the audience
            // to the token endpoint URL. Authorization servers that accept both values
            // are susceptible to token endpoint confusion attacks.
            Audience = "https://identity.example.com",

            Expires = now.AddMinutes(5),
            IssuedAt = now,
            NotBefore = now,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = "my_client_id",
                ["jti"] = Guid.NewGuid().ToString()
            }
        };

        var handler = new JsonWebTokenHandler();
        var jwt = handler.CreateToken(token);

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            Type = OidcConstants.ClientAssertionTypes.JwtBearer,
            Value = jwt
        });
    }
}
```

## Registration in `Program.cs`

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Load signing key from secure storage (Key Vault, etc.)
var rsaKey = RSA.Create();
rsaKey.ImportFromPem(builder.Configuration["ClientAssertion:PrivateKeyPem"]);
var signingCredentials = new SigningCredentials(
    new RsaSecurityKey(rsaKey), SecurityAlgorithms.RsaSha256);

// Register IClientAssertionService
builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(signingCredentials));

// Register token management — the library will use IClientAssertionService
// instead of client_secret when configured
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api.client", client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("my_client_id");
        // No ClientSecret needed — using client assertion instead
        client.Scope = Scope.Parse("api1");
    });

builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("api.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com/"); });

var app = builder.Build();
app.Run();
```

## Key Points

1. **`IClientAssertionService`** is implemented with a `GetClientAssertionAsync` method that returns a signed JWT.
2. **Audience MUST be the authorization server's issuer URL** (e.g., `https://identity.example.com`), **NOT the token endpoint URL** (e.g., `https://identity.example.com/connect/token`).
3. **CVE-2025-27370 and CVE-2025-27371** were caused by setting the audience to the token endpoint URL. This enables token endpoint confusion attacks on authorization servers that accept both values.
4. **`ClientAssertion.Type`** is set to `OidcConstants.ClientAssertionTypes.JwtBearer` (which equals `"urn:ietf:params:oauth:client-assertion-type:jwt-bearer"`).
5. The `IClientAssertionService` is registered with DI using `AddSingleton`. The library automatically picks it up and uses it instead of `client_secret` when making token requests.
