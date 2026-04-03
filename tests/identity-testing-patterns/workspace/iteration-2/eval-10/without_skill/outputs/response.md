# Minimal In-Process IdentityServer for Testing

Here's the minimal setup to host IdentityServer in-process for integration tests.

## WebApplicationFactory

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public class TestServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(new[]
                {
                    new Client
                    {
                        ClientId = "test.client",
                        AllowedGrantTypes = GrantTypes.ClientCredentials,
                        ClientSecrets = { new Secret("secret".Sha256()) },
                        AllowedScopes = { "api1" }
                    }
                })
                .AddInMemoryApiScopes(new[]
                {
                    new ApiScope("api1")
                })
                .AddDeveloperSigningCredential();
        });
    }
}
```

## Usage

```csharp
using IdentityModel.Client;
using Xunit;

public class BasicTests : IClassFixture<TestServerFactory>
{
    private readonly HttpClient _client;

    public BasicTests(TestServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CanGetToken()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = "https://localhost/connect/token",
                ClientId = "test.client",
                ClientSecret = "secret",
                Scope = "api1"
            });

        Assert.False(response.IsError, response.Error);
        Assert.NotEmpty(response.AccessToken);
    }
}
```

The key pieces are `WebApplicationFactory<Program>`, `ConfigureTestServices` to register IdentityServer with in-memory stores, `AddDeveloperSigningCredential()` for a test signing key, and `AddInMemoryClients` for test client registration.
