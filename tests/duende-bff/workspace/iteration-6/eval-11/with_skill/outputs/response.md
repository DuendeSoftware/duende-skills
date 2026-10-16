# Blazor WASM with BFF

## Server Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("offline_access");
    })
    .AddBffBlazorClient();

builder.Services.AddAuthorization();
var app = builder.Build();

app.UseBlazorFrameworkFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapFallbackToFile("index.html");
app.Run();
```

## Client (WASM) Program.cs

```csharp
var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(options =>
{
    options.RemoteApiPath = "/api/remote";
    options.Polling = new BffBlazorClientPollingOptions
    {
        Interval = TimeSpan.FromSeconds(30)   // default is 5 seconds
    };
});

builder.Services.AddCascadingAuthenticationState();

// Typed HttpClient routed through the BFF host
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```

`WeatherClient` takes an `HttpClient` in its constructor. Local API client calls go through the BFF host (cookie + anti-forgery header handled), so server endpoints they hit should use `.AsBffApiEndpoint()`. `Polling.Interval` controls how often the client checks session status.
