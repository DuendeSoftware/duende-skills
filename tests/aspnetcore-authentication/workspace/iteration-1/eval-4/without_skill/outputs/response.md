# Redirect Loop After Login

The most common cause of a redirect loop after OIDC login is related to cookie settings. Since you're using `SameSiteMode.Strict`, the issue is that the cookie isn't being set after the callback from IdentityServer.

`SameSite=Strict` means the cookie is only sent for same-site requests. The OIDC callback is a redirect from your IdentityServer (a different domain), so the browser treats it as a cross-site request and doesn't send the cookie.

## Fix

Change to `SameSiteMode.Lax`:

```csharp
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});
```

`Lax` allows cookies on top-level navigations (like the redirect back from your IdP) while still preventing CSRF on POST requests.
