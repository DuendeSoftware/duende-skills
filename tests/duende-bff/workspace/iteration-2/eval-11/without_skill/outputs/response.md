Here's a Blazor WASM setup with BFF:

## Server-Side

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();
builder.Services.AddAuthentication()
    .AddCookie()
    .AddOpenIdConnect(options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "blazor-wasm";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
    });

var app = builder.Build();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
app.Run();
```

## Client-Side (WASM)

```csharp
var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Add BFF client services
builder.Services.AddAuthorizationCore();
builder.Services.AddScoped<AuthenticationStateProvider, BffAuthenticationStateProvider>();

builder.Services.AddHttpClient<WeatherClient>(client =>
{
    client.BaseAddress = new Uri(builder.HostEnvironment.BaseAddress);
});

await builder.Build().RunAsync();
```

The key idea is that the Blazor WASM client communicates with the BFF server for all authentication operations, and the server proxies API calls on behalf of the client.
