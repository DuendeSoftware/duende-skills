# Blazor WASM with BFF

## Server-Side

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
    });

builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyRenderMode();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode();

app.Run();
```

## Client-Side

```csharp
var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddAuthorizationCore();
builder.Services.AddHttpClient("api", client =>
{
    client.BaseAddress = new Uri(builder.HostEnvironment.BaseAddress);
});

await builder.Build().RunAsync();
```

Set up the server with BFF authentication and the client uses HttpClient to make API calls through the BFF.
