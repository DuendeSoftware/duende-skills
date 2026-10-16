# BFF behind nginx at /app

You most likely need **forwarded headers** and **UsePathBase**, so callback URLs (`/app/signin-oidc`) and the scheme resolve properly.

```csharp
var app = builder.Build();

// Trust the proxy's headers — before UseAuthentication
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UsePathBase("/app");   // BFF mounted at sub-path

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
    proxy_buffer_size 128k; proxy_buffers 4 256k; proxy_busy_buffers_size 256k;
}
```

Without `X-Forwarded-Proto` the app builds an `http://` redirect URI (mismatching the registered one) and Secure/correlation cookies break, so the callback fails. Also: register `https://host/app/signin-oidc` at the IDP; in a multi-instance setup share Data Protection keys (otherwise correlation/auth cookies fail to decrypt, looping users back out); and mind `SameSite` — `Strict` breaks after a cross-site IDP redirect, use `Lax` in that case. ForwardedHeaders may need `KnownProxies`/`KnownNetworks` set to trust nginx.
