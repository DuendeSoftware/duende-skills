# Content Security Policy and Rate Limiting for IdentityServer

## 1. Content Security Policy (CSP) Middleware

Add CSP headers to protect login, consent, and IdentityServer UI pages against XSS and clickjacking:

```csharp
// Add CSP middleware for IdentityServer UI pages — place before UseIdentityServer()
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    var isIdentityUiPath =
        path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/connect", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/diagnostics", StringComparison.OrdinalIgnoreCase);

    if (isIdentityUiPath)
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self'; " +
            "img-src 'self' data:; " +
            "font-src 'self'; " +
            "frame-ancestors 'none'; " +
            "form-action 'self'; " +
            "base-uri 'self'; " +
            "object-src 'none'");

        // Clickjacking defense — belt-and-suspenders with CSP frame-ancestors
        context.Response.Headers.Append("X-Frame-Options", "DENY");

        // Force MIME type sniffing protection
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");

        // Referrer control
        context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    }

    await next();
});
```

## 2. Rate Limiting Configuration

Configure rate limiting with ASP.NET Core's built-in `AddRateLimiter`:

```csharp
// Add rate limiting services
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Sliding window for token endpoint — 20 requests/minute per IP
    options.AddPolicy("token-endpoint", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 4,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    // Fixed window for authorize endpoint — 10 requests/minute per IP
    options.AddPolicy("authorize-endpoint", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));
});
```

## 3. Middleware Pipeline and Route Mapping

```csharp
var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();

// Rate limiter middleware
app.UseRateLimiter();

// CSP middleware (inline above)
// ... CSP app.Use() here ...

app.UseIdentityServer();
app.UseAuthorization();

// Apply rate limit policies to specific IdentityServer endpoints
app.MapGroup("/connect/token")
    .RequireRateLimiting("token-endpoint");

app.MapGroup("/connect/authorize")
    .RequireRateLimiting("authorize-endpoint");

app.MapRazorPages();

app.Run();
```

## Summary

- **CSP** protects UI pages with `frame-ancestors 'none'`, `object-src 'none'`, and strict `default-src 'self'`
- **X-Frame-Options: DENY** provides clickjacking defense as a fallback
- **Token endpoint**: 20 requests/minute per IP via sliding window
- **Authorize endpoint**: 10 requests/minute per IP via fixed window
- Both partitioned by `RemoteIpAddress`
