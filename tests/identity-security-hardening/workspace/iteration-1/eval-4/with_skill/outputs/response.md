# Content Security Policy and Rate Limiting for IdentityServer

## 1. Content Security Policy Middleware

Add CSP headers to protect login, consent, and other IdentityServer UI pages against XSS and clickjacking:

```csharp
// Add after UseRouting(), before UseIdentityServer()
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

        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    }

    await next();
});
```

### Key CSP Directives

- `frame-ancestors 'none'` — prevents the page from being embedded in iframes (clickjacking defense)
- `object-src 'none'` — blocks plugins like Flash/Java
- `form-action 'self'` — ensures login forms only POST to the same origin
- `X-Frame-Options: DENY` — belt-and-suspenders with `frame-ancestors`

## 2. Rate Limiting Configuration

### Service Registration

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Token endpoint: sliding window — 20 requests/minute per IP
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

    // Authorize endpoint: fixed window — 10 requests/minute per IP
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

### Middleware Pipeline

```csharp
var app = builder.Build();

app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();
app.UseStaticFiles();
app.UseRouting();

// Rate limiting before IdentityServer
app.UseRateLimiter();

// CSP middleware
app.Use(async (context, next) => { /* CSP headers as above */ });

app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
```

### Apply Rate Limit Policies to Endpoints

```csharp
app.MapGroup("/connect/token")
    .RequireRateLimiting("token-endpoint");

app.MapGroup("/connect/authorize")
    .RequireRateLimiting("authorize-endpoint");
```

## Why Rate Limiting Matters

- **Token endpoint**: Credential stuffing and brute-force attacks target `/connect/token` with automated password guessing
- **Authorize endpoint**: Abuse of the authorization endpoint can lead to session fixation or redirect URI manipulation at scale
- The sliding window for the token endpoint allows bursts within the window while maintaining the overall limit
- The fixed window for authorize is stricter since interactive logins have lower legitimate throughput
