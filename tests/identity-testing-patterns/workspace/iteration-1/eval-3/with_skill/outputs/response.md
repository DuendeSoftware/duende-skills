# In-Process IdentityServer Integration Testing with WebApplicationFactory

## 1. Test Configuration

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer;

public static class TestConfig
{
    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "test.service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("test-secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "Test API")
    ];

    public static IEnumerable<ApiResource> ApiResources =>
    [
        new ApiResource("api1-resource") { Scopes = { "api1" } }
    ];

    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];
}
```

## 2. IdentityServer WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Duende.IdentityServer;

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
            .AddInMemoryClients(TestConfig.Clients)
            .AddInMemoryApiScopes(TestConfig.ApiScopes)
            .AddInMemoryApiResources(TestConfig.ApiResources)
            .AddInMemoryIdentityResources(TestConfig.IdentityResources)
            // Static development signing key — never persists to disk
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

## 3. Client Credentials Token Test

```csharp
using IdentityModel.Client;
using Xunit;

[Collection("IdentityServer")]
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
    public async Task ClientCredentials_InvalidScope_ShouldReturnError()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "not.allowed"
            });

        Assert.True(response.IsError);
        Assert.Equal("invalid_scope", response.Error);
    }
}
```

**Key points:**
- `options.KeyManagement.Enabled = false` prevents automatic key management from writing files to disk in CI.
- `AddDeveloperSigningCredential(persistKey: false)` provides a static signing key without file persistence.
- `AddInMemoryClients(TestConfig.Clients)` registers test clients in-memory.
- `RequestClientCredentialsTokenAsync` from the IdentityModel library is used to request tokens.
- The token response is verified to not be an error and to contain a non-empty `AccessToken`.
