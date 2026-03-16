# Full BFF v4 Program.cs Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access"); // Required for refresh tokens
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();          // Adds CSRF anti-forgery enforcement middleware
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.Run();
```

## Key Points

- **`AddBff()`** registers all BFF services and auto-registers management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`, `/bff/backchannel-logout`).
- **`ConfigureOpenIdConnect`** sets up the OIDC handler with recommended defaults — do NOT manually call `AddAuthentication().AddCookie().AddOpenIdConnect()` when using v4.
- **`ConfigureCookies`** configures the authentication cookie. Use `SameSite.Lax` when the IDP is on a different domain.
- **`offline_access`** scope is required for refresh tokens — without it, BFF cannot renew expired access tokens.
- **Middleware order matters**: `UseRouting()` -> `UseAuthentication()` -> `UseBff()` -> `UseAuthorization()`. Incorrect order silently breaks anti-forgery enforcement.
- **`SaveTokens = true`** is required so tokens are stored in the session and `GetUserAccessTokenAsync()` works.
