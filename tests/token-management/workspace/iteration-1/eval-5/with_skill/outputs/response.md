# Calling Two APIs: User Token + Client Credentials

Your web app needs two different HTTP clients — one that carries the logged-in user's access token (for invoices) and one that uses a client credentials token (for master data). Here's how to set up both with `Duende.AccessTokenManagement`.

## Package References

```xml
<PackageReference Include="Duende.AccessTokenManagement.OpenIdConnect" Version="4.0.0" />
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// ── Authentication: cookie + OIDC ──
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "web";
        options.Events.OnSigningOut = async e =>
        {
            await e.HttpContext.RevokeRefreshTokenAsync();
        };
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("invoices");
        options.Scope.Add("offline_access");

        options.SaveTokens = true;
    });

// ── Token management (enables both user and client credentials flows) ──
builder.Services.AddOpenIdConnectAccessTokenManagement();

// ── HTTP Client 1: Invoice API — uses the current user's access token ──
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

// ── HTTP Client 2: Master Data API — uses client credentials (machine-to-machine) ──
builder.Services.AddClientAccessTokenHttpClient(
    "masterdata",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/masterdata/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Call the invoice API with the user's token
app.MapGet("/invoices", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

// Call the master data API with a client credentials token
app.MapGet("/masterdata", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("masterdata");
    var response = await client.GetAsync("countries", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
});

app.Run();
```

## How It Works

- **`AddUserAccessTokenHttpClient("invoices", ...)`** — creates a named HTTP client that automatically acquires and attaches the current user's access token. Tokens are refreshed silently when they expire (if `offline_access` was requested).

- **`AddClientAccessTokenHttpClient("masterdata", ...)`** — creates a named HTTP client that uses a client credentials token. The OIDC configuration (client ID, client secret, token endpoint) is inferred from the configured OIDC authority. The token is obtained machine-to-machine with no user context.

- **`AddOpenIdConnectAccessTokenManagement()`** — this single call enables both user token management (reading from the OIDC session) and client credentials token management (using the OIDC handler's client settings). Both HTTP clients are handled by the same library.

Each client has a distinct name (`"invoices"` and `"masterdata"`) with its own `BaseAddress`, so at the call site you simply call `factory.CreateClient("invoices")` or `factory.CreateClient("masterdata")` — no manual token code needed.
