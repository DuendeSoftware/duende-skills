To create a custom identity resource with specific claims, you can define it in your IdentityServer configuration:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource
        {
            Name = "organization",
            DisplayName = "Organization Info",
            UserClaims = { "org_id", "org_name", "org_role" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

This defines a custom scope called "organization" that will include the three claims when requested by a client. The standard openid and profile resources are also included. You may want to add this to the client's allowed scopes as well.
