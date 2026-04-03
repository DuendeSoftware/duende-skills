The issue is a combination of missing forwarded headers configuration and path base setup. When BFF is behind nginx at a sub-path, the OIDC callback URLs and cookie paths are constructed incorrectly because the BFF doesn't know the external scheme, host, or path prefix.

Here's the fix:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Configure forwarded headers options
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // In production, restrict known proxies/networks
    // options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
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
        // Use Lax when the IDP is on a different domain (cross-site redirect)
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// CRITICAL: UseForwardedHeaders MUST come before UseAuthentication
// This ensures the OIDC middleware sees the correct external scheme and host
app.UseForwardedHeaders();

// UsePathBase MUST come before routing and authentication
// This strips /app from incoming requests and prepends it to generated URLs
app.UsePathBase("/app");

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

What's happening and why:

1. **`UseForwardedHeaders` with `XForwardedFor` and `XForwardedProto`** — nginx forwards requests to BFF over HTTP (typically), but the external URL is HTTPS. Without forwarded headers, the OIDC redirect_uri is generated as `http://...` instead of `https://...`, causing the IDP to reject the callback or the cookie to not be sent (since it requires `Secure`).

2. **`UseForwardedHeaders` must come before `UseAuthentication`** — The authentication middleware reads the request scheme/host when constructing the OIDC callback URL. If forwarded headers aren't processed yet, it uses the internal scheme.

3. **`UsePathBase("/app")`** — When the BFF is mounted at `/app`, all generated URLs (including OIDC callback URLs) must include this prefix. Without PathBase, the OIDC callback comes back to `/signin-oidc` instead of `/app/signin-oidc`, and the BFF never processes it.

4. **`SameSite = Lax`** is critical here — After the OIDC redirect from the IDP (which is a cross-site navigation), a `Strict` cookie would not be sent on the first request back to the BFF. This means the post-login cookie isn't included, and it looks like the user was never logged in. Use `Lax` when your IDP is on a different domain.

Your nginx config should forward the necessary headers:

```nginx
location /app {
    proxy_pass http://bff-backend;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;
}
```
