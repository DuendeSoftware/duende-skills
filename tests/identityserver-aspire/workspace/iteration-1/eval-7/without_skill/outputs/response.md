# Integration Test Fixture for Aspire

Here's a test fixture for testing an Aspire solution:

```csharp
using Aspire.Hosting.Testing;

public sealed class AppFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Wait for resources to be ready
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

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

This fixture starts the entire Aspire AppHost, waits for resources to be healthy, and provides methods to create HTTP clients for testing individual services.
