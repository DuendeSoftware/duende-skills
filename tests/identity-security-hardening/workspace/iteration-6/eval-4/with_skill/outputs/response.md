# CSP + rate limiting for IdentityServer

## 1. Content Security Policy (login/consent UI)
Middleware that applies strong headers to IdentityServer UI paths:

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
            "script-src 'self'; " +      // no inline scripts -> XSS defense
            "style-src 'self'; " +
            "img-src 'self' data:; " +
            "font-src 'self'; " +
            "frame-ancestors 'none'; " + // clickjacking
            "form-action 'self'; " +
            "base-uri 'self'; " +
            "object-src 'none'");
        context.Response.Headers.Append("X-Frame-Options", "DENY");           // legacy belt-and-suspenders
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    }

    await next();
});
```
Place it before `UseStaticFiles/UseRouting/UseIdentityServer`. Adjust paths to your Razor Pages folder layout (e.g. `/Account/Login`, `/Consent`; the path comparison is case-insensitive). If you use a CDN, add hashed/nonce-based entries rather than broad origins. Inline `<script>`/`<style>` in your pages must be moved to files or given nonces.

## 2. Rate limiting
IdentityServer has **no built-in rate limiting**. Critically, its protocol endpoints (`/connect/token`, `/connect/authorize`) are matched by IdentityServer's own middleware, **not endpoint routing**, so a named policy attached with `RequireRateLimiting` would never run. Only the **global limiter** applies. We partition it by path:

```csharp
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        // Real client IP (requires UseForwardedHeaders when behind a proxy)
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = context.Request.Path.Value ?? "/";

        // Token endpoint: sliding window, 20/min per IP
        if (path.StartsWith("/connect/token", StringComparison.OrdinalIgnoreCase))
        {
            return RateLimitPartition.GetSlidingWindowLimiter($"token:{ip}",
                _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 20,
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 4,
                    QueueLimit = 0
                });
        }

        // Authorize endpoint: 10/min per IP (sliding window as well)
        if (path.StartsWith("/connect/authorize", StringComparison.OrdinalIgnoreCase))
        {
            return RateLimitPartition.GetSlidingWindowLimiter($"authorize:{ip}",
                _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 10,
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 4,
                    QueueLimit = 0
                });
        }

        return RateLimitPartition.GetNoLimiter("unlimited");
    });

    // OAuth-friendly rejection: JSON + Retry-After instead of the default HTML 429
    options.OnRejected = async (ctx, ct) =>
    {
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retry))
            ctx.HttpContext.Response.Headers.RetryAfter = ((int)retry.TotalSeconds).ToString();
        ctx.HttpContext.Response.ContentType = "application/json";
        await ctx.HttpContext.Response.WriteAsync("{\"error\":\"rate_limited\"}", ct);
    };
});
```

Pipeline order:
```csharp
app.UseForwardedHeaders();     // if behind a proxy – otherwise all clients share the proxy IP
app.UseHttpsRedirection();
app.UseHsts();
// CSP middleware here
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();          // BEFORE UseIdentityServer
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();           // named policies via .RequireRateLimiting("login-page") work here, on your own pages
```

## Things to know
- Per-client/per-user limits: implement `ICustomTokenRequestValidator` (runs after the client and user are known, but after authentication/DB work, so keep the global limiter as the coarse first line). In v8 `ValidateAsync` also takes a `CancellationToken`.
- Limits are per instance; in a load-balanced deployment add a network/gateway limiter too.
- A shared NAT/corporate IP can hit 10 authorize requests/min legitimately; monitor 429s.
