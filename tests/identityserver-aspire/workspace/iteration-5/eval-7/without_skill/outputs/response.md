Below is an xUnit fixture built on Aspire's testing support (`Aspire.Hosting.Testing`). It starts the AppHost, waits for IdentityServer to become healthy, and exposes helpers for the authority URL and a Weather API client. Implementing `IAsyncLifetime` means the app is started once and disposed once for the tests that use the fixture.

```csharp
using System.Net.Http;
using Aspire.Hosting;
using Aspire.Hosting.Testing;
using Xunit;

public sealed class AspireAppFixture : IAsyncLifetime
{
    private DistributedApplication? _app;

    public async Task InitializeAsync()
    {
        // Spin up the real AppHost in-process for testing
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.AppHost>();

        _app = await builder.BuildAsync();
        await _app.StartAsync();

        // Wait until IdentityServer reports healthy before tests run
        await _app.ResourceNotifications
            .WaitForResourceHealthyAsync("identity-server");
    }

    // Runtime authority URL (dynamic port) for IdentityServer
    public Uri GetAuthorityUrl() =>
        _app!.GetEndpoint("identity-server", "https");

    // HttpClient wired to the weather API's base address
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

### How it works

- **`DistributedApplicationTestingBuilder.CreateAsync<Projects.AppHost>()`** loads your AppHost definition, so the test runs the same resource graph you deploy. Replace `Projects.AppHost` with your AppHost's generated marker type.
- **`WaitForResourceHealthyAsync("identity-server")`** pauses until IdentityServer's health check passes. Because ports are assigned dynamically and startup isn't instantaneous, this avoids flaky tests that hit the identity endpoints too early. The name must match the resource name in the AppHost.
- **`GetEndpoint("identity-server", "https")`** returns the actual `https://localhost:{port}` authority, which you use to request tokens or configure OIDC in tests.
- **`CreateHttpClient("weather-api")`** builds a client already targeting the API's dynamic address.
- **`DisposeAsync`** calls `StopAsync` and `DisposeAsync` on the application to release processes/containers.

### Example usage

```csharp
public class WeatherApiTests : IClassFixture<AspireAppFixture>
{
    private readonly AspireAppFixture _fixture;
    public WeatherApiTests(AspireAppFixture fixture) => _fixture = fixture;

    [Fact]
    public async Task Unauthenticated_request_is_rejected()
    {
        var client = _fixture.CreateApiClient();
        var res = await client.GetAsync("/weatherforecast");
        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, res.StatusCode);
    }
}
```

Reference the `Aspire.Hosting.Testing` NuGet package and add a project reference to the AppHost so the `Projects.*` marker type is generated.
