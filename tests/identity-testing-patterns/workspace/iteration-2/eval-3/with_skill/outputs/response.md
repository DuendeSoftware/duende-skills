# In-Process IdentityServer Integration Testing

Here's how to set up an in-process IdentityServer using `WebApplicationFactory` for integration testing with client credentials token issuance.

## 1. Test Configuration

```csharp
using Duende.IdentityServer.Models;

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
        new ApiResource("api1-resource", "API 1")
        {
            Scopes = { "api1" }
        }
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
using Duende.IdentityServer;
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

## 3. Token Endpoint Integration Tests

```csharp
using System.Net;
using IdentityModel.Client;
using Xunit;

[Collection("IdentityServer")]
public class ClientCredentialsTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public ClientCredentialsTests(IdentityServerFactory factory)
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
        Assert.Equal("Bearer", response.TokenType);
    }

    [Fact]
    public async Task ClientCredentials_InvalidSecret_ShouldFail()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "wrong-secret",
                Scope = "api1"
            });

        Assert.True(response.IsError);
    }
}
```

Key points:
- `options.KeyManagement.Enabled = false` disables automatic key management, avoiding disk writes and CI failures.
- `AddDeveloperSigningCredential(persistKey: false)` provides a static signing key for deterministic test token signatures.
- `AddInMemoryClients` registers the test client for client credentials flow.
- The test uses `RequestClientCredentialsTokenAsync` from IdentityModel to hit the in-process `/connect/token` endpoint.
- The response is verified to not be an error and to contain a non-empty `AccessToken`.
