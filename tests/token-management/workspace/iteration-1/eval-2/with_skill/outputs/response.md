# User Token Management for ASP.NET Core Web App

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "cookie";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("cookie", options =>
{
    options.Cookie.Name = "web";
    // Revoke refresh token at sign-out
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
    options.ResponseMode = "query";

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");
    options.Scope.Add("invoice");
    options.Scope.Add("offline_access"); // Required for refresh tokens

    options.GetClaimsFromUserInfoEndpoint = true;
    options.MapInboundClaims = false;

    // REQUIRED — persists access and refresh tokens into the auth session
    options.SaveTokens = true;
});

// Register user token management services
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Register named HTTP client with user access token
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.MapGet("/call-api", async (IHttpClientFactory httpClientFactory, CancellationToken ct) =>
{
    var client = httpClientFactory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    var content = await response.Content.ReadAsStringAsync(ct);
    return Results.Ok(content);
}).RequireAuthorization();

app.Run();
```

## Key Configuration Points

1. **`SaveTokens = true`** — This is mandatory. Without it, the library cannot read or refresh the user's access token. This is the most common misconfiguration.
2. **`offline_access` scope** — Required for refresh tokens. Without it, the access token expires and the user must re-authenticate.
3. **`RevokeRefreshTokenAsync()`** in `OnSigningOut` — Revokes the refresh token at the authorization server on sign-out, preventing reuse after logout.
4. **`AddOpenIdConnectAccessTokenManagement()`** — Registers all user token management services.
5. **`AddUserAccessTokenHttpClient()`** — Registers a named HTTP client that automatically attaches the user's access token.
