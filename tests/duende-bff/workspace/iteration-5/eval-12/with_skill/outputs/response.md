# BFF v4 multi-frontend: `admin` and `portal`

BFF v4 has first-class multi-frontend support via `AddFrontend()`. Each frontend gets its own matching path, CDN-served `index.html`, OIDC client, and remote API proxy — all on a single BFF host.

```csharp
using Duende.Bff;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    // ✅ Admin frontend
    .AddFrontend("admin", frontend =>
    {
        frontend.MatchingPath   = "/admin";
        frontend.CdnIndexHtmlUrl = new Uri("https://cdn.example.com/admin/index.html");

        frontend.ConfigureOpenIdConnect(options =>
        {
            options.Authority    = "https://idp.example.com";
            options.ClientId     = "admin-client";     // distinct client
            options.ClientSecret = "admin-secret";
            options.ResponseType = "code";
            options.SaveTokens   = true;
            options.Scope.Add("openid");
            options.Scope.Add("profile");
            options.Scope.Add("offline_access");
        });

        frontend.AddRemoteApi("api", remote =>
        {
            remote.PathMatch         = "/api";
            remote.TargetUri         = new Uri("https://admin-api.example.com");
            remote.RequiredTokenType = RequiredTokenType.User;
        });
    })
    // ✅ Portal frontend
    .AddFrontend("portal", frontend =>
    {
        frontend.MatchingPath   = "/portal";
        frontend.CdnIndexHtmlUrl = new Uri("https://cdn.example.com/portal/index.html");

        frontend.ConfigureOpenIdConnect(options =>
        {
            options.Authority    = "https://idp.example.com";
            options.ClientId     = "portal-client";    // distinct client
            options.ClientSecret = "portal-secret";
            options.ResponseType = "code";
            options.SaveTokens   = true;
            options.Scope.Add("openid");
            options.Scope.Add("profile");
            options.Scope.Add("offline_access");
        });

        frontend.AddRemoteApi("api", remote =>
        {
            remote.PathMatch         = "/api";
            remote.TargetUri         = new Uri("https://portal-api.example.com");
            remote.RequiredTokenType = RequiredTokenType.User;
        });
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();          // auto-registers BFF middleware for all frontends
app.UseAuthorization();

app.Run();
```

## How it works

- **`AddFrontend("admin", …)` / `AddFrontend("portal", …)`** define two independent frontends. `MatchingPath` decides which frontend serves a request (`/admin/*` vs `/portal/*`).
- **`CdnIndexHtmlUrl`** tells BFF to fetch each SPA's `index.html` from the CDN and serve it under the matching path. (Cache duration is controlled by `IndexHtmlDefaultCacheDuration`, default 5 minutes.)
- **`ConfigureOpenIdConnect`** per frontend gives each SPA its **own** OIDC client (`admin-client` vs `portal-client`), so logins are isolated.
- **`AddRemoteApi`** per frontend proxies that frontend's API path to its backend (`admin-api` vs `portal-api`), attaching the user's token.

## Optional: manual middleware control

For fine-grained control you can turn off auto-registration and place the BFF middleware components yourself:

```csharp
builder.Services.AddBff(options =>
{
    options.AutomaticallyRegisterBffMiddleware = false;
});

// ...
app.UseRouting();
app.UseAuthentication();
app.UseBffPreProcessing();
app.UseBffFrontendSelection();
app.UseBffPathMapping();
app.UseBffOpenIdCallbacks();
app.UseBffStaticFileProxying();
app.UseAuthorization();
```

This keeps both SPAs — each with its own OIDC client and backend — behind one BFF host.
