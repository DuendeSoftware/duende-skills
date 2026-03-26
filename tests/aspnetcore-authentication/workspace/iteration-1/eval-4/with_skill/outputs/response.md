# Fixing the OIDC Redirect Loop

## The Problem

Your redirect loop is caused by `SameSiteMode.Strict` on the authentication cookie. Here's what happens:

1. User visits your app → not authenticated → OIDC handler redirects to IdentityServer
2. User logs in at IdentityServer
3. IdentityServer redirects back to your app's callback URL (a **cross-site** redirect)
4. Your app's OIDC handler processes the callback and tries to set the authentication cookie
5. **The browser refuses to send the cookie** because `SameSite=Strict` blocks cookies on cross-site navigations
6. The user appears unauthenticated → redirected back to IdentityServer → loop

With `SameSite=Strict`, the browser will not include the cookie when the request originates from a different site (IdentityServer's domain). The OIDC callback is a cross-site redirect from IdentityServer back to your app, so the cookie is silently dropped.

## The Fix

Change `SameSiteMode.Strict` to `SameSiteMode.Lax`:

```csharp
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;      // Allow cookie on top-level navigations (OIDC callback)
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;  // Always require HTTPS
    options.Cookie.HttpOnly = true;                   // Not accessible via JavaScript
});
```

`SameSiteMode.Lax` allows the cookie to be sent on top-level navigations (like the OIDC callback redirect) while still protecting against CSRF attacks on cross-site POST requests.

Always set `Cookie.SecurePolicy = CookieSecurePolicy.Always` to ensure the cookie is only sent over HTTPS.
