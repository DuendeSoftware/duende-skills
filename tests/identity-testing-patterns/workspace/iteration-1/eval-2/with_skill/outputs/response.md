# Self-Signed JWT Token Factory for API Testing

## 1. TestTokenFactory

```csharp
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
    // Static key shared between the token factory and the test auth configuration
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

## 2. WebApplicationFactory Trusting the Test Key

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Remove production JWT Bearer configuration
            var jwtDescriptor = services.FirstOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<JwtBearerOptions>));
            if (jwtDescriptor is not null)
                services.Remove(jwtDescriptor);

            // Replace with test-friendly JWT Bearer that trusts our static key
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
using System.Net;
using System.Security.Claims;
using Xunit;

public class ApiTokenTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;

    public ApiTokenTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_WithValidToken_ShouldReturn200()
    {
        var token = TestTokenFactory.CreateAccessToken(
            subject: "user-123",
            audience: "my-api",
            claims: [new Claim("scope", "api1")]);

        _client.SetBearerToken(token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_WithoutToken_ShouldReturn401()
    {
        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```
