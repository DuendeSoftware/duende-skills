# YARP Reverse Proxy with BFF Integration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    });

builder.Services.AddAuthorization();

// YARP with BFF extensions
var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions();

proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId = "api-route",
            ClusterId = "api-cluster",
            Match = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)
        .WithAntiforgeryCheck()
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

// YARP pipeline with anti-forgery check
app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck();
});

app.Run();
```

## Key Points

- **`AddReverseProxy().AddBffExtensions()`** registers YARP with BFF token management support.
- **`LoadFromMemory`** configures routes and clusters in code. The route matches `/api/{**catch-all}`.
- **`.WithAccessToken(TokenType.User)`** — Note: YARP uses `TokenType` (not `RequiredTokenType` which is for `MapRemoteBffApiEndpoint`).
- **`.WithAntiforgeryCheck()`** enables X-CSRF header validation on the route.
- **`MapReverseProxy` with `UseAntiforgeryCheck()`** — Anti-forgery is NOT automatic in the YARP pipeline; it must be explicitly added.
