# Triggering a real OIDC redirect from a local BFF API endpoint

Use **`.SkipResponseHandling()`** on the endpoint.

## Why you need it

By default, BFF **converts `401`/`403` responses from local API endpoints into JSON-friendly responses** (a bare `401`/`403` with no body) instead of letting ASP.NET Core issue a redirect. This is deliberate — SPAs calling BFF APIs with `fetch` want a status code they can handle, not an opaque HTML redirect to the IDP.

For an endpoint where you *do* want the normal interactive behavior — i.e., an unauthenticated request should **redirect to the IDP** via the OIDC challenge — you opt out of that conversion with `.SkipResponseHandling()`.

## How to do it

```csharp
app.MapGet("/api/interactive", () => Results.Ok("data"))
    .RequireAuthorization()      // ✅ triggers the challenge when unauthenticated
    .AsBffApiEndpoint()          // ✅ keep CSRF/anti-forgery protection
    .SkipResponseHandling();     // ✅ bypass BFF's 401/403 → JSON conversion, allow the redirect
```

- **`.RequireAuthorization()`** is what causes the challenge for an anonymous caller.
- **`.AsBffApiEndpoint()`** keeps the `X-CSRF` anti-forgery enforcement in place — you're changing the *response* behavior, not dropping CSRF protection.
- **`.SkipResponseHandling()`** disables BFF's automatic 401/403 conversion so the challenge flows through as a normal ASP.NET Core authentication redirect (the OIDC sign-in redirect).

## When to use it

Reserve this for endpoints intended to be hit by a **full browser navigation** (where a redirect makes sense), not for `fetch`-based API calls. For the latter, keep the default behavior and handle `401` in your fetch wrapper by redirecting to `/bff/login`.
