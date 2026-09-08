# Content Security Policy + Rate Limiting for IdentityServer

Two additions: CSP/anti-clickjacking headers on the UI pages, and rate limiting on the token and authorize endpoints. There is a **critical IdentityServer-specific caveat** for the rate limiter that changes how you must implement it — covered below.

## 1. CSP + security headers middleware (login/consent UI)

Add this middleware to stamp CSP, anti-clickjacking, and MIME-sniffing headers on the IdentityServer UI paths:

```csharp
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    var isIdentityUiPath =
        path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/diagnostics", StringComparison.OrdinalIgnoreCase);

    if (isIdentityUiPath)
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self'; " +
            "img-src 'self' data:; " +
            "font-src 'self'; " +
            "frame-ancestors 'none'; " +   // block iframe embedding (clickjacking)
            "form-action 'self'; " +
            "base-uri 'self'; " +
            "object-src 'none'");           // no plugins

        // Belt-and-suspenders clickjacking defense alongside frame-ancestors
        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    }

    await next();
});
```

`frame-ancestors 'none'` + `X-Frame-Options: DENY` protect against clickjacking; `default-src 'self'` + `object-src 'none'` protect against XSS/plugin injection.

## 2. Rate limiting — the protocol-endpoint caveat

> **Critical:** IdentityServer matches its protocol endpoints (`/connect/token`, `/connect/authorize`) with **its own middleware, NOT ASP.NET Core endpoint routing**. You therefore **cannot** attach a named per-endpoint policy (`RequireRateLimiting("token")`) to those endpoints — it will never run. **Only the global limiter applies to protocol endpoints.** Named policies still work on your own routed Razor Pages (login/consent).

So the token/authorize limits must be built into the **global limiter**, partitioned on `context.Request.Path`:

```csharp
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        // After ForwardedHeaders, RemoteIpAddress is the real client IP
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = context.Request.Path.Value ?? "/";

        // Token endpoint: sliding window, 20 requests/minute per IP
        if (path.StartsWith("/connect/token", StringComparison.OrdinalIgnoreCase))
        {
            return RateLimitPartition.GetSlidingWindowLimiter(
                partitionKey: $"token:{ip}",
                factory: _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 20,
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 4,
                    QueueLimit = 0
                });
        }

        // Authorize endpoint: fixed window, 10 requests/minute per IP
        if (path.StartsWith("/connect/authorize", StringComparison.OrdinalIgnoreCase))
        {
            return RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: $"authorize:{ip}",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 10,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0
                });
        }

        return RateLimitPartition.GetNoLimiter("unlimited");
    });
});
```

## 3. Pipeline ordering

`UseRateLimiter()` must run **before** `UseIdentityServer()`:

```csharp
var app = builder.Build();

app.UseForwardedHeaders();     // so RemoteIpAddress is the real client IP
app.Use(/* CSP middleware above */);

app.UseRateLimiter();          // BEFORE UseIdentityServer
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Named policies DO work on your own routed pages:
app.MapRazorPages().RequireRateLimiting("login-page");

app.Run();
```

## Key takeaways

- **CSP** stamps `frame-ancestors 'none'`, `object-src 'none'`, `default-src 'self'` plus `X-Frame-Options: DENY` and `X-Content-Type-Options: nosniff` on `/account`, `/consent`, `/diagnostics`.
- **Rate limiting for `/connect/token` (20/min) and `/connect/authorize` (10/min) must live in the GLOBAL limiter partitioned by path**, because those protocol endpoints are not matched by ASP.NET Core endpoint routing and named `RequireRateLimiting` policies never fire on them.
- For a token-endpoint 429, consider `OnRejected` returning JSON + a `Retry-After` header so OAuth clients back off correctly.
