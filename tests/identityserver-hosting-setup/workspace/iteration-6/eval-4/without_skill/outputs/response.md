# IdentityServer behind nginx

The app sees plain HTTP from nginx, so it generates http URLs and non-secure cookies. Fix: forward the original scheme/host and have ASP.NET Core honor them.

**nginx**
```nginx
location / {
    proxy_pass http://localhost:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Program.cs**
```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();   // or add your nginx IP
});

var app = builder.Build();
app.UseForwardedHeaders();   // must be first
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
```

Alternatively set env var `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`. Clear the known proxies only if nginx is on a trusted network; otherwise list its IP. As a fallback you can set `options.PublicOrigin = "https://id.example.com"` in IdentityServer options. Once the request scheme is https, cookies get the Secure attribute and discovery shows https.
