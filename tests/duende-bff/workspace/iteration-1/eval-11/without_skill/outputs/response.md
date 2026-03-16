# Blazor WASM with BFF Authentication

Here's how to set up a Blazor WASM app with a BFF backend for authentication.

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
    });

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

## Client-Side Program.cs (WASM Project)

```csharp
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Microsoft.AspNetCore.Components.Authorization;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Auth state provider that polls /bff/user
builder.Services.AddAuthorizationCore();
builder.Services.AddScoped<AuthenticationStateProvider, BffAuthenticationStateProvider>();

// Typed HttpClient for weather data
builder.Services.AddHttpClient<WeatherClient>(client =>
{
    client.BaseAddress = new Uri(builder.HostEnvironment.BaseAddress);
    client.DefaultRequestHeaders.Add("X-CSRF", "1");
});

await builder.Build().RunAsync();
```

## Key Points

- The server-side uses `AddBff().ConfigureOpenIdConnect()` for the V4 fluent API setup.
- On the client side, you need a custom `AuthenticationStateProvider` that checks `/bff/user` to determine the user's authentication state.
- All HTTP clients must include the `X-CSRF: 1` header for BFF anti-forgery protection.
- The `WeatherClient` is registered as a typed HttpClient pointing to the BFF host.
- Consider adding session polling to detect when the user's session expires.
