# Rate Limiting for IdentityServer Endpoints

## Pattern 10: Rate Limiting

Duende IdentityServer has **no built-in rate limiting**. Protect the token and authorize endpoints from brute-force, credential stuffing, and enumeration attacks using ASP.NET Core's built-in rate limiting middleware — combined, ideally, with a network-layer limiter (reverse proxy / gateway) as a first line of defense.

> **Critical caveat — protocol endpoints only get the global limiter.**
> IdentityServer matches its protocol endpoints (`/connect/token`, `/connect/authorize`, …) with **its own middleware, NOT ASP.NET Core endpoint routing**. You therefore **cannot attach a named per-endpoint policy** (`RequireRateLimiting("token-endpoint")`) to a protocol endpoint — it will simply never run. Only the **global limiter** applies to protocol endpoints. Named policies still work on **your own routed Razor Pages** (login, consent).
>
> Register the rate limiter **before** `app.UseIdentityServer()`.

### Global limiter partitioned by path (applies to protocol endpoints)

Approximate per-endpoint limits by partitioning the global limiter on `context.Request.Path`:

```csharp
// ✅ Global limiter — the ONLY limiter that applies to /connect/* protocol endpoints
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        // Use X-Forwarded-For (after ForwardedHeaders) so the real client IP is used
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = context.Request.Path.Value ?? "/";

        // Token endpoint: 20 requests/minute per IP
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

        // Authorize endpoint: 10 requests/minute per IP
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

        // Everything else: no limit
        return RateLimitPartition.GetNoLimiter("unlimited");
    });
});

// Must run BEFORE UseIdentityServer()
app.UseRateLimiter();
app.UseIdentityServer();
```

> **Tip:** For the token endpoint, prefer returning a JSON error body plus a `Retry-After` header rather than the default HTML 429, so OAuth clients can back off correctly (customize via `OnRejected`).

### Named policies for your own Razor Pages

Named policies **do** work on your own routed UI pages (login/consent), which use ASP.NET Core endpoint routing:

```csharp
// ✅ Named policies apply to YOUR routed pages, not protocol endpoints
app.MapRazorPages().RequireRateLimiting("login-page");
```

### Identity-aware limiting via ICustomTokenRequestValidator

For per-client / per-user limits, implement `ICustomTokenRequestValidator`. It runs **after** token request validation, so `ClientId` and the user are known — but also **after** client authentication, secret validation, and DB lookups, so pair it with a coarser layer (network or global limiter) to shed load earlier:

```csharp
public sealed class RateLimitingTokenRequestValidator : ICustomTokenRequestValidator
{
    // v8 added the CancellationToken parameter to this interface
    public Task ValidateAsync(CustomTokenRequestValidationContext context, CancellationToken ct)
    {
        var clientId = context.Result.ValidatedRequest.ClientId;
        if (IsOverLimit(clientId))
        {
            context.Result.IsError = true;
            context.Result.Error = "rate_limited";
            context.Result.ErrorDescription = "Too many token requests";
        }
        return Task.CompletedTask;
    }
}

// idsvrBuilder.AddCustomTokenRequestValidator<RateLimitingTokenRequestValidator>();
```

> **Tip:** In cloud deployments behind a load balancer, `RemoteIpAddress` is the proxy address. Use `X-Forwarded-For` (after configuring `ForwardedHeaders`) or a client identifier for accurate partitioning.
