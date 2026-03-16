# YARP Reverse Proxy with BFF Integration

First, add the YARP BFF integration package:

```bash
dotnet add package Duende.BFF.Yarp
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// BFF setup with OIDC
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    });

builder.Services.AddAuthorization();

// YARP reverse proxy with BFF extensions
var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions();

// In-code route and cluster configuration
proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId = "api-route",
            ClusterId = "api-cluster",
            Match = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)   // Note: YARP uses TokenType, NOT RequiredTokenType
        .WithAntiforgeryCheck()             // Enable anti-forgery validation on this route
    ],
    clusters:
    [
        new ClusterConfig
        {
            ClusterId = "api-cluster",
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

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// Map the YARP reverse proxy with anti-forgery enforcement in the pipeline
app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck(); // Must be explicitly added for YARP routes
});

app.Run();
```

## Key Points

- **`AddBffExtensions()`** registers BFF token management for YARP so that tokens are automatically attached to proxied requests based on the route configuration.
- **`TokenType.User`** (not `RequiredTokenType.User`) — YARP route extensions use `TokenType`, which is different from the `RequiredTokenType` used by `MapRemoteBffApiEndpoint`. This is a common source of confusion.
- **`WithAntiforgeryCheck()`** on the route config marks the route as requiring the `X-CSRF: 1` header.
- **`UseAntiforgeryCheck()`** inside `MapReverseProxy` actually enforces the anti-forgery check at runtime. Unlike `MapRemoteBffApiEndpoint`, YARP does **not** automatically enforce anti-forgery — you must explicitly add it to the proxy pipeline. Omitting it means the route is unprotected against CSRF even if `WithAntiforgeryCheck()` is set on the route.
- **`LoadFromMemory`** provides in-code configuration as an alternative to `appsettings.json`. Both approaches work, but in-code configuration gives you compile-time checking of route/cluster IDs.
