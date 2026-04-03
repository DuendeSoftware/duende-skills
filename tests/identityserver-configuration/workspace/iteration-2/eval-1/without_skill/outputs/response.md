Here's how to set up a basic IdentityServer host in `Program.cs` with in-memory stores:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Enable event logging
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
        new ApiScope("weatherapi")
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up IdentityServer with:
- The openid and profile identity resources
- A `weatherapi` API scope
- All diagnostic events enabled
- The standard authentication and authorization middleware
