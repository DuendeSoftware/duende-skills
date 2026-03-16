# Integration Test Fixture for Aspire + IdentityServer

Here's an xUnit test fixture that starts the Aspire AppHost, waits for IdentityServer to be healthy, and provides helper methods:

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

        // Wait for IdentityServer to be healthy before running tests
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

    public Uri GetAuthorityUrl() =>
        _app!.GetEndpoint("identity-server", "https");

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

    public WeatherApiTests(IdentityAspireFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task GetWeather_WithoutToken_Returns401()
    {
        var client = _fixture.CreateApiClient();
        var response = await client.GetAsync("/weatherforecast");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

## Key Points

- **`IAsyncLifetime`** — The fixture implements `InitializeAsync` and `DisposeAsync` for async setup/teardown.
- **`DistributedApplicationTestingBuilder.CreateAsync`** — Builds the AppHost from the project reference.
- **`WaitForResourceHealthyAsync("identity-server")`** — Blocks until IdentityServer's health check returns healthy. The resource name must match the name used in the AppHost.
- **`GetEndpoint("identity-server", "https")`** — Returns the dynamic `https://localhost:{port}` URL assigned at runtime.
- **`CreateHttpClient("weather-api")`** — Creates an HttpClient pre-configured with the API's base address.
- **`DisposeAsync`** — Calls `StopAsync` and `DisposeAsync` on the app to clean up resources.
