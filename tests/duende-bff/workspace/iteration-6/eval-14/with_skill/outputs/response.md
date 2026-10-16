Use `.SkipResponseHandling()` (v4).

By default BFF converts 401/403 from local API endpoints into plain status responses (no redirect) so SPAs can handle them. To let the normal ASP.NET Core challenge — an actual OIDC redirect — happen:

```csharp
app.MapGet("/api/interactive", () => Results.Ok("data"))
   .RequireAuthorization()
   .AsBffApiEndpoint()
   .SkipResponseHandling();
```

Notes:
- Keep `.AsBffApiEndpoint()` so the `X-CSRF: 1` check still applies (use `.SkipAntiforgery()` or `DisableAntiForgeryCheck` only if truly needed).
- A redirect only makes sense for a browser navigation, not `fetch()`. For fetch calls, keep the default and send the user to `/bff/login` on 401.
