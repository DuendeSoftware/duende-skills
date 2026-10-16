```csharp
using Aspire.Hosting.Testing;

public class AspireFixture : IAsyncLifetime
{
    private DistributedApplication _app = default!;

    public async Task InitializeAsync()
    {
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();
        _app = await appHost.BuildAsync();
        await _app.StartAsync();

        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identityserver")
            .WaitAsync(TimeSpan.FromMinutes(2));
    }

    public string GetAuthority() =>
        _app.GetEndpoint("identityserver", "https").ToString().TrimEnd('/');

    public HttpClient CreateWeatherApiClient() => _app.CreateHttpClient("weatherapi");

    public async Task DisposeAsync()
    {
        await _app.DisposeAsync();
    }
}

[CollectionDefinition("Aspire")]
public class AspireCollection : ICollectionFixture<AspireFixture> { }
```

Use it from tests with `[Collection("Aspire")]` and a constructor-injected fixture. Reference `Aspire.Hosting.Testing` and the AppHost project in the test project.
