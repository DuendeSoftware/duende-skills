# Issuing Self-Signed JWTs for API Integration Tests

You can test your protected API without a real token service by generating JWTs in the test project with a fixed RSA key, and telling the API to validate against that key. Below is a `TestTokenFactory` and the `WebApplicationFactory` wiring for audience `my-api`.

## TestTokenFactory

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
    // Static signing key reused for the whole test run
    private static readonly RsaSecurityKey SigningKeyInternal =
        new(RSA.Create(2048)) { KeyId = "test-key" };

    public static SecurityKey SigningKey => SigningKeyInternal;

    public static string CreateAccessToken(
        string subject,
        string audience,
        IEnumerable<Claim> claims)
    {
        var tokenClaims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, subject),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        tokenClaims.AddRange(claims);

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(tokenClaims),
            Audience = audience,
            Issuer = "https://test-issuer",
            Expires = DateTime.UtcNow.AddMinutes(10),
            SigningCredentials = new SigningCredentials(
                SigningKeyInternal, SecurityAlgorithms.RsaSha256)
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(descriptor);
        return handler.WriteToken(token);
    }
}
```

- `RSA.Create(2048)` produces the static RSA key wrapped in an `RsaSecurityKey`.
- `CreateAccessToken(subject, audience, claims)` accepts the three parameters you need to shape a token.
- It builds a `SecurityTokenDescriptor` and serializes it via `JwtSecurityTokenHandler`.

## WebApplicationFactory that trusts the key

Your `Program.cs` uses `AddJwtBearer` with an `Authority`. Override it in tests so it validates against the static key and the `my-api` audience:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>("Bearer", options =>
            {
                options.Authority = null;      // no metadata lookup in tests
                options.RequireHttpsMetadata = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = TestTokenFactory.SigningKey,
                    ValidateIssuer = true,
                    ValidIssuer = "https://test-issuer",
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

`PostConfigure<JwtBearerOptions>("Bearer", ...)` replaces the token validation parameters for the existing `"Bearer"` scheme, setting `IssuerSigningKey` to the test key and `ValidAudience` to `my-api`.

## Test example

```csharp
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;

public class ApiTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;
    public ApiTests(ApiFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task ValidToken_Returns200()
    {
        var token = TestTokenFactory.CreateAccessToken(
            "user-1", "my-api", new[] { new Claim("scope", "api1") });

        _client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

## Notes
- Keep the signing key static/shared so the issued token and the validator agree.
- Match `ValidAudience` to the API audience (`my-api`); a mismatch yields `401`.
- `ClockSkew = TimeSpan.Zero` makes expiry deterministic in tests.
