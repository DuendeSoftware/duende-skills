# Two HTTP Clients: One With the User Token, One With Client Credentials

You have two different token requirements:

- **Invoice API** → call on behalf of the signed-in user (user's access token)
- **Master data API** → machine-to-machine (client credentials, no user)

Both can be registered with `IHttpClientFactory`. Here's a setup that assumes the app already authenticates users via OpenID Connect.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Cookie + OIDC authentication
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie")
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    });

// User (OIDC) token management
builder.Services.AddOpenIdConnectAccessTokenManagement();

// 1) Invoice API — uses the current user's access token
builder.Services.AddUserAccessTokenHttpClient("invoices", configureClient: client =>
{
    client.BaseAddress = new Uri("https://api.example.com/invoices/");
});

// 2) Master data API — client credentials (machine-to-machine)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("masterdata", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "webapp";
        client.ClientSecret = "secret";
        client.Scope = "masterdata";
    });

builder.Services.AddClientCredentialsHttpClient("masterdata", "masterdata", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/masterdata/");
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/invoices", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("invoices");
    return await (await client.GetAsync("list")).Content.ReadAsStringAsync();
}).RequireAuthorization();

app.MapGet("/masterdata", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("masterdata");
    return await (await client.GetAsync("list")).Content.ReadAsStringAsync();
});

app.Run();
```

## Summary

- **`AddUserAccessTokenHttpClient("invoices", ...)`** attaches the logged-in user's access token (and refreshes it) to calls against the invoice API.
- **`AddClientCredentialsTokenManagement().AddClient(...)` + `AddClientCredentialsHttpClient("masterdata", ...)`** obtains a machine-to-machine token via the client credentials grant and attaches it to calls against the master data API — no user context involved.
- Each client has its own distinct name and `BaseAddress`, so you resolve them independently from `IHttpClientFactory`.

This keeps the two token strategies cleanly separated while both benefit from automatic acquisition, caching, and refresh.
