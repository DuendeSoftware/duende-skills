# TestTokenFactory for Self-Signed JWT Tokens

## 1. TestTokenFactory

```csharp
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
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
            new(JwtClaimTypes.Subject, subject),
            new(JwtClaimTypes.JwtId, Guid.NewGuid().ToString())
        };
        allClaims.AddRange(claims);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(allClaims),
            Audience = audience,
            Issuer = "https://test-authority",
            Expires = DateTime.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(5)),
            SigningCredentials = new SigningCredentials(
                TestSigningKey,
                SecurityAlgorithms.RsaSha256),
            TokenType = "at+jwt"
        };

        var handler = new JsonWebTokenHandler();
        return handler.CreateToken(tokenDescriptor);
    }
}
```

## 2. WebApplicationFactory — Trust the Test Key

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
            // Remove the production JWT Bearer configuration
            var jwtDescriptor = services.FirstOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<JwtBearerOptions>));
            if (jwtDescriptor is not null)
                services.Remove(jwtDescriptor);

            // Replace with test-friendly JWT Bearer trusting our static key
            services.AddAuthentication("Bearer")
                .AddJwtBearer("Bearer", options =>
                {
                    options.MapInboundClaims = false;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = TestTokenFactory.SigningKey,
                        ValidateIssuer = true,
                        ValidIssuer = "https://test-authority",
                        ValidateAudience = true,
                        ValidAudience = "my-api",
                        ValidateLifetime = true,
                        ClockSkew = TimeSpan.Zero
                    };
                });
        });
    }
}
```

## 3. Example Tests

```csharp
public class ProductsApiTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;

    public ProductsApiTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_WithValidToken_ShouldReturn200()
    {
        var token = TestTokenFactory.CreateAccessToken(
            subject: "user-123",
            audience: "my-api",
            claims: new[] { new Claim("scope", "api1") });

        _client.SetBearerToken(token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_WithWrongAudience_ShouldReturn401()
    {
        var token = TestTokenFactory.CreateAccessToken(
            subject: "user-123",
            audience: "wrong-api",
            claims: new[] { new Claim("scope", "api1") });

        _client.SetBearerToken(token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```
