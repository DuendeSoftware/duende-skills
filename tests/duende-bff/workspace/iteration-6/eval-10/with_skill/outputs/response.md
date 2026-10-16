# YARP + BFF with LoadFromMemory

`dotnet add package Duende.BFF.Yarp`

```csharp
using Duende.Bff.Yarp;
using Yarp.ReverseProxy.Configuration;

builder.Services.AddBff()
    .ConfigureOpenIdConnect(o =>
    {
        o.Authority = "https://idp.example.com";
        o.ClientId = "spa-bff-client";
        o.ClientSecret = "secret";
        o.ResponseType = "code";
        o.SaveTokens = true;
        o.Scope.Add("offline_access");
    });

var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions();      // BFF token management for YARP

proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId = "api",
            ClusterId = "api-cluster",
            Match = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)   // YARP uses TokenType, not RequiredTokenType
        .WithAntiforgeryCheck()
    ],
    clusters:
    [
        new ClusterConfig
        {
            ClusterId = "api-cluster",
            Destinations = new Dictionary<string, DestinationConfig>
            {
                ["default"] = new DestinationConfig { Address = "https://upstream-api.example.com" }
            }
        }
    ]);

builder.Services.AddAuthorization();
var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck();   // must be added explicitly for YARP
});

app.Run();
```

Notes:
- `WithAntiforgeryCheck()` only marks the route; `UseAntiforgeryCheck()` inside `MapReverseProxy` actually enforces it. Omitting it leaves YARP routes unprotected. The SPA must send `X-CSRF: 1`.
- Browser `Cookie` header is stripped from YARP requests (patch releases incl. 4.3.1), so the API must use the attached bearer token.
- With JSON config, metadata keys (`Duende.Bff.Yarp.TokenType`, `Duende.Bff.Yarp.AntiforgeryCheck`) are case-sensitive and fail silently on typos — one more reason to use code config.
