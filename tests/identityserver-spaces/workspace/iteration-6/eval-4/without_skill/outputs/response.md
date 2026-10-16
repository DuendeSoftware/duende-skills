# Should unknown tenant paths fall back to the default space?

**No, not recommended.** A 404 for an unknown tenant is the correct, safe behavior.

Reasons:
- **Tenant confusion / data leakage**: a typo or stale link (`/t/acmee`) would silently authenticate against the default space, with a different issuer, clients and users. Users may log into the wrong tenant context.
- **Issuer mismatch**: tokens would be issued by the default space while the client expects `/t/acmee`, causing confusing validation failures, or worse, tokens accepted where they shouldn't be.
- **Enumeration and abuse**: every junk path becomes a valid login surface on the default space, widening attack surface and complicating rate limiting and monitoring.
- **Deleted or suspended tenants**: they would unexpectedly land on the default space instead of being blocked.
- **Debuggability**: 404s make misconfiguration obvious.

**Better**: keep `FallbackToDefault = false` (I can't confirm the exact option name from memory; check docs). For friendlier UX, add a custom 404 page for unknown tenants, log the misses, and if you need a default experience, redirect explicitly from a known landing URL (for example `/`) rather than silently falling back. Only use fallback if the default space is intentionally a public, single-tenant-compatible space.
