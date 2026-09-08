# Multi-Issuer Behavior in IdentityServer

Short answers: **yes, it's the default**; you turn it off by **pinning `IssuerUri`**; and **no, it is not multi-tenancy**.

## Yes — per-domain issuers are the default

By **default**, a single IdentityServer derives the `iss` claim (and the issuer advertised in the discovery document) from the **origin/host of the incoming request**. The same deployment can serve several hosts and return a different `iss` for each, with no extra configuration:

```
Request to https://a.example.com  →  iss = "https://a.example.com"
Request to https://b.example.com  →  iss = "https://b.example.com"
```

So if you host the one IdentityServer on multiple domains, each domain's tokens already carry that domain as the issuer out of the box.

## What turns it off — `IssuerUri`

Setting a fixed issuer **disables** the dynamic behavior. Every token then carries the configured value regardless of which host the request came in on:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Pins iss to a single fixed value; multi-issuer is turned off
    options.IssuerUri = "https://identity.example.com";
});
```

Leave `IssuerUri` unset to keep the per-host behavior.

## No — this is not multi-tenancy

Returning a per-host `iss` (RFC 7519 §4.1.1) only changes the issuer **string** in the token and discovery. It does **not**:

- isolate users, grants, or sessions per domain,
- give each domain its own signing keys,
- partition any data.

All hosts still share the same user store, persisted-grant store, signing keys, and configuration. **Tenant isolation is a separate concern** that remains the implementer's responsibility (e.g. per-tenant stores, key management, and data partitioning). Multi-issuer is convenient for branding/URL separation, but don't mistake it for a security/data boundary.
