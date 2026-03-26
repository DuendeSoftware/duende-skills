# Integration Test Fixture for Aspire with IdentityServer

Here's a test fixture using xUnit's `IAsyncLifetime`:

```csharp
public class AspireTestFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Give IdentityServer time to start
        await Task.Delay(TimeSpan.FromSeconds(10));
    }

    public HttpClient CreateApiClient()
    {
        return _app!.CreateHttpClient("weather-api");
    }

    public string GetAuthorityUrl()
    {
        return "https://localhost:5001";
    }

    public async Task DisposeAsync()
    {
        if (_app is not null)
        {
            await _app.DisposeAsync();
        }
    }
}
```

This creates the AppHost, starts all services, waits a bit for everything to be ready, and provides helper methods for tests. The `CreateApiClient` method gives you an `HttpClient` configured for the weather API.
