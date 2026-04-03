# Integration Test Fixture for Aspire with IdentityServer

Here's an xUnit test fixture that starts the Aspire AppHost, waits for IdentityServer to be healthy, and provides helper methods for tests:

```csharp
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

public sealed class IdentityAspireFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        // Build the AppHost using the testing builder
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Wait for IdentityServer to be healthy before running tests
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

    /// <summary>
    /// Gets the dynamic authority URL for IdentityServer.
    /// Use this to configure test clients with the correct OIDC authority.
    /// </summary>
    public Uri GetAuthorityUrl() =>
        _app!.GetEndpoint("identity-server", "https");

    /// <summary>
    /// Creates an HttpClient pre-configured with the Weather API's base address.
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

## How to use in tests

```csharp
public class WeatherApiTests : IClassFixture<IdentityAspireFixture>
{
    private readonly IdentityAspireFixture _fixture;

    public WeatherApiTests(IdentityAspireFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task GetWeather_ReturnsSuccess()
    {
        // The authority URL is dynamically assigned
        var authority = _fixture.GetAuthorityUrl();

        // HttpClient is pre-configured with the API's base address
        var client = _fixture.CreateApiClient();

        // You'd typically get a token from IdentityServer first,
        // then set the Authorization header
        var response = await client.GetAsync("/weatherforecast");
        // Assert...
    }
}
```

## Key implementation details

1. **`DistributedApplicationTestingBuilder.CreateAsync<Projects.MyApp_AppHost>()`** — Builds the same AppHost that runs in development, but configured for testing. This ensures the test exercises the real Aspire orchestration.

2. **`WaitForResourceHealthyAsync("identity-server")`** — Waits for IdentityServer to report healthy via its health check endpoint. The resource name `"identity-server"` must match the name used in `builder.AddProject<Projects.IdentityServer>("identity-server")` in the AppHost.

3. **`GetEndpoint("identity-server", "https")`** — Returns the dynamic `https://localhost:{port}` URL. Since Aspire assigns ports at runtime, you can't hard-code the authority URL in tests.

4. **`CreateHttpClient("weather-api")`** — Creates an `HttpClient` with the API's dynamic base address already set.

5. **`DisposeAsync`** calls both `StopAsync()` and `DisposeAsync()` on the `DistributedApplication` to properly clean up all resources (containers, processes, etc.).
