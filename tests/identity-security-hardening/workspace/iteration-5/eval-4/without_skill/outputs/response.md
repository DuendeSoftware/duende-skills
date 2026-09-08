# Adding CSP Headers and Rate Limiting

## Content Security Policy for the login/consent UI

Add a middleware that sets CSP and related security headers on the IdentityServer UI pages to defend against XSS and clickjacking:

```csharp
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    if (path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/connect", StringComparison.OrdinalIgnoreCase))
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self'; " +
            "img-src 'self' data:; " +
            "frame-ancestors 'none'; " +   // clickjacking protection
            "object-src 'none'");

        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Append("Referrer-Policy", "no-referrer");
    }

    await next();
});
```

`frame-ancestors 'none'` plus `X-Frame-Options: DENY` prevent the pages from being framed, and `default-src 'self'` restricts script/resource loading to same-origin.

## Rate limiting for the token and authorize endpoints

Use ASP.NET Core's built-in rate limiter. Define a sliding-window policy for the token endpoint (20/min) and a fixed-window policy for the authorize endpoint (10/min), both partitioned by client IP:

```csharp
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Token endpoint — 20 requests/minute per IP (sliding window)
    options.AddPolicy("token", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 4
            }));

    // Authorize endpoint — 10 requests/minute per IP (fixed window)
    options.AddPolicy("authorize", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1)
            }));
});
```

Wire it into the pipeline and apply the policies to the endpoints:

```csharp
var app = builder.Build();

app.UseRateLimiter();
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Apply the rate-limit policies to the OAuth endpoints
app.MapWhen(ctx => ctx.Request.Path.StartsWithSegments("/connect/token"),
    b => b.UseRateLimiter()).RequireRateLimiting("token");
app.MapWhen(ctx => ctx.Request.Path.StartsWithSegments("/connect/authorize"),
    b => b.UseRateLimiter()).RequireRateLimiting("authorize");

app.MapRazorPages();
app.Run();
```

## Notes

- CSP with `frame-ancestors 'none'` and `X-Frame-Options: DENY` blocks clickjacking; `object-src 'none'` and `default-src 'self'` reduce the XSS surface.
- The token endpoint gets a sliding window of 20/min and the authorize endpoint a fixed window of 10/min, each partitioned by the caller's IP.
- Behind a load balancer, `RemoteIpAddress` will be the proxy — use `X-Forwarded-For` (with forwarded headers configured) for accurate per-client partitioning.
- Call `UseRateLimiter()` early in the pipeline so limits apply before the request is processed.
