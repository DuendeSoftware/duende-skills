# Blazor WASM + BFF integration

You need BFF's Blazor client support on **both** ends: `.AddBffBlazorClient()` on the server, and `AddBffBlazorClient(...)` plus a typed local-API client on the WASM side.

```bash
# Server host
dotnet add package Duende.BFF
dotnet add package Duende.BFF.Blazor
# WASM client
dotnet add package Duende.BFF.Blazor.Client
```

## Server-side `Program.cs`

```csharp
using Duende.Bff;
using Duende.Bff.Blazor;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority    = builder.Configuration["Oidc:Authority"];
        options.ClientId     = builder.Configuration["Oidc:ClientId"];
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.SaveTokens   = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .AddBffBlazorClient();   // ✅ server-side Blazor BFF integration

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// ✅ Local API the WeatherClient will call through the BFF host
app.MapGet("/api/weather", () => new[] { new { day = "Mon", tempC = 21 } })
    .RequireAuthorization()
    .AsBffApiEndpoint();

app.Run();
```

## Client-side (WASM) `Program.cs`

```csharp
using Duende.Bff.Blazor.Client;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(options =>
{
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromSeconds(30)   // ✅ 30-second session polling
    };
});

// ✅ Typed client for local API calls routed through the BFF host
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```

```csharp
// WeatherClient.cs
public class WeatherClient
{
    private readonly HttpClient _http;
    public WeatherClient(HttpClient http) => _http = http;

    public async Task<WeatherForecast[]?> GetForecastAsync() =>
        await _http.GetFromJsonAsync<WeatherForecast[]>("api/weather");
}

public record WeatherForecast(string Day, int TempC);
```

## Why it's set up this way

- **`.AddBffBlazorClient()` (server)** wires BFF's session/auth state so the WASM app can observe login state via the BFF.
- **`AddBffBlazorClient(...)` (client)** provides the `AuthenticationStateProvider` backed by `/bff/user`, and the polling interval controls how often it re-checks the session — set here to 30 seconds (the default is 5).
- **`AddLocalApiHttpClient<WeatherClient>()`** creates a typed `HttpClient` whose base address is the BFF host, so `WeatherClient` calls `/api/weather` through the BFF (with the session cookie and CSRF handling in place) — you don't manage tokens in the browser at all.
