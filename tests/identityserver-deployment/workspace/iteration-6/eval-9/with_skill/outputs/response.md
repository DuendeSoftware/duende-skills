# Rate limiting protocol endpoints

**Why `RequireRateLimiting` never triggers:** IdentityServer matches its protocol endpoints (`/connect/authorize`, `/connect/token`, …) with its **own middleware, not ASP.NET Core endpoint routing**. Named per-endpoint policies live in endpoint metadata, so they can't attach to those endpoints. **Only the global limiter applies** to them. Named policies still work on your own routed Razor Pages (login/consent).

IdentityServer has no built-in rate limiting. Options, combinable:

## (a) Network layer
Nginx/gateway/Cloudflare: coarse IP/path limiting that sheds volumetric abuse first.

## (b) Global limiter partitioned by path (before `UseIdentityServer`)

```csharp
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        // Partition on path to approximate per-endpoint limits
        return RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: $"{ip}:{context.Request.Path}",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 4
            });
    });

    // For /connect/token prefer JSON + Retry-After rather than an HTML 429
    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retry))
            ctx.HttpContext.Response.Headers.RetryAfter = ((int)retry.TotalSeconds).ToString();
        await ctx.HttpContext.Response.WriteAsJsonAsync(new { error = "rate_limited" }, ct);
    };
});

var app = builder.Build();
app.UseForwardedHeaders();   // so the IP is the real client IP
app.UseRateLimiter();        // BEFORE UseIdentityServer
app.UseIdentityServer();
```

## (c) Identity-aware validator
`ICustomTokenRequestValidator` runs after validation so `ClientId`/user are known (v8 adds a `CancellationToken` parameter):

```csharp
public class RateLimitingTokenRequestValidator : ICustomTokenRequestValidator
{
    public Task ValidateAsync(CustomTokenRequestValidationContext context, CancellationToken ct)
    {
        var clientId = context.Result.ValidatedRequest.ClientId;
        if (IsOverLimit(clientId))
        {
            context.Result.IsError = true;
            context.Result.Error = "rate_limited";
            context.Result.ErrorDescription = "Too many requests";
        }
        return Task.CompletedTask;
    }
}
// .AddCustomTokenRequestValidator<RateLimitingTokenRequestValidator>();
```
It runs after client authentication, secret validation and DB lookups, so pair it with (a)/(b) to shed load earlier.
