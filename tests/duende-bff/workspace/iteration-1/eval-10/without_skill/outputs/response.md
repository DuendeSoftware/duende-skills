# YARP with BFF

To set up YARP as a reverse proxy with BFF:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();
builder.Services.AddReverseProxy()
    .LoadFromMemory(
        routes: new[]
        {
            new RouteConfig
            {
                RouteId = "api",
                ClusterId = "api-cluster",
                Match = new RouteMatch { Path = "/api/{**catch-all}" }
            }
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

This sets up YARP to proxy API requests to the upstream service.
