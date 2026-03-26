# Duende BFF v4 Setup for React SPA

Here's the complete `Program.cs` using BFF v4's streamlined registration API.

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
        options.Scope.Add("offline_access");
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapFallbackToFile("index.html");

app.Run();
```

## Key Points

- **`AddBff()`** registers BFF services and automatically configures OpenID Connect and cookie authentication with recommended defaults. In v4, this replaces the manual `AddAuthentication().AddCookie().AddOpenIdConnect()` pattern.
- **`ConfigureOpenIdConnect`** configures the OIDC handler with your IDP settings. `SaveTokens = true` is required for token management to work.
- **`offline_access`** scope is critical — without a refresh token, the BFF cannot automatically renew expired access tokens.
- **`ConfigureCookies`** sets the cookie options. `SameSite = Lax` is used here since the IDP is on a different domain.
- **Middleware order**: `UseRouting` → `UseAuthentication` → `UseBff` → `UseAuthorization`. `UseBff()` must be between authentication and authorization for CSRF enforcement to work.
- In v4, management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`) are registered automatically — no `MapBffManagementEndpoints()` call needed.
