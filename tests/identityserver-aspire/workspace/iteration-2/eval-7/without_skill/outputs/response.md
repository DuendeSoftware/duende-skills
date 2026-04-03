# Integration Test Fixture for Aspire

Here's a basic xUnit test fixture for integration testing an Aspire AppHost:

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Hosting;

public class AppHostFixture : IAsyncLifetime
{
    private IHost? _host;
    private HttpClient? _client;

    public async Task InitializeAsync()
    {
        // Start the AppHost
        var builder = Host.CreateDefaultBuilder()
            .ConfigureWebHostDefaults(webBuilder =>
            {
                webBuilder.UseStartup<Program>();
            });

        _host = builder.Build();
        await _host.StartAsync();

        // Give services time to start
        await Task.Delay(TimeSpan.FromSeconds(10));
    }

    public HttpClient GetApiClient()
    {
        return new HttpClient
        {
            BaseAddress = new Uri("https://localhost:5002")
        };
    }

    public string GetAuthorityUrl()
    {
        return "https://localhost:5001";
    }

    public async Task DisposeAsync()
    {
        if (_host is not null)
        {
            await _host.StopAsync();
            _host.Dispose();
        }
    }
}
```

## Usage

```csharp
public class ApiTests : IClassFixture<AppHostFixture>
{
    private readonly AppHostFixture _fixture;

    public ApiTests(AppHostFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task CanCallWeatherApi()
    {
        var client = _fixture.GetApiClient();
        var response = await client.GetAsync("/weatherforecast");
        response.EnsureSuccessStatusCode();
    }
}
```

## Notes

- The `Task.Delay` is a rough way to wait for services to start. In a production test setup, you'd want a more sophisticated health check polling mechanism.
- You'll need to configure the correct ports for your services. These are typically set in `launchSettings.json`.
- Make sure your IdentityServer is configured to use a test database or in-memory stores for integration tests.
