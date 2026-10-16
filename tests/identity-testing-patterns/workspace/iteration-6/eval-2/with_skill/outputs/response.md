# TestTokenFactory + trusting its key in the API's WebApplicationFactory

## TestTokenFactory (static RSA key, shared with the API config)
```csharp
using System.Security.Claims;
using System.Security.Cryptography;
using Duende.IdentityModel;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

public static class TestTokenFactory
{
    public const string Issuer = "https://test-authority";

    // Static key shared between the token factory and the API's test auth configuration
    private static readonly RsaSecurityKey TestSigningKey = CreateRsaKey();
    public static SecurityKey SigningKey => TestSigningKey;

    private static RsaSecurityKey CreateRsaKey() =>
        new(RSA.Create(2048)) { KeyId = "test-key-1" };

    public static string CreateAccessToken(
        string subject, string audience, IEnumerable<Claim> claims, TimeSpan? lifetime = null)
    {
        var allClaims = new List<Claim>
        {
            new(JwtClaimTypes.Subject, subject),
            new(JwtClaimTypes.JwtId, Guid.NewGuid().ToString())
        };
        allClaims.AddRange(claims);

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(allClaims),
            Audience = audience,
            Issuer = Issuer,
            Expires = DateTime.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(5)),
            SigningCredentials = new SigningCredentials(TestSigningKey, SecurityAlgorithms.RsaSha256),
            TokenType = "at+jwt"       // RFC 9068 access-token typ
        };

        return new JsonWebTokenHandler().CreateToken(descriptor);
    }
}
```

## Configure the API factory to trust the key
The API's `Program.cs` registers the `"Bearer"` scheme with an `Authority`. Registering `AddJwtBearer("Bearer")` a second time would throw (duplicate scheme), so I post-configure the existing options instead: remove the authority (no discovery call to `https://localhost:5001`) and supply explicit validation parameters.

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>("Bearer", options =>
            {
                options.Authority = null;
                options.MetadataAddress = null!;
                options.RequireHttpsMetadata = false;
                // Static configuration => no metadata retrieval
                options.Configuration = new OpenIdConnectConfiguration { Issuer = TestTokenFactory.Issuer };
                options.MapInboundClaims = false;       // keep "role"/"scope" claim names
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = TestTokenFactory.SigningKey,
                    ValidateIssuer = true,
                    ValidIssuer = TestTokenFactory.Issuer,
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

## Tests
```csharp
using Duende.IdentityModel.Client;   // SetBearerToken

public class ProductsApiTokenTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private HttpClient ClientWithToken(string audience, params Claim[] claims)
    {
        var client = factory.CreateClient();     // fresh client per test
        client.SetBearerToken(TestTokenFactory.CreateAccessToken("user-123", audience, claims));
        return client;
    }

    [Fact]
    public async Task ValidToken_WithScope_Returns200()
    {
        var client = ClientWithToken("my-api", new Claim("scope", "api1"), new Claim("role", "viewer"));
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/products")).StatusCode);
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await factory.CreateClient().GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ViewerRole_DeleteProduct_Returns403()
    {
        var client = ClientWithToken("my-api", new Claim("scope", "api1"), new Claim("role", "viewer"));
        Assert.Equal(HttpStatusCode.Forbidden, (await client.DeleteAsync("/api/products/1")).StatusCode);
    }

    [Fact]
    public async Task AdminRole_DeleteProduct_Returns204()
    {
        var client = ClientWithToken("my-api", new Claim("role", "admin"));
        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync("/api/products/1")).StatusCode);
    }

    [Fact]
    public async Task WrongAudience_Returns401()
    {
        // ❌ API expects "my-api"
        var client = ClientWithToken("wrong-api", new Claim("scope", "api1"));
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/products")).StatusCode);
    }
}
```

Notes:
- The **audience must match** `ValidAudience = "my-api"` — the most common cause of unexpected 401s.
- Static key = same `RsaSecurityKey` instance used to sign and validate, so no key rotation or network call is needed.
- Test project packages: `Microsoft.AspNetCore.Mvc.Testing`, `Duende.IdentityModel`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`.
