# CSP and rate limiting for IdentityServer

```csharp
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddPolicy("token", httpContext =>
        RateLimitPartition.GetSlidingWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 6,
                QueueLimit = 0
            }));

    options.AddPolicy("authorize", httpContext =>
        RateLimitPartition.GetSlidingWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 6,
                QueueLimit = 0
            }));
});

var app = builder.Build();

app.UseStaticFiles();

// Security headers for UI pages
app.Use(async (ctx, next) =>
{
    ctx.Response.OnStarting(() =>
    {
        var h = ctx.Response.Headers;
        var ct = h.ContentType.ToString();
        if (ct.StartsWith("text/html"))
        {
            h["Content-Security-Policy"] =
                "default-src 'self'; " +
                "script-src 'self'; " +
                "style-src 'self'; " +
                "img-src 'self' data:; " +
                "font-src 'self'; " +
                "object-src 'none'; " +
                "base-uri 'self'; " +
                "form-action 'self'; " +
                "frame-ancestors 'none'";
            h["X-Content-Type-Options"] = "nosniff";
            h["X-Frame-Options"] = "DENY";
            h["Referrer-Policy"] = "no-referrer";
        }
        return Task.CompletedTask;
    });
    await next();
});

app.UseRouting();
app.UseRateLimiter();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```

Since IdentityServer endpoints are middleware and not endpoint-routed, `RequireRateLimiting` can't be attached to them. Instead use a global limiter that picks the policy by path:

```csharp
options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
{
    var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    var path = ctx.Request.Path;
    if (path.StartsWithSegments("/connect/token"))
        return RateLimitPartition.GetSlidingWindowLimiter($"token:{ip}", _ => new SlidingWindowRateLimiterOptions
            { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6, QueueLimit = 0 });
    if (path.StartsWithSegments("/connect/authorize"))
        return RateLimitPartition.GetSlidingWindowLimiter($"authz:{ip}", _ => new SlidingWindowRateLimiterOptions
            { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6, QueueLimit = 0 });
    return RateLimitPartition.GetNoLimiter("none");
});
```

(Use that instead of the two named policies.)

## Caveats
- Behind a reverse proxy, call `UseForwardedHeaders` first, otherwise all clients share the proxy IP.
- Inline scripts/styles in your Razor pages will be blocked by this CSP; move them to files or use nonces.
- `frame-ancestors 'none'` is the modern clickjacking defence; X-Frame-Options is a legacy backup. On the *logout/check-session* pages that need to be framed, adjust accordingly.
- In multi-instance deployments in-memory limits are per instance; consider a gateway/WAF layer.
