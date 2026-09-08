# OIDC callback failing behind nginx at a `/app` sub-path

This is a classic reverse-proxy + sub-path hosting problem. Two configuration pieces are usually missing, and a cookie setting can make it worse.

## 1. Forwarded headers (scheme/host)

nginx handles TLS and forwards the request to your app over plain HTTP. Without telling ASP.NET Core to trust the `X-Forwarded-*` headers, the framework sees the request as `http` on an internal host, so it builds the OIDC `redirect_uri` with the wrong scheme. The IdP redirect then doesn't match and the login round-trip breaks.

Add the forwarded-headers middleware **first in the pipeline**, before authentication runs:

```csharp
using Microsoft.AspNetCore.HttpOverrides;

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
```

And in nginx, make sure the headers are set:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## 2. Path base for the `/app` mount

Since the app is served under `/app`, tell ASP.NET Core about it so generated URLs (including the OIDC callback `signin-oidc`) include the prefix:

```csharp
app.UsePathBase("/app");
```

Then register the redirect URI at your IdP as `https://your-host/app/signin-oidc`.

## 3. Correlation cookie SameSite

OpenID Connect uses short-lived correlation/nonce cookies during the redirect dance. If the IdP is on a different domain, a `SameSite=Strict` correlation cookie won't come back on the callback and you'll get "Correlation failed" / immediate logout. Setting the cookie policy to `Lax` (the usual OIDC default) fixes cross-site redirects:

```csharp
options.Cookie.SameSite = SameSiteMode.Lax;
```

## Summary

- Enable `UseForwardedHeaders` with `XForwardedFor | XForwardedProto`, placed **before** `UseAuthentication`.
- Add `UsePathBase("/app")` and register the matching redirect URI at the IdP.
- Use `SameSite=Lax` for the auth/correlation cookies if the IdP is cross-site.

The forwarded-proto fix alone resolves most "callback fails behind nginx" cases; the path base handles the sub-path.
