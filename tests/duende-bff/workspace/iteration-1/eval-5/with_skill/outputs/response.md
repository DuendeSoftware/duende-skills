# BFF Behind Nginx Reverse Proxy — OIDC Callback Failures

## Root Cause

When the BFF is behind a reverse proxy, the OIDC callback URL is constructed using the request's scheme and host. If forwarded headers aren't configured, the BFF thinks it's running on `http://localhost:5000` instead of `https://your-domain.com/app`, causing redirect URI mismatches and cookie failures.

## Fix: Forwarded Headers and Path Base

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers to trust the proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // In production, restrict to known proxy networks:
    // options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        // ... OIDC config
    })
    .ConfigureCookies(options =>
    {
        // Use Lax when IDP is on a different domain (cross-site redirect)
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

var app = builder.Build();

// These MUST come before UseAuthentication
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

// Sub-path mount — must also come before auth
app.UsePathBase("/app");

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

## Key Points

- **`UseForwardedHeaders`** with `XForwardedFor` and `XForwardedProto` must be placed **before** `UseAuthentication`. This ensures the OIDC handler constructs redirect URIs using the external scheme (`https`) and host, not the internal container/pod address.
- **`UsePathBase("/app")`** tells ASP.NET Core that the app is mounted at `/app`. Without this, the OIDC callback path (`/signin-oidc`) won't match the path the proxy forwards.
- **SameSite cookie issue**: After the OIDC redirect back from the IDP (a cross-site navigation), the browser won't send the cookie if `SameSite=Strict` is set. Use `SameSite=Lax` when the IDP is on a different domain.

## Nginx Configuration

Ensure nginx forwards the necessary headers:

```nginx
location /app {
    proxy_pass http://bff-host:5000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;
}
```
