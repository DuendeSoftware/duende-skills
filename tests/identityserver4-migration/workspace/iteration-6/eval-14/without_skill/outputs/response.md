## Issuer concerns

In IS4, when `IssuerUri` isn't set, the issuer is derived from the request URL (scheme+host+port, plus path base). Tokens' `iss` claim and the discovery document `issuer` depend on it. Duende does the same, so changing hosting can change the issuer and break validation by APIs/clients (`iss` mismatch).

Things to watch:
- **Behind nginx** Kestrel sees `http://localhost:5000` unless forwarded headers are processed. Your issuer would then become `http://localhost:5000` or the internal host.
- Configure forwarded headers first in the pipeline:
```csharp
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    o.KnownProxies.Add(IPAddress.Parse("10.0.0.5")); // or KnownNetworks
});
app.UseForwardedHeaders();
```
and in nginx: `proxy_set_header Host $host; proxy_set_header X-Forwarded-Proto $scheme; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Host $host;`
- **Be explicit**: set `options.IssuerUri = "https://login.example.com"` matching the value your existing tokens carry (check old discovery doc) so it doesn't depend on the proxy.
- Trailing slash, default port, and casing must match exactly.
- Also check that `UseHttpsRedirection`, cookies' Secure flag and discovery endpoints URLs show https.
- Verify `/.well-known/openid-configuration` after deployment.
- Note Duende v6+ has `EmitStaticAudienceClaim` and `aud` changes; v7 uses `at+jwt` token type, which APIs may need to accept.
