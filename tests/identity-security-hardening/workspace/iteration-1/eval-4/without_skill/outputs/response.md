# Adding CSP and Rate Limiting

## Content Security Policy

Add security headers as middleware:

```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " +
        "img-src 'self' data:; frame-ancestors 'none'");

    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");

    await next();
});
```

## Rate Limiting

Use ASP.NET Core's rate limiting middleware:

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = 429;

    options.AddFixedWindowLimiter("token-limit", opt =>
    {
        opt.PermitLimit = 20;
        opt.Window = TimeSpan.FromMinutes(1);
    });

    options.AddFixedWindowLimiter("authorize-limit", opt =>
    {
        opt.PermitLimit = 10;
        opt.Window = TimeSpan.FromMinutes(1);
    });
});
```

Then in the pipeline:

```csharp
app.UseRateLimiter();
```

Apply to routes:

```csharp
app.MapGroup("/connect/token").RequireRateLimiting("token-limit");
app.MapGroup("/connect/authorize").RequireRateLimiting("authorize-limit");
```
