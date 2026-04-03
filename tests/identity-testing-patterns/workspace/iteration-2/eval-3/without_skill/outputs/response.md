# In-Process IdentityServer Integration Testing

To test client credentials token issuance against IdentityServer, you can host it in-process using `WebApplicationFactory`.

## Test Configuration

```csharp
using Duende.IdentityServer.Models;

public static class TestClients
{
    public static IEnumerable<Client> Clients => new[]
    {
        new Client
        {
            ClientId = "test.service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("test-secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    };

    public static IEnumerable<ApiScope> Scopes => new[]
    {
        new ApiScope("api1", "Test API")
    };
}
```

## WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public class IdServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Test");

        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(TestClients.Clients)
                .AddInMemoryApiScopes(TestClients.Scopes)
                .AddDeveloperSigningCredential();
        });
    }
}
```

## Test

```csharp
using IdentityModel.Client;
using Xunit;

public class ClientCredentialsTests : IClassFixture<IdServerFactory>
{
    private readonly HttpClient _client;

    public ClientCredentialsTests(IdServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CanGetAccessToken()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = "https://localhost/connect/token",
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "api1"
            });

        Assert.False(response.IsError, response.Error);
        Assert.NotEmpty(response.AccessToken);
    }
}
```

This sets up IdentityServer in-memory using `WebApplicationFactory`, registers a test client for client credentials flow, and uses `RequestClientCredentialsTokenAsync` from IdentityModel to request a token. The test verifies the token response is successful with a non-empty access token.
