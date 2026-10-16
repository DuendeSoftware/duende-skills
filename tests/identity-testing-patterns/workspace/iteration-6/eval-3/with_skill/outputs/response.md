# In-process IdentityServer with WebApplicationFactory (client credentials)

Note: the `Program.cs` you showed is a protected *API*, not an IdentityServer. This pattern hosts a Duende IdentityServer host project's `Program` (expose it with `public partial class Program { }`) in-process via `WebApplicationFactory<Program>`: no network, no port conflicts, no cert trust problems.

## Packages
```xml
<ItemGroup>
  <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="*" />
  <PackageReference Include="Duende.IdentityModel" Version="*" />
  <PackageReference Include="xunit" Version="*" />
  <PackageReference Include="xunit.runner.visualstudio" Version="*" />
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="*" />
</ItemGroup>
<ItemGroup>
  <ProjectReference Include="..\IdentityServerHost\IdentityServerHost.csproj" />
</ItemGroup>
```
(If the IdentityServer host is a Web SDK project, make the test project `Microsoft.NET.Sdk.Web` too.)

## Test configuration (minimal clients/scopes, builders)
```csharp
public static class TestConfig
{
    public static IEnumerable<Client> Clients =>
    [
        ClientBuilder.ClientCredentials("test.service", "test-secret")
            .WithScopes("api1", "api2.read")
            .Build()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "Primary API"),
        new ApiScope("api2.read", "Read from API 2")
    ];

    public static IEnumerable<ApiResource> ApiResources =>
    [
        new ApiResource("api1-resource", "API 1 Resource") { Scopes = { "api1" } }
    ];

    public static IEnumerable<IdentityResource> IdentityResources => [ new IdentityResources.OpenId() ];
}

public sealed class ClientBuilder
{
    private readonly Client _client = new();

    public static ClientBuilder ClientCredentials(string clientId, string secret)
    {
        var b = new ClientBuilder();
        b._client.ClientId = clientId;
        b._client.AllowedGrantTypes = GrantTypes.ClientCredentials;
        b._client.ClientSecrets = [new Secret(secret.Sha256())];
        return b;
    }

    public ClientBuilder WithScopes(params string[] scopes)
    {
        foreach (var s in scopes) _client.AllowedScopes.Add(s);
        return this;
    }

    public Client Build() => _client;
}
```

## Factory
```csharp
public sealed class IdentityServerFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            // Remove existing IdentityServer option configuration so we can replace it cleanly
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IConfigureOptions<IdentityServerOptions>));
            if (descriptor is not null)
                services.Remove(descriptor);

            services.AddIdentityServer(options =>
            {
                options.Events.RaiseErrorEvents = true;
                options.Events.RaiseFailureEvents = true;

                // ✅ No automatic key management => no key files written to disk (CI-safe)
                options.KeyManagement.Enabled = false;
            })
            .AddInMemoryClients(TestConfig.Clients)
            .AddInMemoryApiScopes(TestConfig.ApiScopes)
            .AddInMemoryApiResources(TestConfig.ApiResources)
            .AddInMemoryIdentityResources(TestConfig.IdentityResources)
            // Static dev signing key; never for production
            .AddDeveloperSigningCredential(persistKey: false);
        });
    }
}
```

## Tests
```csharp
using Duende.IdentityModel.Client;

public class TokenEndpointTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenEndpointTests(IdentityServerFactory factory) => _client = factory.CreateClient();

    // ✅ Build the address from the test server's BaseAddress; never hard-code localhost:5001
    private string TokenAddress => new Uri(_client.BaseAddress!, "connect/token").ToString();

    [Fact]
    public async Task ClientCredentials_ShouldReturnAccessToken()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = TokenAddress,
            ClientId = "test.service",
            ClientSecret = "test-secret",
            Scope = "api1"
        });

        Assert.False(response.IsError, response.Error);
        Assert.NotEmpty(response.AccessToken!);
        Assert.Equal("Bearer", response.TokenType);
    }

    [Fact]
    public async Task ClientCredentials_InvalidScope_ShouldReturnInvalidScope()
    {
        var response = await _client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = TokenAddress,
            ClientId = "test.service",
            ClientSecret = "test-secret",
            Scope = "not.allowed"      // ❌ not granted to this client
        });

        Assert.True(response.IsError);
        Assert.Equal("invalid_scope", response.Error);
    }
}
```

Why this shape:
- **Predictable keys:** `KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)`.
- **Minimal clients:** only what the tests need, so permission bugs aren't masked.
- **Integration over mocking:** the real token pipeline runs; nothing in it is mocked.
- If you run tests in parallel, avoid mutating shared static config; use a fresh factory per test class.
