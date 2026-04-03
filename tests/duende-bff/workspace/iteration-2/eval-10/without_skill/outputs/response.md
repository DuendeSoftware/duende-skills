Here's how to set up YARP reverse proxy with BFF:

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
                Match = new RouteMatch { Path = "/api/{**catch-all}" },
                Metadata = new Dictionary<string, string>
                {
                    ["Duende.Bff.Yarp.TokenType"] = "User",
                    ["Duende.Bff.Yarp.AntiforgeryCheck"] = "true"
                }
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

This configures YARP to proxy all requests matching `/api/{**catch-all}` to your upstream API, with the user's access token attached and anti-forgery checking enabled via metadata.
