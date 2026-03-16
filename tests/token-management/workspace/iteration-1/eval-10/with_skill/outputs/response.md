# Client Assertions with IClientAssertionService

Client assertions use signed JWTs instead of shared client secrets for authenticating to the token endpoint. This is more secure because the private key never leaves your application.

## CRITICAL: CVE-2025-27370 / CVE-2025-27371

These CVEs were caused by setting the client assertion JWT `Audience` to the **token endpoint URL** instead of the **authorization server's issuer URL**. Authorization servers that accept both values are susceptible to token endpoint confusion attacks. **Always set `Audience` to the issuer URL** obtained from the OIDC discovery document (`issuer` claim).

```csharp
// ❌ WRONG — Root cause of CVE-2025-27370 / CVE-2025-27371
Audience = "https://sts.example.com/connect/token"

// ✅ CORRECT — Audience must be the issuer URL
Audience = "https://sts.example.com"
```

## IClientAssertionService Implementation

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
            // ✅ CRITICAL: Audience must be the authorization server's issuer URL,
            // NOT the token endpoint URL — see CVE-2025-27370 / CVE-2025-27371
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
var builder = WebApplication.CreateBuilder(args);

// Load signing key from secure storage (Key Vault, configuration secrets, etc.)
var rsaKey = RSA.Create();
rsaKey.ImportFromPem(builder.Configuration["ClientAssertion:PrivateKeyPem"]);
var signingCredentials = new SigningCredentials(
    new RsaSecurityKey(rsaKey), SecurityAlgorithms.RsaSsaPssSha256);

// ✅ Register the client assertion service
builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(
        signingCredentials,
        clientId: "webapp",
        issuerUrl: "https://sts.example.com"));  // ← issuer URL, NOT token endpoint

// Configure token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

var app = builder.Build();
app.Run();
```

## How It Works

1. **`IClientAssertionService`** — The library calls `GetClientAssertionAsync` before every token request. The returned `ClientAssertion` is sent as `client_assertion` in the token request body.

2. **`Type = OidcConstants.ClientAssertionTypes.JwtBearer`** — This sets the `client_assertion_type` parameter to `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`, as required by RFC 7523.

3. **Audience = Issuer URL** — The JWT `aud` claim must be the authorization server's issuer identifier (the same value as the `issuer` field in the discovery document). Using the token endpoint URL instead is the exact mistake that caused CVE-2025-27370 and CVE-2025-27371.

4. **Registration with DI** — Use `AddSingleton<IClientAssertionService>(...)` or `AddTransient<IClientAssertionService>(...)`. The library resolves this service automatically when present.
