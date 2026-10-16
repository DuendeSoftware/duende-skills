## Server Program.cs

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(o => { o.Authority = "https://idp.example.com"; o.ClientId = "spa-bff-client"; o.ClientSecret = "secret"; o.ResponseType = "code"; o.SaveTokens = true; })
    .AddBlazorServer()
    .AddRemoteApis();
builder.Services.AddBffBlazorClient();   // server side

builder.Services.AddControllers();
builder.Services.AddAuthorization();
var app = builder.Build();

app.UseBlazorFrameworkFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
app.MapBffManagementEndpoints();
app.MapFallbackToFile("index.html");
app.Run();
```

## Client (WASM) Program.cs

```csharp
var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddBffBlazorClient(opt =>
{
    opt.StateProviderPollingInterval = TimeSpan.FromSeconds(30);
});

builder.Services.AddCascadingAuthenticationState();
builder.Services.AddLocalApiHttpClient<WeatherClient>();

await builder.Build().RunAsync();
```
`WeatherClient` takes an `HttpClient` in its constructor; the local API client adds the `X-CSRF: 1` header and uses the host base address.
