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
    })
    .AddRemoteApis();

builder.Services.AddReverseProxy()
    .LoadFromMemory(
        new[]
        {
            new RouteConfig
            {
                RouteId = "api",
                ClusterId = "upstream",
                Match = new RouteMatch { Path = "/api/{**catch-all}" }
            }.WithAccessToken(RequiredTokenType.User)
             .WithAntiforgeryCheck()
        },
        new[]
        {
            new ClusterConfig
            {
                ClusterId = "upstream",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["d1"] = new() { Address = "https://upstream-api.example.com" }
                }
            }
        })
    .AddBffExtensions();

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();
app.MapBffManagementEndpoints();
app.MapReverseProxy();
app.Run();
```
`AddBffExtensions()` adds the access-token and anti-forgery transforms/middleware. The user must be logged in; the SPA sends `X-CSRF: 1`.
