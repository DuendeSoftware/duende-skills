# Local and remote APIs with BFF

```csharp
using Duende.Bff;
using Duende.Bff.Yarp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(o =>
    {
        o.Authority = "https://idp.example.com";
        o.ClientId = "spa-bff-client";
        o.ClientSecret = "secret";
        o.ResponseType = "code";
        o.SaveTokens = true;
        o.Scope.Add("offline_access");
    })
    .AddRemoteApis();

builder.Services.AddAuthorization();
var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();

// Local endpoint: requires login + anti-forgery header
app.MapGet("/api/orders", () => new[] { new { Id = 1, Total = 10.5m } })
   .RequireAuthorization()
   .AsBffApiEndpoint();

// Remote: proxy and attach user's access token
app.MapRemoteBffApiEndpoint("/api/catalog", new Uri("https://catalog-service.internal/api"))
   .WithAccessToken(RequiredTokenType.User);

app.Run();
```

- `AsBffApiEndpoint()` adds anti-forgery protection (`X-CSRF: 1` header required) and makes 401/403 return status codes instead of redirects.
- The remote proxy checks the CSRF header, strips the cookie, adds `Authorization: Bearer <token>`, and refreshes tokens if needed.
- Note `/api/orders` and `/api/catalog` don't overlap, so there is no routing conflict.
