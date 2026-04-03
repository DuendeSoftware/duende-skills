# Sign-Out from Both Local Cookie and IdentityServer

Here's the updated `Program.cs` with a proper sign-out endpoint:

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
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

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

// Sign-out endpoint
app.MapGet("/logout", async (HttpContext ctx) =>
{
    // 1. Clear the local authentication cookie
    await ctx.SignOutAsync("Cookies");

    // 2. Redirect to IdentityServer's end session endpoint
    await ctx.SignOutAsync("oidc");
});

app.Run();
```

## The Sign-Out Flow

When the user hits `/logout`, two sign-out operations happen in sequence:

1. **`SignOutAsync("Cookies")`** — Clears the local authentication cookie, ending the user's session in your web application.

2. **`SignOutAsync("oidc")`** — Triggers the OIDC sign-out flow:
   - The OIDC handler redirects the browser to IdentityServer's end session endpoint (`/connect/endsession`).
   - IdentityServer clears its own session cookie.
   - IdentityServer notifies other client applications that the user has signed out (via front-channel or back-channel logout, if configured).
   - IdentityServer redirects the browser to the configured `PostLogoutRedirectUri` (if set on the client registration).

### Important Notes

- **Both sign-outs are required.** If you only call `SignOutAsync("Cookies")` without `SignOutAsync("oidc")`, the IdentityServer session remains active. The next time the user triggers a challenge (e.g., accessing a protected page), the OIDC handler will redirect to IdentityServer, which will silently re-authenticate the user without showing a login prompt — because the IdentityServer session is still valid.

- **Sign-out order matters.** Clear the local cookie first, then trigger the OIDC sign-out redirect. The OIDC sign-out will redirect the browser away from your application, so any response modifications after it won't take effect.

- You can configure the `PostLogoutRedirectUri` on the OIDC handler options to control where the user lands after the IdentityServer logout completes.
