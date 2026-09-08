## Why you're stuck in a redirect loop

The problem is `SameSiteMode.Strict` on your authentication cookie.

Here's the login sequence:

1. Your app challenges → redirects the browser to IdentityServer at `https://identity.example.com`.
2. The user signs in there.
3. IdentityServer redirects the browser back to your app's callback (`/signin-oidc`).

That last step is a navigation **coming from a different origin** (identity.example.com) to your app. A cookie marked `SameSite=Strict` is only ever sent when the request originates from the **same site**. So when the browser lands on your callback (and even for the correlation/nonce cookies set just before the redirect out), the `Strict` cookie is not honored — the authentication cookie never gets established.

Your app therefore still sees an anonymous user, challenges again, and the whole cycle repeats → infinite redirect loop.

## The fix: switch to `SameSiteMode.Lax`

`Lax` allows cookies to be sent on **top-level navigations** (like the GET redirect back from IdentityServer) while still protecting against most CSRF scenarios. This is the recommended setting for interactive OIDC sign-in.

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    // Change this from Strict to Lax
    options.Cookie.SameSite = SameSiteMode.Lax;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
});
```

### A few related tips

- Don't use `SameSite=None` unless you actually need cross-site cookie delivery (embedded iframes, etc.); if you do, the cookie must also be marked `Secure`.
- Make sure your app is served over HTTPS end-to-end. If you're behind a proxy, configure forwarded headers so ASP.NET Core sees the correct scheme.

Once the cookie is `Lax`, the callback can set it, the user becomes authenticated, and the loop disappears.
