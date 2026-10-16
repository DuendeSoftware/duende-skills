# Rate limiting protocol endpoints

`RequireRateLimiting("policy")` is an endpoint metadata feature applied to endpoints you map via endpoint routing (`MapGet`, controllers). IdentityServer's protocol endpoints (`/connect/token`, `/connect/authorize`) are not mapped as conventional endpoints; Duende's `UseIdentityServer()` middleware / endpoint router handles them itself, so your metadata never applies. (Newer versions can map them via endpoint routing, but by default they aren't.)

Correct way: use the **global/limiter at middleware level** with a partition that matches the path, `PartitionedRateLimiter`, via `options.GlobalLimiter`:

```csharp
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
    {
        var path = ctx.Request.Path;
        if (path.StartsWithSegments("/connect/token") ||
            path.StartsWithSegments("/connect/authorize"))
        {
            var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            return RateLimitPartition.GetFixedWindowLimiter($"{path}:{ip}",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 30,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0
                });
        }
        return RateLimitPartition.GetNoLimiter("none");
    });
});

var app = builder.Build();
app.UseForwardedHeaders();
app.UseRateLimiter();      // before UseIdentityServer
app.UseIdentityServer();
```

Order matters: `UseRateLimiter()` before `UseIdentityServer()`, and forwarded headers first so the client IP is real. For the token endpoint, consider partitioning by client_id too, and rate limit at the edge (WAF/Nginx) as well.
