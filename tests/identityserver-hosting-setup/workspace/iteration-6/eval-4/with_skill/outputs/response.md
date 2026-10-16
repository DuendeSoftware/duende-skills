# IdentityServer behind nginx

The proxy terminates TLS and forwards plain HTTP, so ASP.NET Core thinks the request is http: discovery shows http URLs and cookies lack `Secure`. Fix with Forwarded Headers.

**nginx**
```nginx
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
}
```

**Option 1 – simple (cloud/Kubernetes):** set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`.

**Option 2 – explicit (production):**
```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost |
                               ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42")); // your nginx IP
    options.ForwardLimit = 1;
});

var app = builder.Build();

app.UseForwardedHeaders();   // early, before UseIdentityServer
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
```

Only trust known proxies/networks. Don't hardcode `IssuerUri` to work around this; let it be inferred once the scheme/host are right. Also make sure data protection is persistent/shared if you run multiple instances.
