# YARP reverse proxy with BFF, configured in code

You can wire up YARP with in-memory route/cluster config and have it forward `/api/{**catch-all}` to your upstream, attaching the user's token and enforcing an anti-forgery check.

Add the YARP package (plus the Duende BFF YARP integration if you're using it):

```bash
dotnet add package Yarp.ReverseProxy
dotnet add package Duende.BFF.Yarp
```

## Program.cs

```csharp
using Yarp.ReverseProxy.Configuration;
using Yarp.ReverseProxy.Transforms;
using Duende.AccessTokenManagement.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();
// ... AddAuthentication()/AddOpenIdConnect() with SaveTokens = true ...

builder.Services.AddReverseProxy()
    .LoadFromMemory(
        routes: new[]
        {
            new RouteConfig
            {
                RouteId   = "api",
                ClusterId = "api-cluster",
                Match     = new RouteMatch { Path = "/api/{**catch-all}" }
            }
        },
        clusters: new[]
        {
            new ClusterConfig
            {
                ClusterId    = "api-cluster",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["default"] = new DestinationConfig
                    {
                        Address = "https://upstream-api.example.com"
                    }
                }
            }
        })
    .AddTransforms(context =>
    {
        // Attach the logged-in user's access token to the proxied request
        context.AddRequestTransform(async transformContext =>
        {
            var token = await transformContext.HttpContext.GetUserAccessTokenAsync();
            if (token?.AccessToken is not null)
            {
                transformContext.ProxyRequest.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token.AccessToken);
            }
        });
    });

builder.Services.AddAntiforgery();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
app.UseAntiforgery();

app.MapReverseProxy();

app.Run();
```

## Notes

- **Token attachment:** a YARP request transform reads the current user's access token (via AccessTokenManagement, which refreshes it if needed) and sets it as a `Bearer` header on the outgoing proxied request.
- **Anti-forgery:** `AddAntiforgery()` + `UseAntiforgery()` enable ASP.NET Core's anti-forgery protection so state-changing proxied calls are validated. Make sure your SPA sends the required anti-forgery token/header on requests to `/api/...`.
- **Routing:** `Path = "/api/{**catch-all}"` forwards `/api` and everything under it to the `api-cluster` destination.

If you're on the Duende BFF YARP package, check its documentation for helper extensions that integrate token management and anti-forgery directly into the route configuration, which can replace the manual transform above.
