# Aspire Integration Test Fixture with IdentityServer

Here's a complete xUnit test fixture that starts the Aspire AppHost and waits for IdentityServer to be healthy:

```csharp
using Aspire.Hosting.Testing;

public sealed class IdentityAspireFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Wait for IdentityServer to be fully healthy before running tests
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

    /// <summary>
    /// Gets the dynamic HTTPS authority URL for IdentityServer.
    /// Use this when configuring test HttpClients for token validation.
    /// </summary>
    public Uri GetAuthorityUrl() =>
        _app!.GetEndpoint("identity-server", "https");

    /// <summary>
    /// Creates an HttpClient pre-configured with the weather API's base address.
    /// </summary>
    public HttpClient CreateApiClient() =>
        _app!.CreateHttpClient("weather-api");

    public async Task DisposeAsync()
    {
        if (_app is not null)
        {
            await _app.StopAsync();
            await _app.DisposeAsync();
        }
    }
}
```

## Usage in Tests

```csharp
public class WeatherApiTests : IClassFixture<IdentityAspireFixture>
{
    private readonly IdentityAspireFixture _fixture;

    public WeatherApiTests(IdentityAspireFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task GetWeather_WithValidToken_ReturnsSuccess()
    {
        var client = _fixture.CreateApiClient();
        // The authority URL uses a dynamic port assigned at runtime
        var authority = _fixture.GetAuthorityUrl();

        // Use the authority to obtain a test token, then call the API
        // ...
    }
}
```

## Key Design Decisions

1. **`WaitForResourceHealthyAsync("identity-server")`** - The resource name must match the name used in the AppHost (`builder.AddProject<...>("identity-server")`). This waits until IdentityServer's health check returns healthy, ensuring the discovery document and JWKS endpoints are available.

2. **`GetEndpoint("identity-server", "https")`** - Returns the dynamic `https://localhost:{port}` URL. This is essential because Aspire assigns random ports at runtime. Hardcoding ports in tests would be fragile.

3. **`CreateHttpClient("weather-api")`** - Creates a client pre-configured with the API's dynamic base address. No manual URL construction needed.

4. **`StopAsync` + `DisposeAsync`** - Both are called in cleanup to ensure the AppHost shuts down gracefully and resources are released.
