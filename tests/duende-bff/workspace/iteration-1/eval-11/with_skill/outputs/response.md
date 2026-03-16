# Blazor WASM + BFF Integration

## Server-Side Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "blazor-wasm";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;

        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
    })
    .AddBffBlazorClient(); // Integrates BFF session management with Blazor WASM

builder.Services.AddAuthorization();
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyRenderMode();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode();

app.Run();
```

Key points on the server side:
- `AddBff().ConfigureOpenIdConnect(...)` sets up the BFF with OIDC authentication using the V4 fluent API.
- `.AddBffBlazorClient()` integrates BFF session management with the Blazor WASM client. This ensures the WASM client can check authentication state and route API calls through the BFF host.

## Client-Side Program.cs (WASM Project)

```csharp
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(options =>
{
    options.RemoteApiPath = "/api/remote";
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromSeconds(30) // Poll session status every 30 seconds (default is 5s)
    };
});

// Typed HTTP client that routes through the BFF host — CSRF headers are added automatically
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```

Key points on the client side:
- `AddBffBlazorClient` configures the WASM app to communicate with the BFF host for authentication state. The `Polling.Interval` controls how often the client checks `/bff/user` to detect session expiry.
- `AddLocalApiHttpClient<WeatherClient>()` creates a typed HTTP client that automatically routes requests through the BFF host and includes the required `X-CSRF: 1` header. Use this for calling local BFF API endpoints from your Blazor components.

## WeatherClient Example

```csharp
public class WeatherClient
{
    private readonly HttpClient _httpClient;

    public WeatherClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<WeatherForecast[]?> GetForecastAsync()
    {
        return await _httpClient.GetFromJsonAsync<WeatherForecast[]>("/api/weather");
    }
}
```

The `WeatherClient` is a standard typed HTTP client — the BFF infrastructure handles token management and CSRF headers transparently.
