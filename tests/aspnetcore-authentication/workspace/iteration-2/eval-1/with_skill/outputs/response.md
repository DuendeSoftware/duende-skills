# OIDC Authentication Configuration

Here's the updated `Program.cs` configured for OIDC authentication with Duende IdentityServer:

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "myapp";
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code"; // Authorization code flow (PKCE is automatic in .NET 7+)

    // Disable Microsoft's JWT claim type mapping to prevent XML URI remapping
    options.MapInboundClaims = false;

    // Clear default scopes to avoid duplicates, then add what we need
    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    // Save tokens in the authentication cookie for later API calls
    options.SaveTokens = true;

    // Ensure User.Identity.Name and role-based checks work with short claim names
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

## Key Configuration Details

- **`DefaultScheme = "Cookies"`** — The cookie handler reads the session cookie on each request. If a valid cookie exists, the user is authenticated.
- **`DefaultChallengeScheme = "oidc"`** — When a 401 challenge is triggered, the OIDC handler redirects to IdentityServer for login.
- **`MapInboundClaims = false`** — Prevents the OIDC handler from remapping JWT claim names like `sub` to verbose XML URIs like `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier`. This is critical for `User.FindFirst("sub")` to work.
- **`Scope.Clear()`** — The OIDC handler adds `openid` and `profile` by default. Calling `Clear()` first avoids duplicate scope values in the authorize request.
- **`ResponseType = "code"`** — Uses the authorization code flow. PKCE is sent automatically by the ASP.NET Core OIDC handler since .NET 7.
- **`SaveTokens = true`** — Stores the access token, refresh token, and ID token in the authentication cookie so they can be retrieved later with `HttpContext.GetTokenAsync()`.
- **Middleware ordering** — `UseAuthentication()` must come before `UseAuthorization()` so the authorization middleware can see the authenticated user.
