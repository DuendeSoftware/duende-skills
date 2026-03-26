# Blazor WASM with BFF Integration

## Server-Side Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "blazor-wasm-bff";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
        options.Scope.Add("api1");
    })
    .AddBffBlazorClient();

builder.Services.AddAuthorization();
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyRenderMode();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode();

app.Run();
```

## Client-Side Program.cs (WASM Project)

```csharp
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(options =>
{
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromSeconds(30)
    };
});

// Typed HTTP client that routes through the BFF host
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```

## How It Works

- **Server-side `AddBffBlazorClient()`** integrates BFF session management with Blazor WASM's hosting model. It configures the server to serve the WASM client and manage authentication.
- **Client-side `AddBffBlazorClient`** with polling enables the WASM app to periodically check session status. The 30-second interval means the app checks every 30 seconds if the user is still authenticated.
- **`AddLocalApiHttpClient<WeatherClient>()`** creates a typed `HttpClient` that automatically includes the BFF anti-forgery header and routes requests through the BFF host, so the WASM app never touches tokens directly.
