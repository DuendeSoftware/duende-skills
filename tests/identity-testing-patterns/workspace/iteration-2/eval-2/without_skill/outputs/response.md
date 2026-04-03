# Creating Self-Signed JWT Tokens for Testing

Here's how to create a token factory that generates JWTs with a static RSA key and configure your API to trust it.

## Token Factory

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

public static class TestJwtGenerator
{
    private static readonly RSA Rsa = RSA.Create(2048);
    private static readonly RsaSecurityKey Key = new(Rsa) { KeyId = "test-key" };

    public static SecurityKey SigningKey => Key;

    public static string CreateToken(string subject, string audience, IEnumerable<Claim> claims, int expiresInMinutes = 5)
    {
        var allClaims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, subject),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        allClaims.AddRange(claims);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(allClaims),
            Audience = audience,
            Issuer = "https://test-issuer",
            Expires = DateTime.UtcNow.AddMinutes(expiresInMinutes),
            SigningCredentials = new SigningCredentials(Key, SecurityAlgorithms.RsaSha256)
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(tokenDescriptor);
        return handler.WriteToken(token);
    }
}
```

## Configure WebApplicationFactory to Trust the Key

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

public class TestApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>("Bearer", options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = TestJwtGenerator.SigningKey,
                    ValidateIssuer = true,
                    ValidIssuer = "https://test-issuer",
                    ValidateAudience = true,
                    ValidAudience = "my-api",
                    ValidateLifetime = true
                };
            });
        });
    }
}
```

## Usage

```csharp
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using Xunit;

public class TokenTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public TokenTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task WithValidToken_ReturnsSuccess()
    {
        var token = TestJwtGenerator.CreateToken(
            "user-1", "my-api",
            new[] { new Claim("scope", "api1") });

        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

The factory uses `PostConfigure` to override the JWT Bearer options with test-friendly token validation parameters pointing to your static RSA key.
