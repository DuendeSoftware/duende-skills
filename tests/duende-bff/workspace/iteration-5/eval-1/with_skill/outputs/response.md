# Duende BFF v4 — Full `Program.cs` for a React SPA

Your `BffHost.csproj` already references `Duende.BFF` 4.0.0, so we can use the v4 fluent registration API. It auto-configures OpenID Connect and cookie authentication with the recommended BFF defaults, so you should **not** manually wire `AddAuthentication().AddCookie().AddOpenIdConnect()`.

Here is the complete `Program.cs`:

```csharp
using Duende.Bff;
using Microsoft.AspNetCore.Authentication.Cookies;

var builder = WebApplication.CreateBuilder(args);

// ✅ v4: AddBff() with fluent OIDC + cookie configuration
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority    = builder.Configuration["Oidc:Authority"]    ?? "https://idp.example.com";
        options.ClientId     = builder.Configuration["Oidc:ClientId"]     ?? "spa-bff-client";
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"] ?? "secret";

        options.ResponseType = "code";   // Authorization Code flow
        options.ResponseMode = "query";

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens   = true;      // Required so BFF/ATM can store & refresh tokens
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access"); // Required for refresh tokens
    })
    .ConfigureCookies(options =>
    {
        // Your IDP is on a different host (idp.example.com), so a cross-site
        // redirect happens after login → use Lax so the cookie is sent on return.
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// ✅ Correct middleware order
app.UseRouting();
app.UseAuthentication();
app.UseBff();          // Adds CSRF/anti-forgery enforcement; registers /bff/* endpoints
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.Run();
```

## Why each piece matters

- **`AddBff()`** is the entry point. In v4 the management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`, `/bff/backchannel-logout`) are registered automatically with the implicit default frontend — no `MapBffManagementEndpoints()` call is needed (that was v3).
- **`ConfigureOpenIdConnect`** sets `ResponseType = "code"` for the Authorization Code flow and `SaveTokens = true` so tokens are persisted in the session and refreshed transparently by `Duende.AccessTokenManagement`.
- **`offline_access`** is essential — without it there is no refresh token, and your users will start getting 401s from remote APIs once the access token expires.
- **`ConfigureCookies`** — because your IDP (`idp.example.com`) is a different site from the BFF, use `SameSite=Lax`. If you later move the IDP onto the same site, switch to `Strict`.
- **Middleware order** — `UseBff()` must sit **after** `UseRouting()`/`UseAuthentication()` and **before** `UseAuthorization()`. Any other ordering silently disables anti-forgery enforcement.

## SPA side (quick reminder)

From React, trigger auth as browser navigations, not `fetch`:

```javascript
// Login / logout are navigations, never fetch:
window.location.href = '/bff/login?returnUrl=/dashboard';

// Every BFF API/`/bff/user` call must send the anti-forgery header:
fetch('/bff/user', { headers: { 'X-CSRF': '1' } });
```

That is everything needed to secure the React SPA with BFF v4.
