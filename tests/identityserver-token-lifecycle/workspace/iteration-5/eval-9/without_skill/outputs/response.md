# Issuer Configuration Across Multiple Domains

## Does IdentityServer set the issuer per domain by default?

The `iss` claim comes from IdentityServer's configured issuer. In practice the issuer is typically tied to the base URL of the server. If you don't explicitly configure it, IdentityServer will generally use the request's base address, so hosting on a single domain gives you a stable issuer.

However, if you want each of several domains to reliably emit *that* domain as the issuer, I'd treat that as something you should configure and verify rather than assume — behavior around automatically switching the issuer per incoming host can depend on your hosting/proxy setup (for example, forwarded headers must be correct for the server to see the real host). So I wouldn't rely on per-domain issuers being guaranteed without testing it in your environment.

## Turning it off / fixing the issuer

You can pin the issuer to a single fixed value by setting `IssuerUri` in the IdentityServer options:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com";
});
```

With `IssuerUri` set, every token uses that exact value regardless of which domain the request came in on. This is the setting that overrides any host-based issuer derivation.

## Is this the same as multi-tenancy?

No. Emitting a different issuer per domain is just changing a string value in the token; it does not isolate data. Multi-tenancy means separating each tenant's users, data, grants, and often keys so one tenant can't see another's information. Simply having a per-domain `iss` value gives you none of that isolation — all domains would still share the same user store, keys, and configuration unless you build tenant separation yourself. So issuer-per-domain and multi-tenancy are different concerns.
