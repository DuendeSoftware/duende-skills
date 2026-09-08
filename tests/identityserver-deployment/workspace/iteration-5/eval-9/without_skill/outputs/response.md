# Rate limiting the IdentityServer token/authorize endpoints

## Why the named policy doesn't fire

ASP.NET Core's `RequireRateLimiting("myPolicy")` is **endpoint-routing based** — the policy is stored as metadata on a routed endpoint, and the rate-limiter middleware only applies a named policy when it matches an endpoint that carries that metadata.

`/connect/token` and `/connect/authorize` are **not endpoints you map** with `MapPost`/`MapControllerRoute`. They're handled by the `UseIdentityServer()` middleware, which processes the request based on the path before/without going through normal endpoint routing. Since there's no routed endpoint carrying your policy metadata, the named policy is never selected and never triggers.

So attaching a per-endpoint policy to those paths has no effect. Only a **global limiter** will actually see those requests.

## Use a global limiter partitioned by path

Define the limiter globally and partition it by request path (and usually client IP) so different endpoints get separate buckets:

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    {
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: $"{ip}:{context.Request.Path}",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1)
            });
    });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});
```

Partitioning on `context.Request.Path` lets you approximate per-endpoint limits (e.g. tighter limits for `/connect/token`) even though you can't attach a named policy to them.

## Middleware order matters

Register the rate limiter **before** IdentityServer so it inspects the request first:

```csharp
app.UseRateLimiter();
app.UseIdentityServer();
```

If `UseRateLimiter()` comes after `UseIdentityServer()`, IdentityServer will already have handled and completed the protocol request, and the limiter won't run for it.

## Where named policies still work

Your **own** routed pages (login, consent, custom APIs mapped with `MapGet`/`MapPost`/Razor Pages) are real endpoints, so `RequireRateLimiting("...")` works there as normal. Keep using named policies for those; only the IdentityServer protocol endpoints need the global-limiter approach.

## Additional layers

For robust protection, also rate limit at the reverse proxy / gateway (nginx, Cloudflare, Azure/AWS gateways) as a first line of defense, since that stops volumetric abuse before it reaches your app.

## Summary

- The named policy fails because `/connect/token` isn't a routed endpoint carrying the policy metadata — it's handled by IdentityServer's middleware.
- Use a **global limiter partitioned on `context.Request.Path`**.
- Register `UseRateLimiter()` **before** `UseIdentityServer()`.
