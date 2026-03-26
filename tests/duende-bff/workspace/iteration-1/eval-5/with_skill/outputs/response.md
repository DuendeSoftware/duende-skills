# BFF Behind Nginx Reverse Proxy with Sub-Path

## Problem

When a BFF is behind a reverse proxy, the OIDC callback URL is constructed using the wrong scheme/host/path because the BFF sees the internal request, not the external URL. The authentication callback fails, and the session cookie isn't set.

## Fix

### 1. Configure Forwarded Headers

Add `UseForwardedHeaders` **before** `UseAuthentication` so the OIDC handler constructs callback URLs using the external scheme and host:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // In production, restrict KnownProxies or KnownNetworks
});

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        // Use Lax when the IDP is on a different domain
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Must be FIRST — before any auth middleware
app.UseForwardedHeaders();

// Path base for sub-path mount
app.UsePathBase("/app");

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

### 2. Nginx Configuration

```nginx
location /app {
    proxy_pass http://bff-host:5000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;
}
```

### 3. SameSite Cookie Issue

If the IDP is on a different domain (cross-site), use `SameSite = Lax`. With `Strict`, the browser won't send the cookie on the first request after the OIDC redirect from the IDP, causing the session to appear lost.
