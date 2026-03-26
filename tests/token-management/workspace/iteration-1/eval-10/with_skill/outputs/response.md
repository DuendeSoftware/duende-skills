# Client Assertions (private_key_jwt) with Duende.AccessTokenManagement

Client assertions use signed JWTs instead of shared secrets to authenticate your client to the token endpoint. This is more secure for production deployments as the private key never leaves your service.

## CRITICAL: CVE-2025-27370 / CVE-2025-27371

**The JWT `Audience` must be set to the authorization server's issuer URL — NOT the token endpoint URL.**

CVE-2025-27370 and CVE-2025-27371 were caused by setting the client assertion JWT audience to the token endpoint URL (e.g., `https://identity.example.com/connect/token`). Authorization servers that accept both the issuer URL and the token endpoint URL as valid audience values are susceptible to token endpoint confusion attacks. Always set `Audience` to the issuer URL obtained from the OIDC discovery document's `issuer` claim.

```csharp
// ❌ WRONG: Audience set to token endpoint URL — CVE-2025-27370 / CVE-2025-27371
Audience = "https://identity.example.com/connect/token"

// ✅ CORRECT: Audience must be the authorization server's issuer URL
Audience = "https://identity.example.com"
```

## IClientAssertionService Implementation

```csharp
public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;
    private readonly string _clientId;
    private readonly string _issuerUrl;

    public JwtClientAssertionService(
        SigningCredentials signingCredentials,
        string clientId,
        string issuerUrl)
    {
        _signingCredentials = signingCredentials;
        _clientId = clientId;
        _issuerUrl = issuerUrl;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new SecurityTokenDescriptor
        {
            Issuer = _clientId,
            // ✅ CRITICAL: Audience is the issuer URL, NOT the token endpoint
            Audience = _issuerUrl,
            Expires = now.AddMinutes(5),
            IssuedAt = now,
            NotBefore = now,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = _clientId,
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

## Registration

```csharp
// Load signing key from secure storage (Key Vault, config, etc.)
var jwkJson = builder.Configuration["ClientAssertion:JsonWebKey"];
var jwk = new JsonWebKey(jwkJson);
var signingCredentials = new SigningCredentials(jwk, SecurityAlgorithms.RsaSha256);

// Register the assertion service
builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(
        signingCredentials,
        clientId: "my-client-id",
        issuerUrl: "https://identity.example.com"  // ✅ Issuer URL, NOT token endpoint
    ));

// Register client credentials token management
// When IClientAssertionService is registered, the library uses it automatically
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-client-id");
        // No ClientSecret needed — the assertion replaces it
        client.Scope = Scope.Parse("api1");
    });

builder.Services.AddClientCredentialsHttpClient("api",
    ClientCredentialsClientName.Parse("my.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com"); });
```

## How It Works

1. When the library needs to request a token from the token endpoint, it calls `IClientAssertionService.GetClientAssertionAsync()`.
2. The service creates a signed JWT with:
   - `iss` and `sub` set to the client ID
   - `aud` set to the **authorization server's issuer URL** (not the token endpoint)
   - A short expiration (5 minutes)
   - A unique `jti` for replay protection
3. The JWT is included in the token request as `client_assertion` with type `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`.

## Security Notes

- **Never hardcode the private key** — load from Azure Key Vault, AWS Secrets Manager, or similar.
- **Rotate keys regularly** — use key IDs (`kid`) to support multiple active keys during rotation.
- **Set short expiry** — 5 minutes is typical; the assertion is single-use per token request.
