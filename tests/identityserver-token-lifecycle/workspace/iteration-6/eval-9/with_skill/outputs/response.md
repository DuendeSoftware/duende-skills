**Does it happen by default? Yes.** With no `IssuerUri` configured, IdentityServer derives `iss` (and the discovery document issuer) from the origin of each incoming request. One deployment serving several domains therefore issues:

- `https://a.example.com` → `iss = "https://a.example.com"`
- `https://b.example.com` → `iss = "https://b.example.com"`

No extra configuration is needed.

**What turns it off:** setting a fixed issuer.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Pins iss to one value; per-host issuers are disabled
    options.IssuerUri = "https://identity.example.com";
});
```

Every token then carries that value regardless of host. If you want per-domain issuers, leave `IssuerUri` unset (and make sure forwarded headers/proxy settings give IdentityServer the correct public origin).

**Is this multi-tenancy? No.** Multi-issuer only changes the `iss` value (RFC 7519 §4.1.1). It does not isolate users, grants, signing keys, or any other data per domain. Tenant isolation (separate clients, users, keys, configuration, data partitioning) remains your responsibility. A per-host issuer can be one building block if you use host as a tenant discriminator, but on its own offers no isolation. Also note that APIs must validate the issuer they expect; since signing keys are shared, strict issuer and audience validation matters.
