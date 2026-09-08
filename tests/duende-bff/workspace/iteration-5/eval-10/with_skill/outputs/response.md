# YARP reverse proxy + BFF (in-code configuration)

Install the BFF YARP integration:

```bash
dotnet add package Duende.BFF.Yarp
```

The BFF YARP integration hooks token management and anti-forgery into the YARP pipeline. You register it with `.AddBffExtensions()`, configure routes/clusters via `LoadFromMemory`, and — importantly — you must add `UseAntiforgeryCheck()` **inside** `MapReverseProxy` (unlike `MapRemoteBffApiEndpoint`, YARP's anti-forgery is not automatic).

```csharp
using Duende.Bff;
using Duende.Bff.Yarp;
using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority    = builder.Configuration["Oidc:Authority"];
        options.ClientId     = builder.Configuration["Oidc:ClientId"];
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.SaveTokens   = true;
        options.Scope.Add("offline_access");
    });

// ✅ Register YARP with BFF token-management extensions
var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions();

// ✅ In-code route/cluster configuration via LoadFromMemory
proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId   = "api",
            ClusterId = "api-cluster",
            Match     = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)   // ✅ YARP uses TokenType, not RequiredTokenType
        .WithAntiforgeryCheck()            // ✅ enforce the BFF anti-forgery header
    ],
    clusters:
    [
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
    ]
);

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// ✅ UseAntiforgeryCheck() MUST be added explicitly inside the YARP pipeline
app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck();
});

app.Run();
```

## Why each piece matters

- **`.AddBffExtensions()`** registers BFF's token management for YARP so `.WithAccessToken(...)` and `.WithAntiforgeryCheck()` are available on the route config.
- **`.WithAccessToken(TokenType.User)`** — note the type is `TokenType`, **not** `RequiredTokenType` (that's what `MapRemoteBffApiEndpoint` uses). This attaches the current user's access token (auto-refreshed) to the upstream request.
- **`.WithAntiforgeryCheck()`** marks the route as requiring the `X-CSRF` anti-forgery header.
- **`proxyApp.UseAntiforgeryCheck()`** inside `MapReverseProxy` is mandatory — omit it and YARP routes are **not** anti-forgery protected, even if `.WithAntiforgeryCheck()` is on the route. This is the most common YARP+BFF mistake.
- **`Path = "/api/{**catch-all}"`** matches `/api` and everything beneath it and forwards to the `api-cluster` destination.
