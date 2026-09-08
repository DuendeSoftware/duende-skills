# Blazor WASM with a BFF host

The idea is that the ASP.NET Core host acts as the BFF (holding the session cookie and tokens), and the WASM client talks to local API endpoints on that host, checking auth state via `/bff/user`.

## Server-side `Program.cs`

Set up cookie + OpenID Connect authentication and add the BFF services. The host also serves the Blazor WASM app and exposes the local API.

```csharp
using Duende.Bff;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
    options.DefaultSignOutScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = builder.Configuration["Oidc:Authority"];
    options.ClientId = builder.Configuration["Oidc:ClientId"];
    options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
    options.ResponseType = "code";
    options.SaveTokens = true;
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("offline_access");
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseBlazorFrameworkFiles();
app.UseStaticFiles();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapGet("/api/weather", () => new[] { new { Day = "Mon", TempC = 21 } })
    .RequireAuthorization()
    .AsBffApiEndpoint();

app.MapFallbackToFile("index.html");

app.Run();
```

## Client-side (WASM) `Program.cs`

On the client, register a typed `HttpClient` for the local API and a custom auth-state provider that polls `/bff/user` to keep the UI in sync. A 30-second poll keeps the session state fresh:

```csharp
var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddAuthorizationCore();
builder.Services.AddScoped<AuthenticationStateProvider, BffAuthenticationStateProvider>();

builder.Services.AddHttpClient<WeatherClient>(client =>
{
    client.BaseAddress = new Uri(builder.HostEnvironment.BaseAddress);
});

await builder.Build().RunAsync();
```

```csharp
// BffAuthenticationStateProvider.cs — polls /bff/user every 30 seconds
public class BffAuthenticationStateProvider : AuthenticationStateProvider
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(30);
    private readonly HttpClient _http;

    public BffAuthenticationStateProvider(HttpClient http)
    {
        _http = http;
        _ = PollLoop();
    }

    public override async Task<AuthenticationState> GetAuthenticationStateAsync()
    {
        var identity = new ClaimsIdentity();
        var res = await _http.GetAsync("bff/user");
        if (res.IsSuccessStatusCode)
        {
            var claims = await res.Content.ReadFromJsonAsync<List<ClaimRecord>>();
            identity = new ClaimsIdentity(
                claims!.Select(c => new Claim(c.Type, c.Value)), "bff");
        }
        return new AuthenticationState(new ClaimsPrincipal(identity));
    }

    private async Task PollLoop()
    {
        var timer = new PeriodicTimer(PollInterval);
        while (await timer.WaitForNextTickAsync())
            NotifyAuthenticationStateChanged(GetAuthenticationStateAsync());
    }

    public record ClaimRecord(string Type, string Value);
}
```

```csharp
public class WeatherClient
{
    private readonly HttpClient _http;
    public WeatherClient(HttpClient http) => _http = http;

    public Task<WeatherForecast[]?> GetForecastAsync() =>
        _http.GetFromJsonAsync<WeatherForecast[]>("api/weather");
}
```

## Notes

- The server holds the session cookie and tokens; the WASM app never sees a token.
- The typed `WeatherClient` points at the host base address so it calls the BFF's local `/api/weather` endpoint.
- Polling `/bff/user` on a 30-second interval keeps the Blazor auth state provider up to date if the session changes.
