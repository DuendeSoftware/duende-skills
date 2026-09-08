# Rate limiting IdentityServer's token and authorize endpoints

## Why your named policy never triggers

This is a well-known gotcha. **IdentityServer matches its protocol endpoints (`/connect/token`, `/connect/authorize`, …) with its own middleware — NOT ASP.NET Core endpoint routing.** The `UseIdentityServer()` middleware inspects the path and handles the request itself; those paths are never mapped as routed endpoints.

ASP.NET Core's `RequireRateLimiting("policy")` works by attaching **endpoint metadata** that the rate-limiter middleware reads off the *matched routed endpoint*. Since `/connect/token` is not a routed endpoint, there is no metadata to read, so **named per-endpoint policies never run** on the protocol endpoints. That's exactly why attaching a policy to `/connect/token` does nothing.

Only the **global limiter** applies to IdentityServer's protocol endpoints.

## The correct approach: partition the global limiter on the path

Because only the global limiter runs on protocol endpoints, approximate per-endpoint limits by **partitioning the global limiter on `context.Request.Path`** (and typically the client IP):

```csharp
builder.Services.AddRateLimiter(options =>
{
    // The GLOBAL limiter is the ONLY limiter that applies to /connect/* endpoints
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        // Partition on path so /connect/token and /connect/authorize
        // effectively get their own limits
        return RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: $"{ip}:{context.Request.Path}",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 4
            });
    });
});
```

## Register the middleware before UseIdentityServer

```csharp
app.UseRateLimiter();     // must come BEFORE UseIdentityServer
app.UseIdentityServer();
```

If you register it after `UseIdentityServer()`, IdentityServer has already handled the protocol request and the limiter never sees it.

Note: named policies (`RequireRateLimiting("...")`) *do* still work on **your own routed Razor Pages** — the login and consent pages — because those are real endpoint-routed endpoints. It's only the protocol endpoints that bypass them.

## Identity-aware limits (optional, more precise)

IdentityServer has **no built-in rate limiting**, so for per-client limits after the request is validated, add an `ICustomTokenRequestValidator`. It runs *after* token request validation, so `ClientId`/user are known:

```csharp
public class RateLimitingTokenRequestValidator : ICustomTokenRequestValidator
{
    // v8 added the CancellationToken parameter
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

// idsvrBuilder.AddCustomTokenRequestValidator<RateLimitingTokenRequestValidator>();
```

Because it runs *after* client authentication, secret validation, and DB lookups, pair it with the coarser global limiter (or a reverse-proxy limiter) to shed abusive load earlier.

## Summary

- Named per-endpoint policies **don't** apply to `/connect/token` or `/connect/authorize` — IdentityServer uses its own middleware, not endpoint routing.
- Only the **global limiter** applies; partition it on `context.Request.Path`.
- Register `UseRateLimiter()` **before** `UseIdentityServer()`.
- For identity-aware limits, use `AddCustomTokenRequestValidator<>` (there's no built-in rate limiting).
