# Redirect Loop After Login

## Diagnosis

The redirect loop is likely caused by the cookie not being set properly after the OIDC callback. Since you're using `SameSiteMode.Strict`, the cookie won't be attached when the browser follows the redirect from IdentityServer back to your application.

When the browser is redirected from IdentityServer (a different domain) back to your app, the `SameSite=Strict` setting prevents the cookie from being sent on that cross-site navigation. This means the authentication cookie is never established, so your app keeps redirecting to IdentityServer in a loop.

## Fix

Change the SameSite mode to `Lax`:

```csharp
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;
})
```

`SameSiteMode.Lax` allows the cookie to be sent on top-level navigations from other sites, which is what happens during the OIDC callback redirect. It still provides protection against CSRF attacks for non-GET requests.

You should also make sure your cookie is only sent over HTTPS in production for security reasons.
