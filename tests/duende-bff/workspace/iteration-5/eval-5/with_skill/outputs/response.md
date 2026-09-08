# BFF behind nginx at `/app` — fixing the failing OIDC callback

Two things are almost certainly missing: **forwarded headers** (so the BFF knows the real scheme/host from nginx) and a **path base** (so the callback resolves under `/app`). A SameSite cookie mismatch can compound the problem when the IdP is cross-site.

## 1. Honor the proxy's forwarded headers — before authentication

nginx terminates TLS and forwards over HTTP, so without forwarded headers the BFF thinks the request is `http://…`. That corrupts the OIDC `redirect_uri`/callback and the login "completes" but the resulting cookie/redirect is wrong, logging the user straight back out. Add `UseForwardedHeaders` **before** `UseAuthentication`:

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var app = builder.Build();

// ✅ Trust X-Forwarded-* from nginx — MUST be before UseAuthentication/UseBff
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

// ✅ BFF is mounted under /app — set the path base so /app/signin-oidc etc. resolve
app.UsePathBase("/app");

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

Make sure nginx actually sends them:

```nginx
location /app/ {
    proxy_pass         http://bff-upstream/;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;   # https
}
```

## 2. Path base for the sub-path mount

Because the app lives at `/app`, `UsePathBase("/app")` ensures the OIDC callback path (`/app/signin-oidc`) and the BFF management endpoints (`/app/bff/login`, `/app/bff/user`, …) are generated and matched correctly. Register your app's `redirect_uri` at the IdP as `https://yourhost/app/signin-oidc`.

## 3. SameSite cookies for a cross-site IdP

If your IdP is on a **different site** than the BFF, the post-login redirect back is a cross-site navigation. With `SameSite=Strict` the browser won't send the freshly issued session (and the OIDC correlation) cookie on that first request, so the user appears logged out. Use `Lax`:

```csharp
builder.Services.AddBff()
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax; // cross-site IdP redirect needs Lax
    });
```

## Checklist

- `UseForwardedHeaders(XForwardedFor | XForwardedProto)` **before** `UseAuthentication`.
- `UsePathBase("/app")`.
- nginx forwards `X-Forwarded-Proto $scheme` and `Host`.
- Cookie `SameSite = Lax` when the IdP is cross-site.
- IdP redirect URI registered under `/app`.
