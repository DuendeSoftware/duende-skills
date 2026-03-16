# In-Process IdentityServer Integration Testing

## 1. WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public class IdentityServerTestFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(new[]
                {
                    new Duende.IdentityServer.Models.Client
                    {
                        ClientId = "test-client",
                        AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.ClientCredentials,
                        ClientSecrets = { new Duende.IdentityServer.Models.Secret("secret".Sha256()) },
                        AllowedScopes = { "api1" }
                    }
                })
                .AddInMemoryApiScopes(new[]
                {
                    new Duende.IdentityServer.Models.ApiScope("api1")
                })
                .AddDeveloperSigningCredential();
        });
    }
}
```

## 2. Token Endpoint Test

```csharp
using IdentityModel.Client;
using Xunit;

public class TokenTests : IClassFixture<IdentityServerTestFactory>
{
    private readonly HttpClient _client;

    public TokenTests(IdentityServerTestFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CanGetClientCredentialsToken()
    {
        var disco = await _client.GetDiscoveryDocumentAsync();

        var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = disco.TokenEndpoint,
                ClientId = "test-client",
                ClientSecret = "secret",
                Scope = "api1"
            });

        Assert.False(tokenResponse.IsError);
        Assert.NotNull(tokenResponse.AccessToken);
    }
}
```

This sets up an in-process IdentityServer with a test client and makes a client credentials token request.
