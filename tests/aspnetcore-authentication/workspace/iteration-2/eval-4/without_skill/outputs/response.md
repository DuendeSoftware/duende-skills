# Fixing the Redirect Loop After Login

## The Problem

A redirect loop after OIDC login usually means the authentication cookie isn't being set or sent properly. Since you're using `SameSiteMode.Strict`, this is likely the culprit.

When IdentityServer redirects back to your application after login, the browser may not include the cookie because `SameSite=Strict` prevents cookies from being sent on cross-site navigations. The redirect from IdentityServer's domain to your app's domain counts as a cross-site request.

## The Fix

Change the SameSite setting to `Lax`:

```csharp
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
});
```

`SameSite=Lax` allows the cookie on top-level navigations (like redirects) while still protecting against CSRF on sub-requests.

You should also make sure your application is using HTTPS, as modern browsers may also block cookies without the Secure flag.
