# In-Process IdentityServer for Integration Testing (Client Credentials)

Host a real IdentityServer inside the test process with `WebApplicationFactory<Program>`, override its configuration to use a **static signing key** and **in-memory test clients**, then request a token from `/connect/token`.

## 1. Test configuration (clients + scopes)

```csharp
using Duende.IdentityServer.Models;

public static class TestConfig
{
    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "Primary API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "test.service",
            ClientSecrets = { new Secret("test-secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    ];
}
```

## 2. The WebApplicationFactory hosting IdentityServer

```csharp
using Duende.IdentityServer.Configuration;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            // Remove any existing IdentityServer options registration to replace cleanly
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<IdentityServerOptions>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddIdentityServer(options =>
                {
                    options.Events.RaiseErrorEvents = true;
                    options.Events.RaiseFailureEvents = true;

                    // ✅ Disable automatic key management — no key files written in CI
                    options.KeyManagement.Enabled = false;
                })
                .AddInMemoryClients(TestConfig.Clients)
                .AddInMemoryApiScopes(TestConfig.ApiScopes)
                // ✅ Static developer signing key; do not persist to disk
                .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

Why these two lines matter:
- `options.KeyManagement.Enabled = false` stops IdentityServer's automatic key rotation from trying to **write key material to disk**, which breaks or flakes in CI.
- `AddDeveloperSigningCredential(persistKey: false)` supplies a **static** signing key generated fresh per run and never written to disk, so signatures are predictable and there are no leftover key files.

## 3. The client-credentials token test

```csharp
using Duende.IdentityModel.Client;
using Microsoft.AspNetCore.Mvc.Testing;

public class TokenEndpointTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenEndpointTests(IdentityServerFactory factory)
    {
        // BaseAddress is set by the factory — no hard-coded localhost ports
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
}
```

`RequestClientCredentialsTokenAsync` (from `Duende.IdentityModel`) posts to the in-process `/connect/token` endpoint; the test asserts the response `IsError` is `false` and that a non-empty `AccessToken` was issued.

## Notes
- Register only the clients/scopes each test needs — over-broad configs mask permission bugs.
- Because the factory sets `BaseAddress`, use `factory.CreateClient()` rather than hard-coding `localhost:5001`, which avoids port conflicts in CI.
