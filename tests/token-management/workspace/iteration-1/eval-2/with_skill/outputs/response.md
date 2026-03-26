# User Token Management for ASP.NET Core Web App

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

// Named HTTP client that attaches the user's access token automatically
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

builder.Services.AddControllersWithViews();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapDefaultControllerRoute().RequireAuthorization();

app.Run();
```

## Key Configuration Points

1. **`SaveTokens = true`** — This is mandatory. Without it, the OIDC handler discards tokens after authentication and the library cannot read or refresh them. This is the most common misconfiguration.

2. **`offline_access` scope** — Required for the authorization server to issue refresh tokens. Without refresh tokens, the access token cannot be silently renewed and the user must re-authenticate when it expires.

3. **`RevokeRefreshTokenAsync()` on sign-out** — Revokes the refresh token at the authorization server when the user logs out. Without this, the refresh token remains valid and could be reused.

4. **`AddOpenIdConnectAccessTokenManagement()`** — Registers all the services needed for user token management: token store, token manager, and HttpContext extensions.

5. **`AddUserAccessTokenHttpClient()`** — Creates a named HTTP client that automatically retrieves the current user's access token, attaches it as a Bearer token, and refreshes it via the refresh token if expired.
