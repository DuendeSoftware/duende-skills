# Two HTTP Clients: User Token + Client Credentials

```csharp
var builder = WebApplication.CreateBuilder(args);

// Authentication setup (cookie + OIDC)
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e => await e.HttpContext.RevokeRefreshTokenAsync();
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("invoice");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});

// Register user + client token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// User token HTTP client — attaches the logged-in user's access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

// Client credentials HTTP client — attaches a machine-to-machine token
builder.Services.AddClientAccessTokenHttpClient(
    "masterdata",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/masterdata/");
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapDefaultControllerRoute().RequireAuthorization();
app.Run();
```

## Usage

```csharp
public class DashboardController(IHttpClientFactory factory) : Controller
{
    public async Task<IActionResult> Index()
    {
        // User's access token attached automatically
        var invoiceClient = factory.CreateClient("invoices");
        var invoices = await invoiceClient.GetFromJsonAsync<List<Invoice>>("recent");

        // Client credentials token attached automatically (no user context needed)
        var masterDataClient = factory.CreateClient("masterdata");
        var categories = await masterDataClient.GetFromJsonAsync<List<Category>>("categories");

        return View(new DashboardModel(invoices, categories));
    }
}
```

## How It Works

- **`AddUserAccessTokenHttpClient("invoices")`** — Creates a named client that reads the current user's access token from the authentication session, refreshes it if expired, and attaches it as a Bearer token.

- **`AddClientAccessTokenHttpClient("masterdata")`** — Creates a named client that uses the OIDC provider's token endpoint with the web app's own client credentials to get a machine-to-machine token. This does not require a user context.

- **`AddOpenIdConnectAccessTokenManagement()`** — Enables both user token management and client credentials token management using the OIDC configuration.
