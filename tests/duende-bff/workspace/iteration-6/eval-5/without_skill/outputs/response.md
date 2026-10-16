# BFF behind nginx at /app

Likely missing pieces: forwarded headers and path base.

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    o.KnownNetworks.Clear();
    o.KnownProxies.Clear(); // or add nginx IP
});

var app = builder.Build();
app.UseForwardedHeaders();   // first in pipeline
app.UsePathBase("/app");
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
```

nginx:
```
location /app/ {
    proxy_pass http://localhost:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_buffer_size 128k; proxy_buffers 4 256k; proxy_busy_buffers_size 256k;
}
```

Without X-Forwarded-Proto, the app builds `http://` redirect URIs (mismatch with the IdP) and correlation/nonce cookies set with Secure/SameSite fail, so the callback breaks. Large OIDC cookies/headers can also cause 502s, hence the buffer sizes. Make sure `/app/signin-oidc` is registered at the IdP, and the cookie Path is `/app`. Data Protection keys must persist/shared if multiple instances.
