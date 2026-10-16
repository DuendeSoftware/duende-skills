# Minimal in-process IdentityServer for integration tests

Host the real IdentityServer inside the test process with `WebApplicationFactory<Program>`. It runs on `TestServer`: no network, no ports, no certificate trust issues. Three essentials: **in-memory minimal config**, **static signing key with key management disabled**, and a visible `Program`.

```csharp
// In the IdentityServer host project
public partial class Program { }
```

```csharp
public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            // Remove existing IdentityServer options so we can replace the registration cleanly
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<IdentityServerOptions>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddIdentityServer(options =>
            {
                options.Events.RaiseErrorEvents = true;
                options.Events.RaiseFailureEvents = true;
                options.KeyManagement.Enabled = false;     // no key files on disk
            })
            .AddInMemoryClients(TestConfig.Clients)
            .AddInMemoryApiScopes(TestConfig.ApiScopes)
            .AddInMemoryApiResources(TestConfig.ApiResources)
            .AddInMemoryIdentityResources(TestConfig.IdentityResources)
            .AddTestUsers(TestConfig.Users)
            .AddDeveloperSigningCredential(persistKey: false);   // static dev key, tests only
        });
    }
}
```

A test:
```csharp
public class TokenEndpointTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;
    public TokenEndpointTests(IdentityServerFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task ClientCredentials_ShouldReturnAccessToken()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
            ClientId = "test.service",
            ClientSecret = "test-secret",
            Scope = "api1"
        });

        Assert.False(response.IsError, response.Error);
        Assert.NotEmpty(response.AccessToken!);
    }
}
```

Packages: `Microsoft.AspNetCore.Mvc.Testing`, `Duende.IdentityModel`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`.

Principles behind it:
1. **In-process authority** via `WebApplicationFactory` (deterministic, no ports).
2. **Predictable signing keys:** `KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)`.
3. **Minimal test clients:** register only what each test needs (a small `TestConfig` / builder).
4. **Don't mock the token pipeline;** mock only external I/O (DBs, downstream services).
5. Don't hard-code `localhost:5001`; use the client's `BaseAddress`.
