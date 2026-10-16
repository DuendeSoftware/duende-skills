**Yes, by default.** If `IdentityServerOptions.IssuerUri` is not set, IdentityServer derives the issuer from the incoming request's scheme/host (and path base). So `https://a.example.com` issues tokens with `iss = https://a.example.com`, and `https://b.example.com` with `https://b.example.com`. Discovery documents reflect the same host.

**What turns it off:** setting a static issuer:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://sts.example.com";
});
```

Then every domain issues the same `iss`. (Behind a proxy, also make sure forwarded headers are configured correctly or dynamic issuers will be wrong.)

Considerations when keeping it dynamic:
- Each API/client must validate against the issuer for the domain it trusts; with one `Authority` per app that works naturally, but tokens from domain A will be rejected by APIs expecting B.
- Signing keys are shared across domains, so tokens for one issuer are cryptographically valid for another unless audience/issuer validation is strict.

**Is it multi-tenancy? No.** Per-host issuers only change the `iss` value and discovery URLs. Multi-tenancy involves isolating per-tenant clients, resources, users, identity providers, signing keys, configuration and data — typically via tenant-aware stores/claims or separate instances. You can build multi-tenancy on top of host-based tenant resolution, but the dynamic issuer by itself provides no isolation.
