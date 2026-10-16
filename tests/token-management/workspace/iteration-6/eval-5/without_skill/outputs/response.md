# Two HTTP clients: user token and client credentials

```csharp
builder.Services.AddAuthentication(o =>
{
    o.DefaultScheme = "cookie";
    o.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie")
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://sts.example.com";
    o.ClientId = "webapp";
    o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.SaveTokens = true;
    o.Scope.Add("invoice");
    o.Scope.Add("offline_access");
});

// user tokens
builder.Services.AddOpenIdConnectAccessTokenManagement();

// client credentials
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("masterdata.client", c =>
    {
        c.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        c.ClientId = ClientId.Parse("webapp");
        c.ClientSecret = ClientSecret.Parse("secret");
        c.Scope = Scope.Parse("masterdata");
    });

builder.Services.AddUserAccessTokenHttpClient("invoices",
    configureClient: c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));

builder.Services.AddClientCredentialsHttpClient("masterdata",
    ClientCredentialsClientName.Parse("masterdata.client"),
    c => c.BaseAddress = new Uri("https://api.example.com/masterdata/"));
```

Usage:

```csharp
app.MapGet("/call-api", async (IHttpClientFactory f, CancellationToken ct) =>
{
    var invoices = await f.CreateClient("invoices").GetStringAsync("", ct);
    var master   = await f.CreateClient("masterdata").GetStringAsync("", ct);
    return Results.Ok(new { invoices, master });
}).RequireAuthorization();
```

The user client requires a signed-in user (it uses the saved cookie tokens and refresh token); the machine client does not. Both caches/refresh are handled by the library.
