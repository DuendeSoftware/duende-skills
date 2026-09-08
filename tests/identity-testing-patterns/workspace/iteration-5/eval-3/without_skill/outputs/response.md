# Hosting IdentityServer In-Process for Integration Tests

You can host Duende IdentityServer inside your test process with `WebApplicationFactory<Program>`, override the DI registration to use in-memory test clients and a developer signing key, then request a client-credentials token from `/connect/token`.

## 1. Test client / scope configuration

```csharp
using Duende.IdentityServer.Models;

public static class TestConfig
{
    public static IEnumerable<ApiScope> ApiScopes => new[]
    {
        new ApiScope("api1", "Test API")
    };

    public static IEnumerable<Client> Clients => new[]
    {
        new Client
        {
            ClientId = "test-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    };
}
```

## 2. WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            services.AddIdentityServer()
                .AddInMemoryClients(TestConfig.Clients)
                .AddInMemoryApiScopes(TestConfig.ApiScopes)
                // Developer signing credential for tests
                .AddDeveloperSigningCredential();
        });
    }
}
```

## 3. Test that requests a token

```csharp
using IdentityModel.Client;
using Microsoft.AspNetCore.Mvc.Testing;

public class TokenTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenTests(IdentityServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Can_get_client_credentials_token()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = "connect/token",
                ClientId = "test-client",
                ClientSecret = "secret",
                Scope = "api1"
            });

        Assert.False(response.IsError, response.Error);
        Assert.False(string.IsNullOrEmpty(response.AccessToken));
    }
}
```

## Notes
- `AddInMemoryClients` / `AddInMemoryApiScopes` register the test client and scope without a database.
- `RequestClientCredentialsTokenAsync` (from the IdentityModel client library) posts to `/connect/token`.
- The test asserts `IsError` is false and the `AccessToken` is non-empty.
- `AddDeveloperSigningCredential()` provides a signing key suitable for local/test use so tokens can be signed and validated.
- Using `factory.CreateClient()` means requests go to the in-memory server rather than a real port.
