Here's the setup for Blazor WASM with BFF integration:

## Server-Side Program.cs (BFF Host)

```csharp
// Server/Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "blazor-wasm";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    })
    .AddBffBlazorClient(); // Registers BFF Blazor client support on the server

builder.Services.AddAuthorization();
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyRenderMode();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode();

app.Run();
```

## Client-Side Program.cs (Blazor WASM Project)

```csharp
// Client/Program.cs
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(options =>
{
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromSeconds(30)  // Poll session status every 30 seconds
    };
});

// Typed HTTP client for local API calls — routes through the BFF host
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```

Key points:

1. **Server-side `.AddBffBlazorClient()`** — Registers the server-side infrastructure for BFF Blazor client integration, including session state synchronization endpoints.

2. **Client-side `AddBffBlazorClient`** — Sets up the WASM client to communicate with the BFF host for authentication state. The polling interval controls how often the client checks if the session is still valid.

3. **`AddLocalApiHttpClient<WeatherClient>()`** — Creates a typed HTTP client that automatically routes API calls through the BFF host with the appropriate anti-forgery headers.

4. **Polling interval of 30 seconds** — The default is 5 seconds. Setting it to 30 seconds reduces network traffic at the cost of slightly delayed session expiry detection.
