Use `.SkipResponseHandling()` to bypass BFF's automatic 401/403 response conversion and allow normal ASP.NET Core authentication redirects to occur:

```csharp
app.MapGet("/api/interactive", (HttpContext ctx) =>
{
    return Results.Ok("This endpoint requires auth and will trigger OIDC redirect");
})
.RequireAuthorization()      // Triggers OIDC challenge when unauthenticated
.AsBffApiEndpoint()          // Still enforces X-CSRF anti-forgery header
.SkipResponseHandling();     // Bypasses BFF's 401/403 → JSON conversion
```

By default, BFF converts 401 and 403 responses from local API endpoints into JSON-friendly responses. This is the correct behavior for SPA API calls — the SPA handles 401 by redirecting to `/bff/login` in JavaScript. But when you want a traditional server-side OIDC redirect (the browser navigates directly to the IDP), you need to bypass this conversion.

What `.SkipResponseHandling()` does:
- Without it: BFF intercepts the 401 Challenge result and returns a plain 401 status code (suitable for `fetch()` handling)
- With it: The 401 Challenge result flows through ASP.NET Core's authentication middleware, which triggers the OIDC redirect to the IDP

The endpoint still uses `.AsBffApiEndpoint()` for CSRF protection — `SkipResponseHandling` only affects the 401/403 conversion, not anti-forgery enforcement.

Use `.RequireAuthorization()` to ensure the endpoint triggers an authentication challenge when the user is not logged in. Without it, the endpoint would just run anonymously.
