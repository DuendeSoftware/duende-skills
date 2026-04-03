# OIDC Authentication Configuration

Here's how to configure OIDC authentication in your ASP.NET Core web app:

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authentication.Cookies;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";

    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.SaveTokens = true;
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## What This Does

- **Cookie authentication** is used as the default scheme — the cookie stores the session after login.
- **OpenID Connect** is used as the challenge scheme — when the user isn't authenticated, they're redirected to your IdentityServer.
- **`ResponseType = "code"`** — Uses authorization code flow, which is the recommended approach.
- **`SaveTokens = true`** — Saves the tokens in the cookie so you can retrieve them later.
- The scopes `openid`, `profile`, and `api1` are requested during authentication.
- `UseAuthentication()` is placed before `UseAuthorization()` in the middleware pipeline.

This should get your OIDC login working with IdentityServer.
