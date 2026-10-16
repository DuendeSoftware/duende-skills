# User token management: cookie + OIDC + `invoices` client

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "web";

        // ✅ revoke the refresh token at the STS on sign-out
        options.Events.OnSigningOut = async e =>
        {
            await e.HttpContext.RevokeRefreshTokenAsync();
        };
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = builder.Configuration["IdentityServer:ClientId"];
        options.ClientSecret = builder.Configuration["IdentityServer:ClientSecret"];
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access");   // refresh token

        options.GetClaimsFromUserInfoEndpoint = true;
        options.MapInboundClaims = false;

        options.SaveTokens = true;             // ✅ REQUIRED: tokens persisted in the auth session
    });

builder.Services.AddAuthorization();
builder.Services.AddOpenIdConnectAccessTokenManagement();

// Named client that attaches the current user's access token
builder.Services.AddUserAccessTokenHttpClient("invoices",
    configureClient: client => client.BaseAddress = new Uri("https://api.example.com/invoices/"));

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.MapGet("/call-api", async (IHttpClientFactory httpClientFactory, CancellationToken ct) =>
{
    var client = httpClientFactory.CreateClient("invoices");
    var response = await client.GetAsync("", ct);
    return Results.Content(await response.Content.ReadAsStringAsync(ct), "application/json");
}).RequireAuthorization();

app.MapGet("/logout", (HttpContext ctx) => Results.SignOut(
    new AuthenticationProperties { RedirectUri = "/" }, ["cookie", "oidc"]));

app.Run();
```

## Key points
- **`SaveTokens = true`** is mandatory; without it the library can't read/refresh tokens and throws at runtime.
- **`offline_access`** is what yields a refresh token; without it the user must re-authenticate when the access token expires.
- **Revocation on sign-out:** `OnSigningOut` on the cookie handler calls `RevokeRefreshTokenAsync()`, so the refresh token is invalidated at the authorization server whenever the cookie is signed out (not just the local cookie deleted).
- `AddUserAccessTokenHttpClient` gives automatic attach + silent refresh. No manual token code is needed.
