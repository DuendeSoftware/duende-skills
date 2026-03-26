# In-Process IdentityServer Integration Testing

## 1. IdentityServer WebApplicationFactory

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
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
                options.Events.RaiseErrorEvents = true;
                options.Events.RaiseFailureEvents = true;

                // Disable automatic key management — use a static key for predictability
                options.KeyManagement.Enabled = false;
            })
            .AddInMemoryClients(new[]
            {
                new Client
                {
                    ClientId = "test.service",
                    ClientName = "Test Service",
                    AllowedGrantTypes = GrantTypes.ClientCredentials,
                    ClientSecrets = { new Secret("test-secret".Sha256()) },
                    AllowedScopes = { "api1" }
                }
            })
            .AddInMemoryApiScopes(new[]
            {
                new ApiScope("api1", "Test API")
            })
            .AddInMemoryApiResources(new[]
            {
                new ApiResource("api1-resource") { Scopes = { "api1" } }
            })
            .AddInMemoryIdentityResources(new IdentityResource[]
            {
                new IdentityResources.OpenId(),
                new IdentityResources.Profile()
            })
            // Static development signing key — no disk writes, predictable in CI
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

## 2. Test: Request Client Credentials Token

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
        Assert.NotNull(response.AccessToken);
        Assert.NotEmpty(response.AccessToken);
        Assert.Equal("Bearer", response.TokenType);
    }

    [Fact]
    public async Task ClientCredentials_InvalidClient_ShouldReturnError()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "nonexistent",
                ClientSecret = "wrong-secret",
                Scope = "api1"
            });

        Assert.True(response.IsError);
        Assert.Equal("invalid_client", response.Error);
    }
}
```

## Key Design Decisions

- **`KeyManagement.Enabled = false`**: Prevents the automatic key management system from trying to write key material to disk, which causes failures in CI environments
- **`AddDeveloperSigningCredential(persistKey: false)`**: Creates an in-memory RSA key that lives only for the test run — no `tempkey.jwk` file written to disk
- **`AddInMemoryClients`**: Test clients are defined inline for clarity; use `TestConfig.Clients` for shared definitions
- **`factory.CreateClient().BaseAddress`**: Use the factory-provided base address instead of hard-coding `localhost:5001`
