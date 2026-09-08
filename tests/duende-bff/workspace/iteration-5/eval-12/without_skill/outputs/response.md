# Hosting two SPAs (admin + portal) behind one BFF

You want a single host that serves two SPAs from different paths, each with its own OIDC client and its own downstream API. Without a built-in multi-frontend feature, the usual approach is to register **two OpenID Connect schemes** (one per client), select the scheme based on the request path, and proxy each path to its API.

```csharp
using Duende.Bff;
using Microsoft.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .AddRemoteApis();

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc-admin";
    })
    .AddCookie("cookie")
    // Admin client
    .AddOpenIdConnect("oidc-admin", options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "admin-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.CallbackPath = "/admin/signin-oidc";
        options.SaveTokens = true;
    })
    // Portal client
    .AddOpenIdConnect("oidc-portal", options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "portal-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.CallbackPath = "/portal/signin-oidc";
        options.SaveTokens = true;
    });

// Pick the challenge scheme based on which app the user is in
builder.Services.AddAuthentication()
    .AddPolicyScheme("dynamic", "dynamic", options =>
    {
        options.ForwardDefaultSelector = ctx =>
            ctx.Request.Path.StartsWithSegments("/portal") ? "oidc-portal" : "oidc-admin";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Proxy each app's API to its backend
app.MapRemoteBffApiEndpoint("/admin/api", new Uri("https://admin-api.example.com"))
    .RequireAccessToken(TokenType.User);

app.MapRemoteBffApiEndpoint("/portal/api", new Uri("https://portal-api.example.com"))
    .RequireAccessToken(TokenType.User);

// Serve each SPA's index.html (proxied/copied from the CDN) under its path
app.MapGet("/admin/{**path}", () => Results.Redirect("https://cdn.example.com/admin/index.html"));
app.MapGet("/portal/{**path}", () => Results.Redirect("https://cdn.example.com/portal/index.html"));

app.Run();
```

## Notes

- **Two OIDC schemes** (`oidc-admin`, `oidc-portal`) give each SPA its own client id and callback path.
- **A policy scheme** with `ForwardDefaultSelector` chooses which client to challenge with, based on whether the request is under `/admin` or `/portal`.
- **Two remote proxies** forward `/admin/api` and `/portal/api` to their respective backends with the user's token.
- For the CDN-hosted `index.html`, you'd typically fetch and serve it (or reverse-proxy it) under each path; the redirect above is a simplification.

This is a fair amount of manual wiring. If you're on a recent Duende BFF release, check whether it offers a dedicated multi-frontend configuration that can express per-app OIDC clients and API mappings more directly than the scheme-selection approach above.
