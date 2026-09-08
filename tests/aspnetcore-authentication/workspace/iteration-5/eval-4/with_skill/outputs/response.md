## What's happening

Your login round-trip looks like this:

1. Browser hits your app → OIDC handler redirects to `https://identity.example.com`.
2. User authenticates on IdentityServer.
3. IdentityServer **redirects back** to your callback (`/signin-oidc`) — this is a top-level navigation coming **from a different site** (identity.example.com → your app).
4. The cookie handler tries to set the authentication cookie during that callback.

With **`SameSiteMode.Strict`**, the browser refuses to send/accept the cookie on a request that originated from another site. So the auth cookie is never stored on the callback. Your app then sees an unauthenticated user, challenges again, redirects to IdentityServer again, and you get an infinite **redirect loop**.

The nonce/correlation cookies the OIDC handler writes before the challenge are affected too — `Strict` breaks the whole cross-site callback.

## The fix — use `SameSiteMode.Lax`

`Lax` still blocks cookies on cross-site sub-requests (images, iframes, XHR) but **allows them on top-level GET navigations**, which is exactly what the OIDC callback redirect is. This is the correct setting for interactive OIDC login.

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.Name = "web.app";

    // ✅ Lax — not Strict — so the cookie survives the cross-site OIDC callback
    options.Cookie.SameSite = SameSiteMode.Lax;

    // ✅ Require HTTPS for the cookie in production
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
});
```

### Notes

- **`SameSite = SameSiteMode.Lax`** is the actual fix for the loop.
- **`SecurePolicy = CookieSecurePolicy.Always`** ensures the cookie is only sent over HTTPS. This matters because modern browsers pair `SameSite` with `Secure`; over plain HTTP some browsers will reject cookies. Since your IdentityServer is HTTPS, keep the app on HTTPS and set this to `Always`.
- Do **not** use `SameSiteMode.None` unless you truly need cross-site cookie sending (e.g. embedded iframes) — and `None` *requires* `Secure`.
- If you're behind a reverse proxy/load balancer, also configure `ForwardedHeaders` so the app knows the request is HTTPS; otherwise `SecurePolicy.Always` can drop the cookie because the app thinks the scheme is `http`.

After switching to `Lax`, the callback cookie is written, the user is authenticated, and the loop stops.
