# Should `FallbackToDefault = true` handle unknown tenant paths?

**Not by default; keep the strict 404.**

How resolution works: requests carrying the space prefix (e.g. `/t/unknown`) with no matching space get `404`. Other unmatched requests also get `404`, unless `FallbackToDefault = true`, which serves them from the **default space** (data pool `0`).

Why it's risky:
- It crosses a **security boundary** silently: a typo, stale link, deleted (soft-deleted) space, or a spoofed host/forwarded header would land on the default space, with its own clients, sessions and issuer, instead of failing.
- Deleted or suspended tenants would stop returning 404 and instead hit the default space.
- Mismatched issuers create confusing validation failures at clients, and the default space becomes a catch-all attack surface for scanning/enumeration.
- A 404 makes misconfiguration obvious and keeps isolation guarantees easy to reason about.

When it's acceptable: only if falling back to the default space is an **intentional isolation decision**, e.g. the default space is the deliberately public/primary environment and other spaces are the exception.

Recommendations:
```csharp
builder.Services.Configure<SpacesOptions>(o =>
{
    o.SpacePathPrefix = "/t";
    o.FallbackToDefault = false;   // default; keep it
});
```
- Add logging/monitoring for unmatched space requests and a friendly custom 404 page.
- Make sure the host actually mapped to a space is correct (`UseForwardedHeaders` with `KnownProxies` before `UseSpaceResolution`), since an untrusted forwarded host can select a different boundary.
- If you want a default landing experience, link explicitly to the default space URL instead.
