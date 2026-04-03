# Registering Both User Token and Client Credentials HTTP Clients

Here's how to set up a web app that calls two different APIs: one using the user's access token and one using client credentials.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Configure authentication: cookie + OIDC
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
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("invoice");
    options.Scope.Add("offline_access");
    options.SaveTokens = true;
});

// Register token management — AddOpenIdConnectAccessTokenManagement enables
// BOTH user token management AND client credentials token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register a client credentials client for the master data API
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("masterdata.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("webapp");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.Scope = Scope.Parse("masterdata");
    });

// HTTP client #1: User token — attaches the logged-in user's access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

// HTTP client #2: Client credentials — machine-to-machine, no user context needed
builder.Services.AddClientCredentialsHttpClient(
    "masterdata",
    ClientCredentialsClientName.Parse("masterdata.client"),
    client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/masterdata/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Endpoint using user token
app.MapGet("/invoices", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

// Endpoint using client credentials token
app.MapGet("/masterdata", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    var client = factory.CreateClient("masterdata");
    var response = await client.GetAsync("categories", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
});

app.Run();
```

## Key Points

1. **`AddOpenIdConnectAccessTokenManagement()`** enables both user token management and client credentials token management in a web app context.
2. **`AddUserAccessTokenHttpClient("invoices", ...)`** registers a named HTTP client that attaches the logged-in user's access token. The token is refreshed automatically using the refresh token if it's expired.
3. **`AddClientCredentialsHttpClient("masterdata", ...)`** registers a named HTTP client that uses a client credentials token (machine-to-machine). No user context is needed.
4. Both clients are distinct named clients with separate `BaseAddress` values — `"invoices"` for user-context calls and `"masterdata"` for service-to-service calls.
5. The user token client requires `SaveTokens = true`, `offline_access` scope, and `RevokeRefreshTokenAsync` on sign-out.
