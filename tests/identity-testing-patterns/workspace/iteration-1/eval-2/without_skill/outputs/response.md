# Creating Self-Signed JWTs for Testing

## Token Factory

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

public static class TestTokenFactory
{
    private static readonly RSA _rsa = RSA.Create(2048);
    private static readonly RsaSecurityKey _key = new(_rsa) { KeyId = "test-key" };

    public static SecurityKey SigningKey => _key;

    public static string CreateAccessToken(string subject, string audience, IEnumerable<Claim> claims)
    {
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, subject)
            }.Concat(claims)),
            Audience = audience,
            Issuer = "https://test-issuer",
            Expires = DateTime.UtcNow.AddMinutes(5),
            SigningCredentials = new SigningCredentials(_key, SecurityAlgorithms.RsaSha256)
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(tokenDescriptor);
        return handler.WriteToken(token);
    }
}
```

## Configure API to Trust Test Key

```csharp
public class TestApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>("Bearer", options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    IssuerSigningKey = TestTokenFactory.SigningKey,
                    ValidIssuer = "https://test-issuer",
                    ValidAudience = "my-api",
                    ValidateLifetime = true
                };
            });
        });
    }
}
```

## Test Example

```csharp
[Fact]
public async Task GetProducts_WithToken_Returns200()
{
    var token = TestTokenFactory.CreateAccessToken("user-1", "my-api",
        new[] { new Claim("scope", "api1") });

    _client.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", token);

    var response = await _client.GetAsync("/api/products");
    Assert.Equal(HttpStatusCode.OK, response.StatusCode);
}
```
