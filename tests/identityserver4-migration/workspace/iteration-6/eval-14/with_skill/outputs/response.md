## Issuer concerns when moving from IIS to Kestrel + nginx

The issuer (`iss` claim, and `issuer` in discovery) must remain **identical** after migration, otherwise existing tokens are rejected and client/API trust breaks. Since you never set `IssuerUri`, it's inferred from the request URL (scheme/host/port), which changes if the hosting does.

### Steps
1. **Record the current value** from the old instance's `/.well-known/openid-configuration` (the Migration Analysis Tool also reports it).
2. **Set it explicitly**:
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com"; // exactly what the old discovery doc said
});
```
Check trailing slash, scheme, host and port.
3. **Configure forwarded headers** — behind nginx, Kestrel sees `http://localhost:5000`; without forwarded headers the discovery document shows HTTP/the internal host:
```csharp
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    // add KnownProxies / KnownNetworks for nginx
});
var app = builder.Build();
app.UseForwardedHeaders();   // before UseIdentityServer
```
nginx: `proxy_set_header Host $host; proxy_set_header X-Forwarded-Proto $scheme; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`
4. **Verify** `/.well-known/openid-configuration` shows the same issuer and HTTPS endpoints.

### Related things that change with the move
- **Data Protection**: IIS/Windows → Linux means different default key locations; the default app name is the content-root path, which changes. Set `SetApplicationName(...)` and a persistent key store (`PersistKeysToDbContext`/file system/blob), or persisted grants, cookies and antiforgery tokens won't decrypt.
- **Signing keys**: `AddDeveloperSigningCredential` isn't suitable; use automatic key management or `AddSigningCredential`, keeping the old key as needed for continuity.
