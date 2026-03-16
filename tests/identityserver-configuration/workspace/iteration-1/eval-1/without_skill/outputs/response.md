Here's how to set up a basic Duende IdentityServer host with in-memory stores:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("weatherapi", "Weather API")
    })
    .AddInMemoryClients(new List<Client>());

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up:
- IdentityServer with all event types enabled for logging/diagnostics
- The standard `openid` and `profile` identity resources
- A single API scope called `weatherapi`
- An empty client list (you'll add clients later)
- The authentication and authorization middleware in the pipeline
