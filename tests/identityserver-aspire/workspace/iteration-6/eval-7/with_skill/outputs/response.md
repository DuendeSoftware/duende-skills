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
            .WaitForResourceHealthyAsync("identity-server")
            .WaitAsync(TimeSpan.FromMinutes(2));
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

[CollectionDefinition("Aspire")]
public class AspireCollection : ICollectionFixture<IdentityAspireFixture>;
```

Notes:
- The resource name must match the AppHost name (`identity-server`, `weather-api`).
- The authority uses a dynamic port, so tests must get it from `GetEndpoint`.
- `WaitForResourceHealthyAsync` needs IdentityServer to expose `/health`.
- `CreateHttpClient` returns a client with the API's dynamic base address.
