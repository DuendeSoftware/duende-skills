## Cause

The OIDC callback is a cross-site POST (`response_mode=form_post`) or cross-site redirect from the IdentityServer origin back to your app. With `SameSite=Strict`, browsers don't send cookies on cross-site requests. The OIDC handler stores correlation and nonce cookies, and the browser won't send them back on the callback; also the session cookie set during that response may not be sent on the follow-up navigation, so the app thinks you're unauthenticated, challenges again, and you loop.

## Fix

Use `SameSite=Lax` (the default for the cookie handler) for the main auth cookie. If you use `form_post` with a cross-site POST, the correlation/nonce cookies need `SameSite=None; Secure`, which the OIDC handler does by default.

```csharp
builder.Services.AddAuthentication(o =>
{
    o.DefaultScheme = "Cookies";
    o.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", o =>
{
    o.Cookie.SameSite = SameSiteMode.Lax;
    o.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    o.Cookie.HttpOnly = true;
})
.AddOpenIdConnect("oidc", o =>
{
    o.Authority = "https://identity.example.com";
    o.ClientId = "web.app";
    o.ClientSecret = "secret";
    o.ResponseType = "code";
    o.SaveTokens = true;
});
```

Also make sure the site runs over HTTPS and call `UseAuthentication()` before `UseAuthorization()`.
