# Self-signed JWTs with a static RSA key

## TestTokenFactory
```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
    public const string Issuer = "https://test-issuer";
    public const string Audience = "my-api";

    private static readonly RSA Rsa = RSA.Create(2048);   // generated once per test run

    public static readonly RsaSecurityKey SigningKey = new(Rsa) { KeyId = "test-key" };

    public static string CreateToken(IEnumerable<Claim>? claims = null,
        string audience = Audience, string issuer = Issuer, TimeSpan? lifetime = null)
    {
        var creds = new SigningCredentials(SigningKey, SecurityAlgorithms.RsaSha256);
        var now = DateTime.UtcNow;
        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            notBefore: now.AddMinutes(-1),
            expires: now.Add(lifetime ?? TimeSpan.FromHours(1)),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
```
"Static" here means a static field, so the factory and the API share the same key within the test process. (You could also embed an exported PEM/XML key if you need a deterministic key across runs.)

## WebApplicationFactory
The API uses `Authority`, which would trigger metadata discovery. Clear it and set explicit validation parameters:

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
                options.Authority = null;
                options.MetadataAddress = null!;
                options.ConfigurationManager = null;
                options.Configuration = new Microsoft.IdentityModel.Protocols.OpenIdConnect.OpenIdConnectConfiguration
                {
                    Issuer = TestTokenFactory.Issuer
                };
                options.RequireHttpsMetadata = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = TestTokenFactory.Issuer,
                    ValidateAudience = true,
                    ValidAudience = "my-api",
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = TestTokenFactory.SigningKey,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.Zero
                };
            });
        });
    }
}
```
Setting `options.Configuration` with an issuer prevents any metadata fetch against `https://localhost:5001`.

Since `MapInboundClaims = false` in the API, claim names like `role` and `scope` stay as-is.

## Tests
```csharp
public class ApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public ApiTests(ApiFactory f) => _factory = f;

    private HttpClient ClientWith(params Claim[] claims)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new("Bearer", TestTokenFactory.CreateToken(claims));
        return client;
    }

    [Fact]
    public async Task Valid_token_with_scope_returns_200()
    {
        var client = ClientWith(new Claim("sub", "42"), new Claim("scope", "api1"));
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/products")).StatusCode);
    }

    [Fact]
    public async Task Admin_can_delete()
    {
        var client = ClientWith(new Claim("role", "admin"));
        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync("/api/products/1")).StatusCode);
    }

    [Fact]
    public async Task Wrong_audience_returns_401()
    {
        var client = _factory.CreateClient();
        var token = TestTokenFactory.CreateToken(new[] { new Claim("scope", "api1") }, audience: "other");
        client.DefaultRequestHeaders.Authorization = new("Bearer", token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/products")).StatusCode);
    }

    [Fact]
    public async Task Expired_token_returns_401()
    {
        var token = TestTokenFactory.CreateToken(new[] { new Claim("scope", "api1") }, lifetime: TimeSpan.FromMinutes(-5));
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/products")).StatusCode);
    }
}
```
Package needed in test project: `Microsoft.AspNetCore.Mvc.Testing` (and `System.IdentityModel.Tokens.Jwt` if not transitively available).
