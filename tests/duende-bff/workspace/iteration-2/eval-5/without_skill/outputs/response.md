When running an ASP.NET Core app behind nginx with a sub-path, you typically need to handle forwarded headers and the path base. Here's what you're likely missing:

```csharp
var builder = WebApplication.CreateBuilder(args);

// ... your existing BFF and auth configuration ...

var app = builder.Build();

// Add forwarded headers middleware
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

// Set the path base for the sub-path mount
app.UsePathBase("/app");

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

The key issues are:

1. **Forwarded Headers** — nginx proxies requests internally, often over HTTP. The `X-Forwarded-Proto` header tells your app the original scheme was HTTPS. Without this, OIDC redirect URIs will be HTTP instead of HTTPS.

2. **Path Base** — When mounted at `/app`, the app needs to know so it generates correct callback URLs.

Make sure your nginx forwards the right headers:
```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

Also make sure `UseForwardedHeaders` comes early in the pipeline, before authentication.
