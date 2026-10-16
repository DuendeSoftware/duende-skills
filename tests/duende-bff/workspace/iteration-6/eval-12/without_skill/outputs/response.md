# BFF v4 multi-frontend

```csharp
builder.Services.AddBff()
    .AddFrontends(
        new BffFrontend(BffFrontendName.Parse("admin"))
            .WithIndexHtmlUrl(new Uri("https://cdn.example.com/admin/index.html"))
            .WithPathMapping(PathString.FromUriComponent("/admin"))
            .WithOpenIdConnectOptions(o =>
            {
                o.Authority = "https://idp.example.com";
                o.ClientId = "admin-client";
                o.ClientSecret = "secret-admin";
                o.ResponseType = "code";
                o.Scope.Add("offline_access");
            })
            .WithRemoteApis(new RemoteApi(PathString.FromUriComponent("/admin/api"), new Uri("https://admin-api.example.com"))),
        new BffFrontend(BffFrontendName.Parse("portal"))
            .WithIndexHtmlUrl(new Uri("https://cdn.example.com/portal/index.html"))
            .WithPathMapping(PathString.FromUriComponent("/portal"))
            .WithOpenIdConnectOptions(o => { o.Authority = "https://idp.example.com"; o.ClientId = "portal-client"; o.ClientSecret = "secret-portal"; o.ResponseType = "code"; })
            .WithRemoteApis(new RemoteApi(PathString.FromUriComponent("/portal/api"), new Uri("https://portal-api.example.com"))));

var app = builder.Build();
app.UseBff();
app.UseAuthorization();
app.MapBffManagementEndpoints();
app.Run();
```
Each frontend gets its own cookie, OIDC client and management endpoints under its path (e.g. `/admin/bff/login`). Frontends can also come from configuration. Exact API names may vary by v4 minor version.
