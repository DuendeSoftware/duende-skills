# BFF Behind Reverse Proxy

When running behind a reverse proxy, you need to configure forwarded headers so the app knows the external URL.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

var app = builder.Build();

app.UseForwardedHeaders();
app.UsePathBase("/app");
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

Make sure your nginx is sending the `X-Forwarded-For` and `X-Forwarded-Proto` headers. The `UseForwardedHeaders` middleware should be early in the pipeline, before authentication.
