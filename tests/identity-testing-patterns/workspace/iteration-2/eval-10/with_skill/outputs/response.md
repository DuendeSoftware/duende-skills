# Minimal In-Process IdentityServer for Integration Testing

Here's the minimal pattern for hosting an in-process IdentityServer for integration testing.

## WebApplicationFactory

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer(options =>
            {
                // Disable automatic key management to avoid disk writes in CI
                options.KeyManagement.Enabled = false;
            })
            .AddInMemoryClients(new[]
            {
                new Client
                {
                    ClientId = "test.service",
                    AllowedGrantTypes = GrantTypes.ClientCredentials,
                    ClientSecrets = { new Secret("test-secret".Sha256()) },
                    AllowedScopes = { "api1" }
                }
            })
            .AddInMemoryApiScopes(new[]
            {
                new ApiScope("api1", "Test API")
            })
            .AddInMemoryIdentityResources(new IdentityResource[]
            {
                new IdentityResources.OpenId(),
                new IdentityResources.Profile()
            })
            // Static development signing key — not persisted to disk
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

## Usage in a Test

```csharp
using IdentityModel.Client;
using Xunit;

public class TokenEndpointTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenEndpointTests(IdentityServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task ClientCredentials_ShouldReturnAccessToken()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "api1"
            });

        Assert.False(response.IsError, response.Error);
        Assert.NotEmpty(response.AccessToken);
    }
}
```

Key points:
- `WebApplicationFactory<Program>` with `ConfigureTestServices` overrides the IdentityServer registration.
- `options.KeyManagement.Enabled = false` avoids disk writes in CI.
- `AddDeveloperSigningCredential(persistKey: false)` provides a static test signing key.
- `AddInMemoryClients` registers clients directly — no external configuration needed.
