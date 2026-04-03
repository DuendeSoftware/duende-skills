Here's the multi-frontend BFF v4 configuration:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .AddFrontend("admin", frontend =>
    {
        frontend.MatchingPath = "/admin";
        frontend.CdnIndexHtmlUrl = new Uri("https://cdn.example.com/admin/index.html");

        frontend.ConfigureOpenIdConnect(options =>
        {
            options.Authority = "https://idp.example.com";
            options.ClientId = "admin-client";
            options.ClientSecret = "admin-secret";
            options.ResponseType = "code";
            options.SaveTokens = true;
            options.Scope.Add("admin-api");
        });

        frontend.AddRemoteApi("admin-api", remote =>
        {
            remote.PathMatch = "/api/admin";
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
            options.ResponseType = "code";
            options.SaveTokens = true;
            options.Scope.Add("portal-api");
        });

        frontend.AddRemoteApi("portal-api", remote =>
        {
            remote.PathMatch = "/api/portal";
            remote.TargetUri = new Uri("https://portal-api.example.com");
            remote.RequiredTokenType = RequiredTokenType.User;
        });
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

Key points:

1. **`AddFrontend("admin", ...)`** — Each frontend gets its own OIDC configuration, cookie scheme, and remote API mapping. The `MatchingPath` determines which frontend handles a given request.

2. **`CdnIndexHtmlUrl`** — BFF v4 can serve the SPA's `index.html` from a CDN URL, avoiding the need to host static files locally.

3. **Separate OIDC clients** — Each frontend has its own ClientId/ClientSecret, allowing different scopes and permissions per app.

4. **`AddRemoteApi`** — Each frontend defines its own remote API proxying, scoped to that frontend's token.

5. **`AddBff()`** is the base builder — all `AddFrontend()` calls chain from it.
