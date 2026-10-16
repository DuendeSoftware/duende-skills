# Two clients: user token and client credentials

```csharp
var builder = WebApplication.CreateBuilder(args);

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
        options.Authority = builder.Configuration["IdentityServer:Authority"];
        options.ClientId = builder.Configuration["IdentityServer:ClientId"];
        options.ClientSecret = builder.Configuration["IdentityServer:ClientSecret"];
        options.ResponseType = "code";
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access");
        options.MapInboundClaims = false;
        options.SaveTokens = true;                 // required for user tokens
    });

builder.Services.AddAuthorization();
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Machine-to-machine definition
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("masterdata.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("webapp-masterdata");
        client.ClientSecret = ClientSecret.Parse(builder.Configuration["MasterData:Secret"]!);
        client.Scope = Scope.Parse("masterdata");
    });

// 1) invoice API with the logged-in user's token
builder.Services.AddUserAccessTokenHttpClient("invoices",
    configureClient: c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));

// 2) master data API with a client credentials token
builder.Services.AddClientCredentialsHttpClient("masterdata",
    ClientCredentialsClientName.Parse("masterdata.client"),
    c => c.BaseAddress = new Uri("https://api.example.com/masterdata/"));

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/call-api", async (IHttpClientFactory f, CancellationToken ct) =>
{
    var invoices = await f.CreateClient("invoices").GetStringAsync("", ct);
    var master = await f.CreateClient("masterdata").GetStringAsync("", ct);
    return Results.Ok(new { invoices, master });
}).RequireAuthorization();

app.Run();
```

Notes:
- `AddUserAccessTokenHttpClient` needs a signed-in user and silently refreshes with the refresh token.
- Alternative for machine tokens in a web app that has no separate named definition: `AddClientAccessTokenHttpClient("masterdata", ...)`, which uses the OIDC provider and `UserTokenManagementOptions.ClientCredentialsScope`/`ClientCredentialsResource`. The explicit `AddClientCredentialsHttpClient` above is clearer and includes the 401-retry resiliency handler.
- Typed-client equivalents: `.AddUserAccessTokenHandler()` and `.AddClientCredentialsTokenHandler(name)` (add `.AddDefaultAccessTokenResiliency()` for the latter).
- Don't cache tokens yourself; the library handles caching (HybridCache in v4).
