# Registering Two HTTP Clients: User Token + Client Credentials

Your web app needs one client that uses the **logged-in user's** access token (invoice API) and one that uses a **client credentials** token independent of any user (master data API). Both go through `IHttpClientFactory`. This requires OIDC token management to be configured.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

// --- Cookie + OIDC authentication ---
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
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access"); // refresh tokens for the user flow

        options.SaveTokens = true; // ← required for user token management
    });

// ✅ Enables BOTH user token and client-credentials token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// ✅ Invoice API — uses the logged-in user's access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

// ✅ Master data API — uses a client credentials (machine-to-machine) token
builder.Services.AddClientAccessTokenHttpClient(
    "masterdata",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/masterdata/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// User-context call
app.MapGet("/invoices", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("invoices");     // user token attached
    return Results.Ok(await (await client.GetAsync("list", ct)).Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

// Machine-to-machine call (no user context needed)
app.MapGet("/masterdata", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("masterdata");   // client credentials token attached
    return Results.Ok(await (await client.GetAsync("list", ct)).Content.ReadAsStringAsync(ct));
});

app.Run();
```

## The two registrations

| Client | Registration | Token used |
|---|---|---|
| `invoices` → `https://api.example.com/invoices/` | `AddUserAccessTokenHttpClient(...)` | Current user's access token (refreshed via refresh token) |
| `masterdata` → `https://api.example.com/masterdata/` | `AddClientAccessTokenHttpClient(...)` | Client credentials token (re-requested from the token server when expired) |

Both are enabled by the single `AddOpenIdConnectAccessTokenManagement()` call — it registers the services for **user** tokens *and* the app's own **client-credentials** tokens.

### Typed-client alternative

```csharp
builder.Services.AddHttpClient<InvoiceClient>(c =>
        c.BaseAddress = new Uri("https://api.example.com/invoices/"))
    .AddUserAccessTokenHandler();

builder.Services.AddHttpClient<MasterDataClient>(c =>
        c.BaseAddress = new Uri("https://api.example.com/masterdata/"))
    .AddClientAccessTokenHandler();
```

> The client-credentials token uses the OIDC provider's client (`webapp`/`secret`). If the master data API needs a *different* client id/scope than your OIDC app, set `options.ClientCredentialsScope` / `options.ClientCredentialsResource` on `AddOpenIdConnectAccessTokenManagement(options => ...)`.
