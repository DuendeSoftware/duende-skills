# Fixing the Redirect Loop: SameSite Cookie Issue

## The Problem

Your redirect loop is caused by `SameSiteMode.Strict` on the authentication cookie. Here's what happens:

1. The user is redirected to IdentityServer to log in.
2. After successful authentication, IdentityServer redirects back to your app's callback endpoint (e.g., `/signin-oidc`).
3. The OIDC handler processes the callback and tries to set the authentication cookie.
4. **The browser refuses to send the cookie** on this redirect because it's a cross-site navigation (from `identity.example.com` to your app) and `SameSite=Strict` cookies are **never sent on cross-site requests**, including top-level navigations initiated by a redirect from another site.
5. Your app sees no cookie → user appears unauthenticated → triggers another challenge → redirect loop.

`SameSite=Strict` prevents the cookie from being sent during the OIDC callback redirect from IdentityServer because the browser treats the redirect from `identity.example.com` as a cross-site request.

## The Fix

Change `SameSiteMode.Strict` to `SameSiteMode.Lax`:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;  // Changed from Strict
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always; // Always use HTTPS
    options.Cookie.Name = "myapp";
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

## Why Lax Works

- **`SameSite=Lax`** allows the cookie to be sent on **top-level navigations** (like the redirect back from IdentityServer) but still blocks the cookie on cross-site sub-requests (images, iframes, AJAX from other origins). This is the correct setting for OIDC callbacks.
- **`SameSite=Strict`** blocks the cookie on **all** cross-site requests, including top-level redirects. This is too restrictive for OIDC flows.

## Additional Security

Always set `Cookie.SecurePolicy = CookieSecurePolicy.Always` to ensure the cookie is only sent over HTTPS. Combined with `SameSite=Lax`, this provides strong protection against CSRF while still allowing the OIDC redirect flow to work correctly.
