BFF's `AsBffApiEndpoint()` (and the BFF API handling) converts 401/403 into status codes instead of redirects, so the SPA can handle them. To get a real OIDC redirect on a local endpoint, don't mark it as a BFF API endpoint and don't use the BFF handlers; or opt out with the skip-response-handling metadata:

```csharp
app.MapGet("/api/special", () => "ok")
   .RequireAuthorization()
   .SkipResponseHandling();   // v4: bypass 401/403 conversion, default challenge (OIDC redirect) runs
```
(Alternatively `.AsBffApiEndpoint(requireAntiForgeryCheck: true)` without `.SkipResponseHandling()` keeps conversion.) Note the SPA must navigate (not fetch) to this URL for a redirect to be useful.
