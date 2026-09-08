Here's a `Program.cs` that configures OpenID Connect against your IdentityServer using cookie + OIDC schemes.

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie()
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.UsePkce = true;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = true;

    // Prevent claims from being remapped to the long XML/SOAP URIs
    options.MapInboundClaims = false;

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

### Notes

- **`MapInboundClaims = false`** — This is the key setting to stop the OIDC/JWT handler from renaming inbound claims (e.g. `sub`, `name`, `role`) to the `http://schemas.xmlsoap.org/...` XML URIs. With it off, claims keep their original short names. I also set `JwtSecurityTokenHandler.DefaultMapInboundClaims` is not needed since the option covers it.
- **`Scope.Clear()`** — The handler adds `openid` and `profile` by default; clearing first avoids duplicate scope entries before I re-add exactly what you need plus `api1`.
- **Schemes** — `DefaultScheme` is the cookie (so the session is read from the cookie), and `DefaultChallengeScheme` is `oidc` (so an unauthenticated request redirects to IdentityServer).
- **`ResponseType = "code"`** with PKCE is the authorization code flow, which is the correct choice for a server-side web app with a client secret.
- **`SaveTokens = true`** keeps the access/refresh/ID tokens available via `HttpContext.GetTokenAsync(...)`.
- **Middleware order** — `UseAuthentication()` must come before `UseAuthorization()`.

You could move `Authority`, `ClientId`, and `ClientSecret` into `appsettings.json` (they're already under the `Authentication` section) and bind them with `builder.Configuration`.
