# Multi-frontend BFF v4

```csharp
builder.Services.AddBff(options =>
{
    options.AutomaticallyRegisterBffMiddleware = false;  // manual control (see below)
})
.AddFrontend("admin", frontend =>
{
    frontend.MatchingPath = "/admin";
    frontend.CdnIndexHtmlUrl = new Uri("https://cdn.example.com/admin/index.html");

    frontend.ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "admin-client";
        options.ClientSecret = "admin-secret";
    });

    frontend.AddRemoteApi("api", remote =>
    {
        remote.PathMatch = "/api/admin";   // under the frontend's path mapping
        remote.TargetUri = new Uri("https://admin-api.example.com");
        remote.RequiredTokenType = RequiredTokenType.User;
    });
})
.AddFrontend("portal", frontend =>
{
    frontend.MatchingPath = "/portal";
    frontend.CdnIndexHtmlUrl = new Uri("https://cdn.example.com/portal/index.html");

    frontend.ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "portal-client";
        options.ClientSecret = "portal-secret";
    });

    frontend.AddRemoteApi("api", remote =>
    {
        remote.PathMatch = "/api/portal";
        remote.TargetUri = new Uri("https://portal-api.example.com");
        remote.RequiredTokenType = RequiredTokenType.User;
    });
});

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();

app.UseBffPreProcessing();
app.UseBffFrontendSelection();
app.UseBffPathMapping();
app.UseBffOpenIdCallbacks();
app.UseBffStaticFileProxying();

app.UseAuthorization();
app.Run();
```

Notes:
- Each frontend has its own OIDC client, cookie and APIs; management endpoints are auto-registered per frontend.
- Remote API calls from each SPA **must include `X-CSRF: 1`** or BFF returns 401 before attaching a token (4.0.4/4.1.3/4.2.1/4.3.1+).
- `IIndexHtmlTransformer` can inject per-frontend runtime config into the CDN `index.html`; `IndexHtmlDefaultCacheDuration` (default 5 min) controls caching.
- Use shared Data Protection keys and server-side sessions (EF) in production; the BFF's `Cookie` header is stripped before reaching remote APIs.
- Frontends can also be configured via `Frontends:<name>` in configuration.
