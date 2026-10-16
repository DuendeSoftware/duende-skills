```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(o =>
{
    o.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    o.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app";
    o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.SaveTokens = true; // keeps id_token for id_token_hint
    o.SignedOutRedirectUri = "/signed-out";
});

builder.Services.AddAuthorization();
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");
app.MapGet("/signed-out", () => "You have been signed out");

app.MapPost("/logout", () => Results.SignOut(
    new AuthenticationProperties { RedirectUri = "/signed-out" },
    new[] { CookieAuthenticationDefaults.AuthenticationScheme, OpenIdConnectDefaults.AuthenticationScheme }))
   .RequireAuthorization();

app.Run();
```

(Use `MapGet` if you need GET, though POST with antiforgery is safer against CSRF logout.)

## Flow
1. The user hits `/logout`; `SignOut` is invoked for both schemes.
2. The cookie handler deletes the local session cookie.
3. The OIDC handler builds an end-session request to IdentityServer (`/connect/endsession`) with `id_token_hint` (from saved tokens) and `post_logout_redirect_uri`, and redirects the browser there.
4. IdentityServer ends its SSO session, possibly notifying other clients, and redirects back to `/signin-oidc`-style callback `/signout-callback-oidc`, which then redirects to the `RedirectUri` (`/signed-out`).

The post-logout URI must be registered on the client in IdentityServer.
