# Setting Up YARP Reverse Proxy with BFF

You can use YARP (Yet Another Reverse Proxy) with Duende BFF to proxy API requests while attaching access tokens. Here's how to set it up.

First, install the YARP BFF integration package:

```bash
dotnet add package Duende.BFF.Yarp
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens = true;
    });

builder.Services.AddAuthorization();

// Add YARP reverse proxy with BFF extensions for token management
builder.Services.AddReverseProxy()
    .AddBffExtensions()
    .LoadFromMemory(
        routes: new[]
        {
            new RouteConfig
            {
                RouteId = "api-route",
                ClusterId = "api-cluster",
                Match = new RouteMatch { Path = "/api/{**catch-all}" }
            }
            .WithAccessToken(RequiredTokenType.User)
        },
        clusters: new[]
        {
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
        }
    );

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapReverseProxy();

app.Run();
```

## How It Works

1. **`AddBffExtensions()`** integrates BFF token management into the YARP pipeline so tokens are attached to proxied requests.
2. **`WithAccessToken(RequiredTokenType.User)`** configures the route to forward the user's access token.
3. The BFF middleware (`UseBff()`) handles anti-forgery protection for all requests.
4. **`LoadFromMemory`** provides in-code route and cluster configuration as an alternative to appsettings.json.

Make sure your SPA sends the `X-CSRF: 1` header with all proxied requests to satisfy BFF's anti-forgery requirements.
