For a multi-frontend BFF setup, you'd need to configure each SPA separately. Here's a general approach:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();

// You'd need to configure multiple authentication schemes
builder.Services.AddAuthentication()
    .AddCookie("admin-cookie")
    .AddOpenIdConnect("admin-oidc", options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "admin-client";
        options.ClientSecret = "admin-secret";
    })
    .AddCookie("portal-cookie")
    .AddOpenIdConnect("portal-oidc", options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "portal-client";
        options.ClientSecret = "portal-secret";
    });

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Map remote endpoints for each app
app.MapRemoteBffApiEndpoint("/api/admin", new Uri("https://admin-api.example.com"));
app.MapRemoteBffApiEndpoint("/api/portal", new Uri("https://portal-api.example.com"));

app.Run();
```

You'd also need to serve the appropriate SPA based on the path. This might involve custom middleware to proxy to the CDN or serve different index.html files based on the request path.
