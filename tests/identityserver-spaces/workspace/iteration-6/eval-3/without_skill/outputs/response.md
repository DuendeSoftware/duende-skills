# Why all spaces return the same issuer

**Cause**: `options.IssuerUri` is a static override. When set, IdentityServer uses exactly that string as the `issuer` in discovery and the `iss` claim in tokens, regardless of the request's host or path. Any per-space (per-path/per-host) issuer logic is therefore overridden, so every space reports `https://login.example.com`.

**Fix**: remove the setting (leave `IssuerUri` null). When unset, IdentityServer derives the issuer dynamically from the current request (scheme, host, path base). If the space middleware sets the path base to `/t/acme`, the issuer becomes `https://login.example.com/t/acme`.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // options.IssuerUri = "https://login.example.com";  // remove
    options.EmitStaticAudienceClaim = true;
});
```

Checks:
- Make sure the space-resolution middleware runs before `UseIdentityServer()` so path base/host is set.
- If behind a proxy, configure forwarded headers so scheme/host are correct.
- Verify `/t/acme/.well-known/openid-configuration` and `/t/globex/...` show different `issuer` values.
- Update client/API validation (`Authority`, `ValidIssuer`) to the per-space issuer.

If you need an explicit value per tenant, compute it from the tenant at runtime instead of a static string (check the Spaces docs for the supported hook).
