# Why the Cookie transform is ignored

Since the security patch releases (2.2.1, 2.3.1, 3.0.1, 3.1.1, 4.0.4, 4.1.3, 4.2.1, 4.3.1) BFF removes the `Cookie` header from every YARP-proxied request so the session cookie never reaches the API. The removal happens **after** YARP copies request headers and **after the route's own transforms run**, so a route-level transform that sets `Cookie` is overwritten — it has no effect while `RemoveCookieHeaderFromYarpRequests` is `true` (default).

**Fix:** register the transform *later* than BFF's:

```csharp
builder.Services.AddReverseProxy()
    .AddBffExtensions()
    .AddTransforms(ctx =>
    {
        if (ctx.Route.RouteId == "my-api")
            ctx.AddRequestTransform(t =>
            {
                t.ProxyRequest.Headers.TryAddWithoutValidation("Cookie", "specific=value");
                return ValueTask.CompletedTask;
            });
    });
```
Transforms added after `AddBffExtensions` run later and can set a specific `Cookie` (intentional). Set only the specific cookie; don't copy the browser's cookies. Disabling `options.RemoveCookieHeaderFromYarpRequests` is not recommended since it forwards the session cookie to all APIs. Prefer bearer tokens (`WithAccessToken(TokenType.User)`).
