# Why every space reports the same issuer

**Cause**: `options.IssuerUri = "https://login.example.com"` is a fixed override. Spaces rely on *issuer inference* from request origin plus path base, which gives each space its own `iss`. With a static `IssuerUri`, inference is bypassed, so every space returns the same `issuer` in discovery and the same `iss` in tokens. (Data and discovery endpoints still differ per space; only the issuer value is identical.) The same rule applies to Multi-Issuer.

**Fix**: leave `IssuerUri` unset.

```csharp
builder.Services
    .AddIdentityServer(options =>
    {
        // options.IssuerUri = "https://login.example.com";   // REMOVE
        options.EmitStaticAudienceClaim = true;
    })
    ...
```

Then make sure inference sees the right origin and path:
```csharp
app.UseForwardedHeaders();   // forwarded host/proto first (only from KnownProxies)
app.UseSpaceResolution();    // before UseRouting: moves /t/acme into PathBase
app.UseRouting();
app.UseIdentityServer();
```

Result: `https://login.example.com/t/acme/.well-known/openid-configuration` returns `issuer: https://login.example.com/t/acme`, and `/t/globex` gets its own. Origin-matched spaces (`https://acme.example.com`) get `https://acme.example.com`.

Follow-ups:
- Set each client's/API's authority and valid issuer to its space's base URL.
- In HA, every instance must resolve the same issuer per host/space: keep proxy host names and path bases stable.
- If forwarded headers are misconfigured, the inferred issuer will use the internal scheme/host; configure `KnownProxies` correctly.
