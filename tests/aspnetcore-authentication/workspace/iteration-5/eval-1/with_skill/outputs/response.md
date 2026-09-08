Here's a complete `Program.cs` that wires up OpenID Connect against your Duende IdentityServer, with the cookie scheme handling the local session and the OIDC scheme handling the challenge.

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    // Cookie is the primary scheme used for [Authorize] and User.Identity
    options.DefaultScheme = "Cookies";
    // OIDC handles the challenge (401 -> redirect to IdentityServer)
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "web.app";
    options.Cookie.SameSite = SameSiteMode.Lax; // required so the cookie survives the OIDC callback
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";

    // Authorization code flow (PKCE is automatic on .NET 7+)
    options.ResponseType = "code";

    // Clear the default scopes (openid, profile) so we don't add duplicates
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");
    options.Scope.Add("offline_access"); // request refresh tokens

    // Persist the tokens in the auth cookie so they can be used to call APIs
    options.SaveTokens = true;

    // Fetch full profile claims from the userinfo endpoint
    options.GetClaimsFromUserInfoEndpoint = true;

    // Do NOT remap JWT claim types to the long XML/SOAP URIs
    options.MapInboundClaims = false;

    // Tell ASP.NET Core which claims back User.Identity.Name and role checks
    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "name",
        RoleClaimType = "role"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// Order matters: authentication must run before authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", (HttpContext ctx) =>
        $"Hello {ctx.User.Identity?.Name ?? "anonymous"}!")
    .RequireAuthorization();

app.Run();
```

### Why each key setting matters

| Setting | Reason |
|---------|--------|
| `MapInboundClaims = false` | Without this the OIDC handler renames `sub` → `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier` (and similar for `name`, `role`, `email`). Turning it off keeps the original JWT claim names so `User.FindFirst("sub")` works. |
| `Scope.Clear()` before adding scopes | The handler pre-seeds `openid` and `profile`. Clearing first prevents duplicate scope values in the authorize request. |
| `DefaultScheme = "Cookies"` / `DefaultChallengeScheme = "oidc"` | The cookie carries the authenticated session; OIDC is only invoked when a challenge is needed. |
| `ResponseType = "code"` | Authorization code flow with automatic PKCE — the recommended flow for confidential web apps. |
| `SaveTokens = true` | Stores the access, refresh, and ID tokens in the cookie for later API calls (`await HttpContext.GetTokenAsync("access_token")`). |
| `UseAuthentication()` before `UseAuthorization()` | Authorization must be able to see the authenticated principal that authentication established. |

> Because `NameClaimType`/`RoleClaimType` are set to `"name"` and `"role"`, `User.Identity.Name` and `[Authorize(Roles = "...")]` resolve correctly.

You can keep the authority/client values in `appsettings.json` and bind them if you prefer, but the code above matches the values you supplied.
