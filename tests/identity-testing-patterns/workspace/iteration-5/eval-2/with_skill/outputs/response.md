# Testing a Protected API with Self-Signed JWTs

Instead of standing up a real IdentityServer for API tests, mint your own JWTs in the test project using a **static RSA signing key**, then configure the API's `WebApplicationFactory` to trust that same key. Because the key is fixed, signatures are verifiable deterministically.

## 1. TestTokenFactory

```csharp
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
    // Static key shared between the factory and the API's validation config
    private static readonly RsaSecurityKey TestSigningKey = CreateRsaKey();

    public static SecurityKey SigningKey => TestSigningKey;

    private static RsaSecurityKey CreateRsaKey()
    {
        var rsa = RSA.Create(2048);
        return new RsaSecurityKey(rsa) { KeyId = "test-key-1" };
    }

    public static string CreateAccessToken(
        string subject,
        string audience,
        IEnumerable<Claim> claims,
        TimeSpan? lifetime = null)
    {
        var allClaims = new List<Claim>
        {
            new("sub", subject),
            new("jti", Guid.NewGuid().ToString())
        };
        allClaims.AddRange(claims);

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(allClaims),
            Audience = audience,
            Issuer = "https://test-authority",
            Expires = DateTime.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(5)),
            SigningCredentials = new SigningCredentials(
                TestSigningKey, SecurityAlgorithms.RsaSha256),
            // RFC 9068: access tokens should carry typ=at+jwt
            TokenType = "at+jwt"
        };

        var handler = new JsonWebTokenHandler();
        return handler.CreateToken(descriptor);
    }
}
```

Key points:
- `RSA.Create(2048)` wrapped in an `RsaSecurityKey` gives a **static** key held for the test run.
- `CreateAccessToken` takes **subject, audience, and claims** so each test shapes the identity.
- It uses `SecurityTokenDescriptor` + `JsonWebTokenHandler.CreateToken` to serialize the JWT.

## 2. WebApplicationFactory that trusts the test key

The API in `Program.cs` registers `AddJwtBearer("Bearer", ...)` bound to an `Authority`. In tests, replace those `JwtBearerOptions` with `TokenValidationParameters` pointing at the static key and audience `my-api`.

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Remove the production JWT Bearer configuration (Authority-based)
            var jwtDescriptor = services.FirstOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<JwtBearerOptions>));
            if (jwtDescriptor is not null)
                services.Remove(jwtDescriptor);

            // Re-register Bearer trusting the static test key
            services.AddAuthentication("Bearer")
                .AddJwtBearer("Bearer", options =>
                {
                    options.MapInboundClaims = false;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = TestTokenFactory.SigningKey, // the test key
                        ValidateIssuer = true,
                        ValidIssuer = "https://test-authority",
                        ValidateAudience = true,
                        ValidAudience = "my-api",                      // API audience
                        ValidateLifetime = true,
                        ClockSkew = TimeSpan.Zero
                    };
                });
        });
    }
}
```

## 3. Using it in a test

```csharp
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;

public class ProductsApiTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;

    public ProductsApiTests(ApiFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task GetProducts_WithValidToken_Returns200()
    {
        var token = TestTokenFactory.CreateAccessToken(
            subject: "user-123",
            audience: "my-api",
            claims: [new Claim("scope", "api1")]);

        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_WrongAudience_Returns401()
    {
        var token = TestTokenFactory.CreateAccessToken(
            subject: "user-123",
            audience: "wrong-api",           // fails ValidAudience = "my-api"
            claims: [new Claim("scope", "api1")]);

        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

## Why this works
- The token is signed with `TestSigningKey`, and the factory sets that same key as `IssuerSigningKey`, so signature validation passes.
- `ValidAudience = "my-api"` matches the API's expected audience — if the token's `aud` differs, validation fails and you get `401`, which is exactly what the wrong-audience test asserts.
- No IdentityServer host, no network, no certificate trust issues.
