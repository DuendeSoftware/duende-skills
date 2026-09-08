Here's an xUnit fixture that boots the whole Aspire app (including IdentityServer), waits for IdentityServer to report healthy, and hands your tests helpers for the authority URL and a Weather API `HttpClient`. It uses `DistributedApplicationTestingBuilder` and implements `IAsyncLifetime` so setup/teardown run once for the test collection.

```csharp
using Aspire.Hosting;
using Aspire.Hosting.Testing;

public sealed class IdentityAspireFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        // Build the AppHost from its Projects marker type
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Block until IdentityServer's health check reports healthy,
        // so no test runs against a not-yet-ready identity provider.
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

    // Dynamic https://localhost:{port} authority assigned at runtime
    public Uri GetAuthorityUrl() =>
        _app!.GetEndpoint("identity-server", "https");

    // HttpClient pre-configured with the weather-api base address
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

## Why each piece matters

- **`DistributedApplicationTestingBuilder.CreateAsync<Projects.MyApp_AppHost>()`** loads your real AppHost graph in-process, so tests exercise the same orchestration (dependencies, `WaitFor`, environment variables) as production.
- **`WaitForResourceHealthyAsync("identity-server")`** is the crucial line: IdentityServer's port is dynamic and it isn't instantly ready. Waiting on its health status guarantees the discovery document and JWKS are serveable before any test starts. The resource name must match the name used in the AppHost (`"identity-server"`).
- **`GetEndpoint("identity-server", "https")`** returns the runtime authority URL — use it when configuring test token clients or `HttpClient`s that talk to IdentityServer directly.
- **`CreateHttpClient("weather-api")`** gives you a client already pointed at the API's dynamic base address, so you don't hard-code ports.
- **`DisposeAsync`** stops and disposes the `DistributedApplication` so containers/processes are torn down between runs.

## Using it in a test

```csharp
public class WeatherApiTests : IClassFixture<IdentityAspireFixture>
{
    private readonly IdentityAspireFixture _fixture;
    public WeatherApiTests(IdentityAspireFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task Weather_requires_a_token()
    {
        var client = _fixture.CreateApiClient();
        var response = await client.GetAsync("/weather");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        // Acquire a token from _fixture.GetAuthorityUrl() for the authorized case.
    }
}
```

Add the `Aspire.Hosting.Testing` package to the test project, and expose the AppHost's `Projects.*` marker (the AppHost project reference) so `CreateAsync<Projects.MyApp_AppHost>()` resolves.
