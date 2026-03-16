# Adding CSP Headers and Rate Limiting

## Content Security Policy

You can add security headers using middleware:

```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'");
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    await next();
});
```

This sets basic CSP headers on all responses. The `frame-ancestors 'none'` directive prevents clickjacking.

## Rate Limiting

ASP.NET Core 7+ has built-in rate limiting:

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = 429;

    options.AddFixedWindowLimiter("token-limit", config =>
    {
        config.PermitLimit = 20;
        config.Window = TimeSpan.FromMinutes(1);
    });

    options.AddFixedWindowLimiter("authorize-limit", config =>
    {
        config.PermitLimit = 10;
        config.Window = TimeSpan.FromMinutes(1);
    });
});

// In the pipeline
app.UseRateLimiter();
```

You would then apply these to routes:

```csharp
app.MapGroup("/connect/token").RequireRateLimiting("token-limit");
app.MapGroup("/connect/authorize").RequireRateLimiting("authorize-limit");
```

Note: For the token endpoint, you might want a sliding window instead of fixed window for smoother rate control. The above uses fixed windows for simplicity.
