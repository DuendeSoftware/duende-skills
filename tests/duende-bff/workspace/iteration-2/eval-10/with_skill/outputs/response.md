Here's the YARP reverse proxy integration with BFF using in-code configuration:

```csharp
// Program.cs
using Duende.BFF.Yarp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

var proxyBuilder = builder.Services.AddReverseProxy()
    .AddBffExtensions(); // Register BFF token management for YARP

// Configure routes and clusters in code
proxyBuilder.LoadFromMemory(
    routes:
    [
        new RouteConfig
        {
            RouteId = "api-route",
            ClusterId = "upstream-cluster",
            Match = new RouteMatch { Path = "/api/{**catch-all}" }
        }
        .WithAccessToken(TokenType.User)      // Note: YARP uses TokenType, not RequiredTokenType
        .WithAntiforgeryCheck()                // Enforce X-CSRF header on this route
    ],
    clusters:
    [
        new ClusterConfig
        {
            ClusterId = "upstream-cluster",
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

// IMPORTANT: UseAntiforgeryCheck() must be explicitly added inside MapReverseProxy
app.MapReverseProxy(proxyApp =>
{
    proxyApp.UseAntiforgeryCheck();
});

app.Run();
```

Key points:

1. **`AddReverseProxy().AddBffExtensions()`** — Registers YARP with BFF token management extensions.

2. **`LoadFromMemory`** — Configures routes and clusters in code instead of appsettings.json.

3. **`.WithAccessToken(TokenType.User)`** — YARP routes use `TokenType` (not `RequiredTokenType` which is used by `MapRemoteBffApiEndpoint`).

4. **`.WithAntiforgeryCheck()`** — Enables anti-forgery validation on the route.

5. **`proxyApp.UseAntiforgeryCheck()`** — Must be explicitly added inside `MapReverseProxy`. Unlike `MapRemoteBffApiEndpoint`, YARP's anti-forgery enforcement is NOT automatic.

Install the YARP integration package:
```
dotnet add package Duende.BFF.Yarp
```
