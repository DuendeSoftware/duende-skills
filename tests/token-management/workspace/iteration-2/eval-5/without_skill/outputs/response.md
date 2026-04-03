# Registering Both User Token and Client Credentials HTTP Clients

Here's how to set up HTTP clients for both user tokens and client credentials in your web app.

## `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure authentication
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
})
.AddCookie("Cookies")
.AddOpenIdConnect("OpenIdConnect", options =>
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

// Add token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// HTTP client for invoice API (user token)
builder.Services.AddHttpClient("invoices", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
}).AddUserAccessTokenHandler();

// HTTP client for master data API (client credentials)
builder.Services.AddHttpClient("masterdata", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/masterdata/");
}).AddClientAccessTokenHandler();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/invoices", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

app.MapGet("/masterdata", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("masterdata");
    var response = await client.GetAsync("categories", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
});

app.Run();
```

## Notes

- `AddUserAccessTokenHandler()` attaches the current user's access token to requests.
- `AddClientAccessTokenHandler()` uses client credentials (machine-to-machine) tokens.
- Both clients are registered as named HTTP clients via `AddHttpClient`.
- Make sure the OIDC configuration includes the proper scopes for both APIs.
