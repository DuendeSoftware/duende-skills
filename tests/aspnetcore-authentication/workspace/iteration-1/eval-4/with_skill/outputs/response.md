# Redirect Loop After Login — SameSite Cookie Issue

## The Problem

Your redirect loop is caused by `SameSiteMode.Strict` on the authentication cookie. Here's what's happening:

1. Your app redirects the user to IdentityServer for login (different domain)
2. IdentityServer authenticates the user and redirects back to your app's callback endpoint
3. The OIDC handler processes the callback and tries to set the authentication cookie
4. **Because the redirect comes from a different site (IdentityServer), the browser refuses to send/set a cookie marked `SameSite=Strict`**
5. The cookie is never set, so on the next request the user appears unauthenticated
6. The app challenges again → redirect to IdentityServer → already logged in → callback → cookie fails again → **loop**

`SameSite=Strict` means the cookie is **never** sent on cross-site requests, including top-level navigations from a different origin. The OIDC callback redirect from IdentityServer is exactly this kind of cross-site navigation.

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
    options.Cookie.Name = "webapp";
    // FIX: Use Lax instead of Strict for OIDC callbacks
    options.Cookie.SameSite = SameSiteMode.Lax;
    // Always use HTTPS for the cookie
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
})
.AddOpenIdConnect("oidc", options =>
{
    // ... OIDC configuration ...
});
```

## Why `Lax` is Safe

`SameSiteMode.Lax` allows the cookie to be sent on top-level navigations (GET requests) from other sites, which is exactly what the OIDC callback redirect is. It still prevents the cookie from being sent on cross-site POST requests and embedded requests (iframes, images, etc.), providing good CSRF protection.

Combined with `Cookie.SecurePolicy = CookieSecurePolicy.Always`, your cookie is:
- Only sent over HTTPS
- Protected from cross-site POST/embedded attacks
- Properly set during the OIDC callback redirect flow
